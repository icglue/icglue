#include "ig_lib.h"
#include "logger.h"

#include <stdio.h>
#include <string.h>

/* static functions */
static GList *ig_lib_gen_hierarchy (struct ig_lib_db *db, struct ig_lib_connection_info *cinfo);
static GNode *ig_lib_merge_hierarchy_list (struct ig_lib_db *db, GList *hier_list, const char *signame);

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
        fprintf (stderr, "Error: module %s already exists\n", name);
        return NULL;
    }

    struct ig_module *mod = ig_module_new (name, ilm, resource, db->str_chunks);

    if (g_hash_table_contains (db->objects_by_id, mod->object->id)) {
        fprintf (stderr, "Error: object %s already exists\n", mod->object->id);
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
        fprintf (stderr, "Error: instance %s already exists\n", name);
        return NULL;
    }

    struct ig_instance *inst = NULL;

    if (!type->resource) {
        if (strcmp (name, type->default_instance->name) != 0) {
            fprintf (stderr, "Error: module %s is no resource - so only a default instance is valid\n", type->name);
            return NULL;
        }
        if (type->default_instance->parent != NULL) {
            fprintf (stderr, "Error: module %s is no resource and is already instanciated\n", type->name);
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


bool ig_lib_connection_unidir (struct ig_lib_db *db, const char *signame, struct ig_lib_connection_info *source, GList *targets)
{
    GList *hier_start_list = NULL;

    //fprintf (stderr, "DEBUG: creating individual hierarchies...\n");
    bool error = false;
    source->dir = IG_LCDIR_UP;
    source->is_explicit = true;
    //fprintf (stderr, "DEBUG: creating startpoint hierarchy...\n");
    GList *source_hier = ig_lib_gen_hierarchy (db, source);
    if (source_hier == NULL) {
        error = true;
    } else {
        hier_start_list = g_list_prepend (hier_start_list, source_hier);
    }
    //fprintf (stderr, "DEBUG: startpoint hierarchy depth: %d\n", g_list_length (source_hier));
    for (GList *li = targets; li != NULL; li = li->next) {
        struct ig_lib_connection_info *start = (struct ig_lib_connection_info *) li->data;
        start->is_explicit = true;

        //fprintf (stderr, "DEBUG: creating targetpoint hierarchy...\n");
        GList *target_hier = ig_lib_gen_hierarchy (db, start);
        if (target_hier == NULL) {
            error = true;
        } else {
            hier_start_list = g_list_prepend (hier_start_list, target_hier);
        }
        //fprintf (stderr, "DEBUG: targetpoint hierarchy depth: %d\n", g_list_length (target_hier));
    }

    g_list_free (targets);

    bool result = true;

    if (error) {
        result = false;
        goto l_ig_lib_connection_unidir_final_free_hierlist;
    }

    //fprintf (stderr, "DEBUG: merging to hierarchy tree...\n");
    /* create hierarchy tree */
    GNode *hier_tree = ig_lib_merge_hierarchy_list (db, hier_start_list, signame);

    if (hier_tree == NULL) {
        result = false;
        goto l_ig_lib_connection_unidir_final_free_hierlist;
    }

    //fprintf (stderr, "DEBUG: printing hierarchy tree...\n");
    /* debug: printout */
    GSList *pr_stack = NULL;
    int pr_indent = 0;
    pr_stack = g_slist_prepend (pr_stack, hier_tree);

    while (pr_stack != NULL) {
        GNode *i_node = (GNode *) pr_stack->data;
        //fprintf (stderr, "DEBUG: current node: depth=%d, n_children=%d\n", g_node_depth (i_node), g_node_n_children (i_node));
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

        log_debug ("con-udir", "%s", str_t->str);
        g_string_free (str_t, true);

        /* modify stack and continue */
        if (g_node_first_child (i_node) != NULL) {
            //fprintf (stderr, "DEBUG: node has child...\n");
            pr_indent++;
            pr_stack = g_slist_prepend (pr_stack, g_node_first_child (i_node));
            continue;
        }

        while (pr_stack != NULL) {
            i_node = (GNode *) pr_stack->data;
            if (g_node_next_sibling (i_node) != NULL) {
                //fprintf (stderr, "DEBUG: node has sibling...\n");
                pr_stack->data = g_node_next_sibling (i_node);
                break;
            }
            //fprintf (stderr, "DEBUG: node is last one in subhierarchy...\n");
            pr_indent--;
            GSList *temp = pr_stack;
            pr_stack = g_slist_remove_link (pr_stack, temp);
            g_slist_free (temp);
        }
    }


    /* TODO:
     * - create ports/pins
     * - free tree
     */

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

    //fprintf (stderr, "DEBUG: merging a hierarchy level...\n");

    GNode *result = NULL;

    /* check for equality */
    GList *lhier_first = (GList *) hier_list->data;
    struct ig_lib_connection_info *cinfo_first = (struct ig_lib_connection_info *) lhier_first->data;

    struct ig_lib_connection_info *cinfo_node = ig_lib_connection_info_copy (db->str_chunks, cinfo_first);
    if (cinfo_node == NULL) return NULL;
    //fprintf (stderr, "DEBUG: reference node: %s\n", cinfo_first->obj->id);

    GList *successor_list = NULL;
    if (lhier_first->next != NULL) {
        successor_list = g_list_prepend (successor_list, lhier_first->next);
    }

    for (GList *li = hier_list->next; li != NULL; li = li->next) {
        GList *lhier = (GList *) li->data;
        if (lhier == NULL) continue;
        struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *) lhier->data;
        //fprintf (stderr, "DEBUG: current node: %s\n", i_cinfo->obj->id);

        /* object equality */
        if (i_cinfo->obj != cinfo_node->obj) {
            ig_lib_connection_info_free (cinfo_node);
            fprintf (stderr, "Error: hierarchy has no common start (%s and %s)\n", i_cinfo->obj->id, cinfo_node->obj->id);
            g_list_free (successor_list);
            return NULL;
        }

        /* local name? */
        if (i_cinfo->local_name != NULL) cinfo_node->local_name = i_cinfo->local_name;

        /* dir merge */
        if (cinfo_node->dir == IG_LCDIR_DEFAULT) {
            cinfo_node->dir = i_cinfo->dir;
        } else if ((i_cinfo->dir != IG_LCDIR_DEFAULT) && (i_cinfo->dir != cinfo_node->dir)) {
            fprintf (stderr, "Warning: merging ports to bidirectional\n");
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

    //fprintf (stderr, "DEBUG: generating subhierarchies (successor_list size is %d)...\n", g_list_length (successor_list));
    /* generate children */
    while (successor_list != NULL) {
        /* pick one */
        GList *equal_list = successor_list;
        GList *ref_hier_list = (GList *) equal_list->data;
        struct ig_lib_connection_info *ref_cinfo = (struct ig_lib_connection_info *) ref_hier_list->data;
        //fprintf (stderr, "DEBUG: current node: %s\n", ref_cinfo->obj->id);

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

    //fprintf (stderr, "DEBUG: creating hierarchy list...\n");
    while (true) {
        if (cinfo == NULL) return result;

        //fprintf (stderr, "DEBUG: hierarchy element: %s\n", cinfo->obj->id);

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
            cinfo = ig_lib_connection_info_new (db->str_chunks, mod->default_instance->object, NULL, cinfo->dir);
            continue;
        } else {
            fprintf (stderr, "Internal Error: object of invalid type in module/instance hierarchy\n");
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

    if (local_name == NULL) {
        result->local_name = NULL;
    } else {
        result->local_name = g_string_chunk_insert_const (str_chunks, local_name);
    }

    return result;
}

struct ig_lib_connection_info *ig_lib_connection_info_copy (GStringChunk *str_chunks, struct ig_lib_connection_info *original)
{
    if (original == NULL) return NULL;
    if ((str_chunks == NULL) && (original->local_name != NULL)) return NULL;

    struct ig_lib_connection_info *result = g_slice_new (struct ig_lib_connection_info);

    result->obj = original->obj;
    result->dir = original->dir;
    result->is_explicit = original->is_explicit;

    if (original->local_name != NULL) {
        result->local_name = g_string_chunk_insert_const (str_chunks, original->local_name);
    } else {
        result->local_name = NULL;
    }

    return result;
}

void ig_lib_connection_info_free (struct ig_lib_connection_info *cinfo)
{
    if (cinfo == NULL) return;
    g_slice_free (struct ig_lib_connection_info, cinfo);
}
