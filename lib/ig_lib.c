#include "ig_lib.h"
#include "logger.h"

#include <stdio.h>
#include <string.h>

/* static functions */
static GList   *ig_lib_gen_hierarchy (struct ig_lib_db *db, struct ig_lib_connection_info *cinfo);
static GNode   *ig_lib_merge_hierarchy_list (struct ig_lib_db *db, GList *hier_list, const char *signame);
static void     ig_lib_htree_print (GNode *hier_tree);
static GNode   *ig_lib_htree_reduce (GNode *hier_tree);
static GList   *ig_lib_htree_process (struct ig_lib_db *db, GNode *hier_tree);
static gboolean ig_lib_htree_process_tfunc (GNode *node, gpointer data);
static void     ig_lib_htree_free (GNode *hier_tree);
static gboolean ig_lib_htree_free_tfunc (GNode *node, gpointer data);

static char    *ig_lib_gen_name_signal  (struct ig_lib_db *db, const char *basename);
static char    *ig_lib_gen_name_pinport (struct ig_lib_db *db, const char *basename, enum ig_port_dir dir);
static bool     ig_lib_gen_name_iscaps (const char *name);

/* header functions */
struct ig_lib_db *ig_lib_db_new ()
{
    struct ig_lib_db *result = g_slice_new (struct ig_lib_db);

    result->objects_by_id     = g_hash_table_new (g_str_hash, g_str_equal);
    result->modules_by_id     = g_hash_table_new (g_str_hash, g_str_equal);
    result->modules_by_name   = g_hash_table_new (g_str_hash, g_str_equal);
    result->instances_by_id   = g_hash_table_new (g_str_hash, g_str_equal);
    result->instances_by_name = g_hash_table_new (g_str_hash, g_str_equal);

    result->str_chunks = g_string_chunk_new (128);

    return result;
}

void ig_lib_db_free (struct ig_lib_db *db)
{
    if (db == NULL) return;

    g_hash_table_destroy (db->objects_by_id);
    g_hash_table_destroy (db->modules_by_id);
    g_hash_table_destroy (db->modules_by_name);
    g_hash_table_destroy (db->instances_by_id);
    g_hash_table_destroy (db->instances_by_name);

    g_string_chunk_free (db->str_chunks);
}

struct ig_module *ig_lib_add_module (struct ig_lib_db *db, const char *name, bool ilm, bool resource)
{
    if (db == NULL) return NULL;
    if (name == NULL) return NULL;

    if (g_hash_table_contains (db->modules_by_name, name)) {
        log_error ("EAExi", "module %s already exists", name);
        return NULL;
    }

    struct ig_module *mod = ig_module_new (name, ilm, resource, db->str_chunks);

    if (g_hash_table_contains (db->objects_by_id, mod->object->id)) {
        log_error ("EAExi", "object %s already exists", mod->object->id);
        ig_module_free (mod);
        return NULL;
    }

    char *l_name = g_string_chunk_insert_const (db->str_chunks, mod->name);
    char *l_id   = g_string_chunk_insert_const (db->str_chunks, mod->object->id);

    g_hash_table_insert (db->modules_by_name, l_name, mod);
    g_hash_table_insert (db->modules_by_id,   l_id,   mod);
    g_hash_table_insert (db->objects_by_id,   l_id,   mod->object);

    return mod;
}

struct ig_instance *ig_lib_add_instance (struct ig_lib_db *db, const char *name, struct ig_module *type, struct ig_module *parent)
{
    if (db == NULL) return NULL;
    if (name == NULL) return NULL;
    if (type == NULL) return NULL;
    if (parent == NULL) return NULL;

    if (g_hash_table_contains (db->instances_by_name, name)) {
        log_error ("EAExi", "instance %s already exists", name);
        return NULL;
    }

    struct ig_instance *inst = NULL;

    if (!type->resource) {
        if (strcmp (name, type->default_instance->name) != 0) {
            log_error ("ENoRs", "module %s is no resource - so only a default instance is valid", type->name);
            return NULL;
        }
        if (type->default_instance->parent != NULL) {
            log_error ("ENoRs", "module %s is no resource and is already instanciated", type->name);
            return NULL;
        }

        inst = type->default_instance;

        inst->parent = parent;
        ig_obj_attr_set (inst->object, "parent", parent->object->id, true);
        g_queue_push_tail (parent->child_instances, inst);
    } else {
        inst = ig_instance_new (name, type, parent, db->str_chunks);
    }

    char *l_name = g_string_chunk_insert_const (db->str_chunks, inst->name);
    char *l_id   = g_string_chunk_insert_const (db->str_chunks, inst->object->id);

    g_hash_table_insert (db->instances_by_name, l_name, inst);
    g_hash_table_insert (db->instances_by_id,   l_id,   inst);
    g_hash_table_insert (db->objects_by_id,     l_id,   inst->object);

    return inst;
}

struct ig_code *ig_lib_add_codesection (struct ig_lib_db *db, const char *name, const char *code, struct ig_module *parent)
{
    if (db == NULL) return NULL;
    if (code == NULL) return NULL;
    if (parent == NULL) return NULL;

    struct ig_code *cs = ig_code_new (name, code, parent, db->str_chunks);

    char *l_id = g_string_chunk_insert_const (db->str_chunks, cs->object->id);

    g_hash_table_insert (db->objects_by_id, l_id, cs->object);

    return cs;
}

bool ig_lib_connection (struct ig_lib_db *db, const char *signame, struct ig_lib_connection_info *source, GList *targets, GList **gen_objs)
{
    GList *hier_start_list = NULL;

    log_debug ("LCnUD", "creating individual hierarchies...");
    bool error = false;

    if (source != NULL) {
        source->dir = IG_LCDIR_UP;
        source->is_explicit = true;
        log_debug ("LCnUd", "creating startpoint hierarchy...");
        GList *source_hier = ig_lib_gen_hierarchy (db, source);
        if (source_hier == NULL) {
            error = true;
        } else {
            hier_start_list = g_list_prepend (hier_start_list, source_hier);
        }
        log_debug ("LCnUd", "startpoint hierarchy depth: %d", g_list_length (source_hier));
    }

    for (GList *li = targets; li != NULL; li = li->next) {
        struct ig_lib_connection_info *start = (struct ig_lib_connection_info *) li->data;
        start->is_explicit = true;

        log_debug ("LCnUd", "creating targetpoint hierarchy...");
        GList *target_hier = ig_lib_gen_hierarchy (db, start);
        if (target_hier == NULL) {
            error = true;
        } else {
            hier_start_list = g_list_prepend (hier_start_list, target_hier);
        }
        log_debug ("LCnUd", "targetpoint hierarchy depth: %d", g_list_length (target_hier));
    }

    g_list_free (targets);

    bool result = true;

    if (error) {
        result = false;
        goto l_ig_lib_connection_unidir_final_free_hierlist;
    }

    log_debug ("LCnUd", "merging to hierarchy tree...");
    /* create hierarchy tree */
    GNode *hier_tree = ig_lib_merge_hierarchy_list (db, hier_start_list, signame);

    if (hier_tree == NULL) {
        result = false;
        goto l_ig_lib_connection_unidir_final_free_hierlist;
    }

    log_debug ("LCnUd", "printing hierarchy tree...");
    /* debug: printout */
    ig_lib_htree_print (hier_tree);

    log_debug ("LCnUd", "reducing hierarchy tree...");
    hier_tree = ig_lib_htree_reduce (hier_tree);

    ig_lib_htree_print (hier_tree);

    log_debug ("LCnUd", "processing hierarchy tree...");
    GList *gen_objs_res = ig_lib_htree_process (db, hier_tree);
    if (gen_objs_res != NULL) {
        log_info ("LCnUd", "successfully created signal %s", signame);
    } else {
        log_warn ("LCnUd", "nothing created for signal %s", signame);
    }
    if (gen_objs != NULL) *gen_objs = gen_objs_res;
    for (GList *li = gen_objs_res; li != NULL; li = li->next) {
        struct ig_object *io = (struct ig_object *) li->data;
        ig_obj_attr_set (io, "signal", signame, true);
    }

    log_debug ("LCnUd", "deleting hierarchy tree...");
    ig_lib_htree_free (hier_tree);

l_ig_lib_connection_unidir_final_free_hierlist:
    for (GList *li = hier_start_list; li != NULL; li = li->next) {
        GList *hier = (GList *) li->data;
        for (GList *lj = hier; lj != NULL; lj = lj->next) {
            struct ig_lib_connection_info *cinfo = (struct ig_lib_connection_info *) lj->data;
            ig_lib_connection_info_free (cinfo);
        }
        g_list_free (hier);
    }
    g_list_free (hier_start_list);

    return result;
}

static GNode *ig_lib_merge_hierarchy_list (struct ig_lib_db *db, GList *hier_list, const char *signame)
{
    if (db == NULL) return NULL;
    if (hier_list == NULL) return NULL;

    log_debug ("LMrHi", "merging a hierarchy level...");

    GNode *result = NULL;

    /* check for equality */
    GList *lhier_first = (GList *) hier_list->data;
    struct ig_lib_connection_info *cinfo_first = (struct ig_lib_connection_info *) lhier_first->data;

    struct ig_lib_connection_info *cinfo_node = ig_lib_connection_info_copy (db->str_chunks, cinfo_first);
    if (cinfo_node == NULL) return NULL;
    log_debug ("LMrHi", "reference node: %s", cinfo_first->obj->id);

    GList *successor_list = NULL;
    if (lhier_first->next != NULL) {
        successor_list = g_list_prepend (successor_list, lhier_first->next);
    }

    for (GList *li = hier_list->next; li != NULL; li = li->next) {
        GList *lhier = (GList *) li->data;
        if (lhier == NULL) continue;
        struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *) lhier->data;
        log_debug ("LMrHi", "current node: %s", i_cinfo->obj->id);

        /* object equality */
        if (i_cinfo->obj != cinfo_node->obj) {
            ig_lib_connection_info_free (cinfo_node);
            log_error ("LMrHi", "hierarchy has no common start (%s and %s)", i_cinfo->obj->id, cinfo_node->obj->id);
            g_list_free (successor_list);
            return NULL;
        }

        /* local name? */
        if (i_cinfo->local_name != NULL) {
            cinfo_node->local_name = i_cinfo->local_name;
            cinfo_node->force_name = i_cinfo->force_name;
        }

        /* dir merge */
        if (cinfo_node->dir == IG_LCDIR_DEFAULT) {
            cinfo_node->dir = i_cinfo->dir;
        } else if ((i_cinfo->dir != IG_LCDIR_DEFAULT) && (i_cinfo->dir != cinfo_node->dir)) {
            log_warn ("LMrHi", "merging ports to bidirectional");
            cinfo_node->dir = IG_LCDIR_BIDIR;
        }

        /* explicit */
        if (i_cinfo->is_explicit) cinfo_node->is_explicit = true;

        if (lhier->next != NULL) {
            successor_list = g_list_prepend (successor_list, lhier->next);
        }
    }

    if (cinfo_node->local_name == NULL) cinfo_node->local_name = signame;
    result = g_node_new (cinfo_node);

    log_debug ("LMrHi", "generating subhierarchies (successor_list size is %d)...", g_list_length (successor_list));
    /* generate children */
    while (successor_list != NULL) {
        /* pick one */
        GList *equal_list = successor_list;
        GList *ref_hier_list = (GList *) equal_list->data;
        struct ig_lib_connection_info *ref_cinfo = (struct ig_lib_connection_info *) ref_hier_list->data;
        log_debug ("LMrHi", "current node: %s", ref_cinfo->obj->id);

        successor_list = g_list_remove_link (successor_list, equal_list);

        GList *li = successor_list;
        while (li != NULL) {
            GList *i_hier_list = (GList *) li->data;
            struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *) i_hier_list->data;

            if (i_cinfo->obj == ref_cinfo->obj) {
                /* part of equal list */
                GList *li_next = li->next;
                successor_list = g_list_remove_link (successor_list, li);
                equal_list = g_list_concat (equal_list, li);
                li = li_next;
            } else {
                li = li->next;
            }
        }

        GNode *child_node = ig_lib_merge_hierarchy_list (db, equal_list, cinfo_node->local_name);

        child_node = g_node_insert (result, 0, child_node);

        g_list_free (equal_list);
    }

    return result;
}


static GList *ig_lib_gen_hierarchy (struct ig_lib_db *db, struct ig_lib_connection_info *cinfo)
{
    GList *result = NULL;

    bool copy_first = false;

    /* startpoint is instance of generated module? */
    if (cinfo->obj->type == IG_OBJ_INSTANCE) {
        struct ig_instance *inst = (struct ig_instance *) cinfo->obj->obj;
        struct ig_module   *mod  = inst->module;

        if (!mod->resource) {
            cinfo->obj = mod->object;
            copy_first = true;
        }
    } else if (cinfo->obj->type == IG_OBJ_MODULE) {
        struct ig_module *mod = (struct ig_module *) cinfo->obj->obj;
        if (!mod->resource) {
            copy_first = true;
        }
    }

    log_debug ("LGnHi", "creating hierarchy list...");
    while (true) {
        if (cinfo == NULL) return result;

        log_debug ("LGnHi", "hierarchy element: %s", cinfo->obj->id);

        if (cinfo->obj->type == IG_OBJ_INSTANCE) {
            result = g_list_prepend (result, cinfo);
            struct ig_instance *inst = (struct ig_instance *) cinfo->obj->obj;
            if (inst->parent == NULL) return result;
            cinfo = ig_lib_connection_info_new (db->str_chunks, inst->parent->object, NULL, cinfo->dir);
            continue;
        } else if (cinfo->obj->type == IG_OBJ_MODULE) {
            result = g_list_prepend (result, cinfo);
            struct ig_module *mod = (struct ig_module *) cinfo->obj->obj;
            if (mod->default_instance == NULL) return result;
            if (copy_first) {
                bool force_name = cinfo->force_name;
                cinfo = ig_lib_connection_info_new (db->str_chunks, mod->default_instance->object, cinfo->local_name, cinfo->dir);
                cinfo->force_name = force_name;
                copy_first = false;
            } else {
                cinfo = ig_lib_connection_info_new (db->str_chunks, mod->default_instance->object, NULL, cinfo->dir);
            }
            continue;
        } else {
            log_errorint ("LGnHi", "object of invalid type in module/instance hierarchy");
            ig_lib_connection_info_free (cinfo);
            for (GList *li = result; li != NULL; li = li->next) {
                ig_lib_connection_info_free ((struct ig_lib_connection_info *) li->data);
            }
            g_list_free (result);
            return NULL;
        }
    }
}

struct ig_lib_connection_info *ig_lib_connection_info_new (GStringChunk *str_chunks, struct ig_object *obj, const char *local_name, enum ig_lib_connection_dir dir)
{
    if (obj == NULL) return NULL;
    if ((str_chunks == NULL) && (local_name != NULL)) return NULL;

    struct ig_lib_connection_info *result = g_slice_new (struct ig_lib_connection_info);

    result->obj = obj;
    result->dir = dir;
    result->is_explicit = false;
    result->force_name  = false;

    if (local_name == NULL) {
        result->local_name = NULL;
    } else {
        result->local_name = g_string_chunk_insert_const (str_chunks, local_name);
    }

    result->parent_name = NULL;

    return result;
}

struct ig_lib_connection_info *ig_lib_connection_info_copy (GStringChunk *str_chunks, struct ig_lib_connection_info *original)
{
    if (original == NULL) return NULL;
    if ((str_chunks == NULL) && ((original->local_name != NULL) || (original->parent_name != NULL))) return NULL;

    struct ig_lib_connection_info *result = g_slice_new (struct ig_lib_connection_info);

    result->obj = original->obj;
    result->dir = original->dir;
    result->is_explicit = original->is_explicit;
    result->force_name  = original->force_name;

    if (original->local_name != NULL) {
        result->local_name = g_string_chunk_insert_const (str_chunks, original->local_name);
    } else {
        result->local_name = NULL;
    }

    if (original->parent_name != NULL) {
        result->parent_name = g_string_chunk_insert_const (str_chunks, original->parent_name);
    } else {
        result->parent_name = NULL;
    }

    return result;
}

void ig_lib_connection_info_free (struct ig_lib_connection_info *cinfo)
{
    if (cinfo == NULL) return;
    g_slice_free (struct ig_lib_connection_info, cinfo);
}

static void ig_lib_htree_print (GNode *hier_tree)
{
    GSList *pr_stack = NULL;
    int pr_indent = 0;
    pr_stack = g_slist_prepend (pr_stack, hier_tree);

    while (pr_stack != NULL) {
        GNode *i_node = (GNode *) pr_stack->data;
        log_debug ("LPHTr", "current node: depth=%d, n_children=%d", g_node_depth (i_node), g_node_n_children (i_node));
        struct ig_lib_connection_info *i_info = (struct ig_lib_connection_info *) i_node->data;

        /* print node */
        GString *str_t = g_string_new (NULL);
        for (int i = 0; i < pr_indent-1; i++) {
            str_t = g_string_append (str_t, " | ");
        }
        if (pr_indent > 0) {
            str_t = g_string_append (str_t, " +-");
        }
        str_t = g_string_append (str_t, "-*-");

        if (i_info->dir == IG_LCDIR_UP) {
            str_t = g_string_append (str_t, "<-- ");
        } else if (i_info->dir == IG_LCDIR_BIDIR) {
            str_t = g_string_append (str_t, "<-> ");
        } else if (i_info->dir == IG_LCDIR_DOWN) {
            str_t = g_string_append (str_t, "--> ");
        } else {
            str_t = g_string_append (str_t, "-?- ");
        }

        str_t = g_string_append (str_t, i_info->obj->id);
        str_t = g_string_append (str_t, ".");
        str_t = g_string_append (str_t, i_info->local_name);
        if (i_info->is_explicit) {
            str_t = g_string_append (str_t, "(explicit)");
        }

        log_debug ("HTree", "%s", str_t->str);
        g_string_free (str_t, true);

        /* modify stack and continue */
        if (g_node_first_child (i_node) != NULL) {
            log_debug ("LPHTr", "node has child...");
            pr_indent++;
            pr_stack = g_slist_prepend (pr_stack, g_node_first_child (i_node));
            continue;
        }

        while (pr_stack != NULL) {
            i_node = (GNode *) pr_stack->data;
            if (g_node_next_sibling (i_node) != NULL) {
                log_debug ("LPHTr", "node has sibling...");
                pr_stack->data = g_node_next_sibling (i_node);
                break;
            }
            log_debug ("LPHTr", "node is last one in subhierarchy...");
            pr_indent--;
            GSList *temp = pr_stack;
            pr_stack = g_slist_remove_link (pr_stack, temp);
            g_slist_free (temp);
        }
    }
}

static GNode *ig_lib_htree_reduce (GNode *hier_tree)
{
    GNode *temp = hier_tree;

    while (temp != NULL) {
        if (g_node_n_children (temp) > 1) break;
        struct ig_lib_connection_info *cinfo = (struct ig_lib_connection_info *) temp->data;
        if (cinfo->is_explicit) break;
        temp = g_node_first_child (temp);
    }

    if (temp == NULL) {
        if (hier_tree != NULL) ig_lib_htree_free (hier_tree);
        return NULL;
    }

    g_node_unlink (temp);
    ig_lib_htree_free (hier_tree);

    return temp;
}

struct ig_lib_htree_process_data {
    struct ig_lib_db *db;
    GList            *gen_objs;
};

static GList *ig_lib_htree_process (struct ig_lib_db *db, GNode *hier_tree)
{
    struct ig_lib_htree_process_data data = {db, NULL};

    g_node_traverse (hier_tree, G_PRE_ORDER, G_TRAVERSE_ALL, -1, ig_lib_htree_process_tfunc, &data);

    return data.gen_objs;
}

static gboolean ig_lib_htree_process_tfunc (GNode *node, gpointer data)
{
    struct ig_lib_htree_process_data *pdata = (struct ig_lib_htree_process_data *) data;

    struct ig_lib_connection_info *cinfo = (struct ig_lib_connection_info *) node->data;
    struct ig_lib_db *db = (struct ig_lib_db *) pdata->db;

    struct ig_object *obj = cinfo->obj;

    const char *local_name  = cinfo->local_name;
    const char *parent_name = cinfo->parent_name;

    log_debug ("HTrPr", "processing node %s", obj->id);

    if (obj->type == IG_OBJ_INSTANCE) {
        struct ig_instance *inst = (struct ig_instance *) obj->obj;

        const char *conn_name = parent_name;
        if (conn_name == NULL) {
            log_error ("HTrPr", "No connection for signal %s in instance %s", local_name, obj->id);
            conn_name = "";
        }

        const char *pin_name;

        if (cinfo->force_name) {
            pin_name = local_name;
        } else {
            enum ig_port_dir pdir = IG_PD_IN;
            if (cinfo->dir == IG_LCDIR_UP) {
                pdir = IG_PD_OUT;
            } else if (cinfo->dir == IG_LCDIR_BIDIR) {
                pdir = IG_PD_BIDIR;
            }
            pin_name = ig_lib_gen_name_pinport (db, local_name, pdir);
        }

        /* create a pin */
        struct ig_pin *inst_pin = ig_pin_new (pin_name, conn_name, inst, db->str_chunks);
        if (g_hash_table_contains (db->objects_by_id, inst_pin->object->id)) {
            log_error ("HTrPr", "Already declared pin %s", inst_pin->object->id);
        }
        g_hash_table_insert (db->objects_by_id, g_string_chunk_insert_const (db->str_chunks, inst_pin->object->id), inst_pin->object);
        pdata->gen_objs = g_list_prepend (pdata->gen_objs, inst_pin->object);

        log_debug ("HTrPr", "Created pin \"%s\" in instance \"%s\" connected to \"%s\"", pin_name, inst->object->id, conn_name);
        for (GNode *in = g_node_first_child (node); in != NULL; in = g_node_next_sibling (in)) {
            struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *) in->data;
            i_cinfo->parent_name = pin_name;
        }
    } else if (obj->type == IG_OBJ_MODULE) {
        struct ig_module *mod = (struct ig_module *) obj->obj;

        const char *signal_name = NULL;

        if (G_NODE_IS_ROOT (node)) {
            if (cinfo->force_name) {
                signal_name = local_name;
            } else {
                signal_name = ig_lib_gen_name_signal (db, local_name);
            }

            /* create a declaration */
            struct ig_decl *mod_decl = ig_decl_new (signal_name, NULL, true, mod, db->str_chunks);
            if (g_hash_table_contains (db->objects_by_id, mod_decl->object->id)) {
                log_error ("HTrPr", "Already declared declaration %s", mod_decl->object->id);
            }
            g_hash_table_insert (db->objects_by_id, g_string_chunk_insert_const (db->str_chunks, mod_decl->object->id), mod_decl->object);
            pdata->gen_objs = g_list_prepend (pdata->gen_objs, mod_decl->object);

            log_debug ("HTrPr", "Created declaration \"%s\" in module \"%s\"", signal_name, mod->object->id);
        } else {
            signal_name = parent_name;
            if (signal_name == NULL) {
                log_error ("HTrPr", "No pin for signal %s in instance of module %s", local_name, obj->id);
                signal_name = "";
            }

            enum ig_port_dir pdir = IG_PD_IN;
            if (cinfo->dir == IG_LCDIR_UP) {
                pdir = IG_PD_OUT;
            } else if (cinfo->dir == IG_LCDIR_BIDIR) {
                pdir = IG_PD_BIDIR;
            }
            /* create a port */
            struct ig_port *mod_port = ig_port_new (signal_name, pdir, mod, db->str_chunks);
            if (g_hash_table_contains (db->objects_by_id, mod_port->object->id)) {
                log_error ("HTrPr", "Already declared port %s", mod_port->object->id);
            }
            g_hash_table_insert (db->objects_by_id, g_string_chunk_insert_const (db->str_chunks, mod_port->object->id), mod_port->object);
            pdata->gen_objs = g_list_prepend (pdata->gen_objs, mod_port->object);

            log_debug ("HTrPr", "Created port \"%s\" in module \"%s\"", signal_name, mod->object->id);
        }

        for (GNode *in = g_node_first_child (node); in != NULL; in = g_node_next_sibling (in)) {
            struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *) in->data;
            i_cinfo->parent_name = signal_name;
        }
    } else {
        log_errorint ("HTrPr", "invalid object in hierarchy tree");
    }

    return false;
}

static void ig_lib_htree_free (GNode *hier_tree)
{
    g_node_traverse (hier_tree, G_LEVEL_ORDER, G_TRAVERSE_ALL, -1, ig_lib_htree_free_tfunc, NULL);
    g_node_destroy (hier_tree);
}

static gboolean ig_lib_htree_free_tfunc (GNode *node, gpointer data)
{
    struct ig_lib_connection_info *cinfo = (struct ig_lib_connection_info *) node->data;
    ig_lib_connection_info_free (cinfo);
    node->data = NULL;

    return false;
}

static bool ig_lib_gen_name_iscaps (const char *name) {
    if (name == NULL) return false;

    bool hasupper = false;

    for (const char *ic = name; *ic != '\0'; ic++) {
        if (g_ascii_islower (*ic)) return false;
        if (g_ascii_isupper (*ic)) hasupper = true;
    }

    return hasupper;
}

static char *ig_lib_gen_name_signal (struct ig_lib_db *db, const char *basename)
{
    GString *tstr = g_string_new (basename);

    if (ig_lib_gen_name_iscaps (basename)) {
        tstr = g_string_append (tstr, "_S");
    } else {
        tstr = g_string_append (tstr, "_s");
    }

    char *result = g_string_chunk_insert_const (db->str_chunks, tstr->str);
    g_string_free (tstr, true);

    return result;
}

static char *ig_lib_gen_name_pinport (struct ig_lib_db *db, const char *basename, enum ig_port_dir dir)
{
    GString *tstr = g_string_new (basename);

    if (dir == IG_PD_IN) {
        if (ig_lib_gen_name_iscaps (basename)) {
            tstr = g_string_append (tstr, "_I");
        } else {
            tstr = g_string_append (tstr, "_i");
        }
    } else if (dir == IG_PD_OUT) {
        if (ig_lib_gen_name_iscaps (basename)) {
            tstr = g_string_append (tstr, "_O");
        } else {
            tstr = g_string_append (tstr, "_o");
        }
    } else if (dir == IG_PD_BIDIR) {
        if (ig_lib_gen_name_iscaps (basename)) {
            tstr = g_string_append (tstr, "_B");
        } else {
            tstr = g_string_append (tstr, "_b");
        }
    }

    char *result = g_string_chunk_insert_const (db->str_chunks, tstr->str);
    g_string_free (tstr, true);

    return result;
}
