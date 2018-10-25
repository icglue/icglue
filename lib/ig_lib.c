/*
 *  ICGlue is a Tcl-Library for scripted HDL generation
 *  Copyright (C) 2017-2018  Andreas Dixius, Felix Neumärker
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

#include "ig_lib.h"
#include "logger.h"

#include <stdio.h>
#include <string.h>

/* static functions */
static GList   *ig_lib_gen_hierarchy (struct ig_lib_db *db, struct ig_lib_connection_info *cinfo);
static bool     ig_lib_check_cycle (struct ig_lib_db *db, struct ig_instance *child, struct ig_module *parent);
static GNode   *ig_lib_merge_hierarchy_list (struct ig_lib_db *db, GList *hier_list, const char *signame);
static void     ig_lib_htree_print (GNode *hier_tree);
static GNode   *ig_lib_htree_reduce (GNode *hier_tree);
static GList   *ig_lib_htree_process_signal (struct ig_lib_db *db, GNode *hier_tree);
static gboolean ig_lib_htree_process_signal_tfunc (GNode *node, gpointer data);
static GList   *ig_lib_htree_process_parameter (struct ig_lib_db *db, GNode *hier_tree, const char *defvalue);
static gboolean ig_lib_htree_process_parameter_tfunc (GNode *node, gpointer data);
static void     ig_lib_htree_free (GNode *hier_tree);
static gboolean ig_lib_htree_free_tfunc (GNode *node, gpointer data);

static struct ig_net *ig_lib_add_net (struct ig_lib_db *db, const char *netname, GList *objs);

static char *ig_lib_gen_name_signal  (struct ig_lib_db *db, const char *basename);
static char *ig_lib_gen_name_pinport (struct ig_lib_db *db, const char *basename, enum ig_port_dir dir);
static char *ig_lib_rm_suffix_pinport (struct ig_lib_db *db, const char *pinportname);
static bool  ig_lib_gen_name_iscaps (const char *name);

/* header functions */
struct ig_lib_db *ig_lib_db_new ()
{
    struct ig_lib_db *result = g_slice_new (struct ig_lib_db);

    result->objects_by_id     = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, (GDestroyNotify)ig_obj_unref);
    result->modules_by_id     = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, (GDestroyNotify)ig_obj_unref);
    result->modules_by_name   = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, (GDestroyNotify)ig_obj_unref);
    result->instances_by_id   = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, (GDestroyNotify)ig_obj_unref);
    result->instances_by_name = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, (GDestroyNotify)ig_obj_unref);
    result->nets_by_id        = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, (GDestroyNotify)ig_obj_unref);
    result->nets_by_name      = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, (GDestroyNotify)ig_obj_unref);

    result->str_chunks = g_string_chunk_new (128);

    return result;
}

void ig_lib_db_clear (struct ig_lib_db *db)
{
    g_hash_table_remove_all (db->modules_by_id);
    g_hash_table_remove_all (db->modules_by_name);
    g_hash_table_remove_all (db->instances_by_id);
    g_hash_table_remove_all (db->instances_by_name);
    g_hash_table_remove_all (db->nets_by_id);
    g_hash_table_remove_all (db->nets_by_name);
    g_hash_table_remove_all (db->objects_by_id);

    g_string_chunk_clear (db->str_chunks);
}

void ig_lib_db_free (struct ig_lib_db *db)
{
    if (db == NULL) return;

    g_hash_table_destroy (db->modules_by_id);
    g_hash_table_destroy (db->modules_by_name);
    g_hash_table_destroy (db->instances_by_id);
    g_hash_table_destroy (db->instances_by_name);
    g_hash_table_destroy (db->nets_by_id);
    g_hash_table_destroy (db->nets_by_name);
    g_hash_table_destroy (db->objects_by_id);

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

    if (g_hash_table_contains (db->objects_by_id, IG_OBJECT (mod)->id)) {
        log_errorint ("EAExi", "object %s already exists", IG_OBJECT (mod)->id);
        ig_module_free (mod);
        return NULL;
    }

    char *l_name = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (mod)->name);
    char *l_id   = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (mod)->id);

    g_hash_table_insert (db->modules_by_name, l_name, mod);
    g_hash_table_insert (db->modules_by_id,   l_id,   mod);
    g_hash_table_insert (db->objects_by_id,   l_id,   IG_OBJECT (mod));
    ig_obj_ref (IG_OBJECT (mod));
    ig_obj_ref (IG_OBJECT (mod));
    ig_obj_ref (IG_OBJECT (mod));

    return mod;
}

struct ig_pin *ig_lib_add_pin (struct ig_lib_db *db, struct ig_instance *inst, const char *pin_name, const char *conn_name, const char *invert_attr)
{
    /* create a pin */
    struct ig_pin *inst_pin = ig_pin_new (pin_name, conn_name, inst, db->str_chunks);

    ig_obj_attr_set (IG_OBJECT (inst_pin), "invert", invert_attr, false);
    if (g_hash_table_contains (db->objects_by_id, IG_OBJECT (inst_pin)->id)) {
        log_error ("CPin", "Already declared pin %s", IG_OBJECT (inst_pin)->id);
        ig_pin_free (inst_pin);
        inst_pin = NULL;
    } else {
        g_hash_table_insert (db->objects_by_id, g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (inst_pin)->id), IG_OBJECT (inst_pin));
        ig_obj_ref (IG_OBJECT (inst_pin));
        g_queue_push_tail (inst->pins, inst_pin);
        ig_obj_ref (IG_OBJECT (inst_pin));
    }

    return inst_pin;
}

static bool ig_lib_check_cycle (struct ig_lib_db *db, struct ig_instance *child, struct ig_module *parent)
{
    bool result = false;

    if (child == NULL) return false;
    if (parent == NULL) return false;

    struct ig_lib_connection_info *start = ig_lib_connection_info_new (db->str_chunks, IG_OBJECT (parent), NULL, IG_LCDIR_DEFAULT);
    GList                         *hlist = ig_lib_gen_hierarchy (db, start);

    if (hlist == NULL) return false;

    struct ig_object *root = ((struct ig_lib_connection_info *)hlist->data)->obj;

    if (strcmp (root->id, IG_OBJECT (child)->id) == 0) {
        result = true;
    }

    for (GList *li = hlist; li != NULL; li = li->next) {
        ig_lib_connection_info_free ((struct ig_lib_connection_info *)li->data);
    }
    g_list_free (hlist);

    return result;
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

    if (parent->resource) {
        log_error ("EPRes", "cannot create instances in resource module %s", IG_OBJECT (parent)->name);
        return NULL;
    }

    struct ig_instance *inst = NULL;

    if (!type->resource) {
        if (strcmp (name, IG_OBJECT (type->default_instance)->name) != 0) {
            log_error ("ENoRs", "module %s is no resource - so only a default instance is valid", IG_OBJECT (type)->name);
            return NULL;
        }
        if (type->default_instance->parent != NULL) {
            log_error ("ENoRs", "module %s is no resource and is already instantiated", IG_OBJECT (type)->name);
            return NULL;
        }

        inst = type->default_instance;

        if (ig_lib_check_cycle (db, inst, parent)) {
            log_error ("ECycl", "cannot instantiate module %s in module %s - would create hierarchy cycle!", IG_OBJECT (type)->name, IG_OBJECT (parent)->name);
            return NULL;
        }

        inst->parent = parent;
        ig_obj_attr_set (IG_OBJECT (inst), "parent", IG_OBJECT (parent)->id, true);
        g_queue_push_tail (parent->child_instances, inst);
        ig_obj_ref (IG_OBJECT (inst));
    } else {
        inst = ig_instance_new (name, type, parent, db->str_chunks);

        g_queue_push_tail (parent->child_instances, inst);
        ig_obj_ref (IG_OBJECT (inst));
        g_queue_push_tail (type->mod_instances, inst);
        ig_obj_ref (IG_OBJECT (inst));
    }

    char *l_name = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (inst)->name);
    char *l_id   = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (inst)->id);

    g_hash_table_insert (db->instances_by_name, l_name, inst);
    g_hash_table_insert (db->instances_by_id,   l_id,   inst);
    g_hash_table_insert (db->objects_by_id,     l_id,   IG_OBJECT (inst));
    ig_obj_ref (IG_OBJECT (inst));
    ig_obj_ref (IG_OBJECT (inst));
    ig_obj_ref (IG_OBJECT (inst));

    return inst;
}

struct ig_code *ig_lib_add_codesection (struct ig_lib_db *db, const char *name, const char *code, struct ig_module *parent)
{
    if (db == NULL) return NULL;
    if (code == NULL) return NULL;
    if (parent == NULL) return NULL;

    log_debug ("LACSc", "new codesection for module %s...", IG_OBJECT (parent)->name);
    struct ig_code *cs = ig_code_new (name, code, parent, db->str_chunks);

    if (cs == NULL) {
        log_error ("LACSc", "error while creating new codesection for module %s", IG_OBJECT (parent)->name);
        return NULL;
    }

    char *l_id = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (cs)->id);

    g_queue_push_tail (parent->code, cs);
    ig_obj_ref (IG_OBJECT (cs));

    g_hash_table_insert (db->objects_by_id, l_id, IG_OBJECT (cs));
    ig_obj_ref (IG_OBJECT (cs));
    log_debug ("LACSc", "...added codesection for module %s", IG_OBJECT (parent)->name);

    return cs;
}

struct ig_rf_regfile *ig_lib_add_regfile (struct ig_lib_db *db, const char *name, struct ig_module *parent)
{
    if (db == NULL) return NULL;
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;

    log_debug ("LARgf", "new regfile %s for module %s...", name, IG_OBJECT (parent)->name);
    struct ig_rf_regfile *rf = ig_rf_regfile_new (name, parent, db->str_chunks);

    if (rf == NULL) {
        log_error ("LARgf", "error while creating new regfile %s for module %s", name, IG_OBJECT (parent)->name);
        return NULL;
    }

    char *l_id = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (rf)->id);

    if (g_hash_table_contains (db->objects_by_id, l_id)) {
        log_error ("LARgf", "Regfile %s already exists", IG_OBJECT (rf)->name);
        ig_rf_regfile_free (rf);

        rf = NULL;
    } else {
        g_queue_push_tail (parent->regfiles, rf);
        ig_obj_ref (IG_OBJECT (rf));

        g_hash_table_insert (db->objects_by_id, l_id, IG_OBJECT (rf));
        ig_obj_ref (IG_OBJECT (rf));
        log_debug ("LARgf", "...added regfile %s for module %s", name, IG_OBJECT (parent)->name);
    }

    return rf;
}

struct ig_rf_entry *ig_lib_add_regfile_entry (struct ig_lib_db *db, const char *name, struct ig_rf_regfile *parent)
{
    if (db == NULL) return NULL;
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;

    log_debug ("LARfE", "new entry %s for regfile %s...", name, IG_OBJECT (parent)->name);
    struct ig_rf_entry *entry = ig_rf_entry_new (name, parent, db->str_chunks);

    if (entry == NULL) {
        log_error ("LARfE", "error while creating new entry %s for regfile %s", name, IG_OBJECT (parent)->name);
        return NULL;
    }

    char *l_id = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (entry)->id);

    if (g_hash_table_contains (db->objects_by_id, l_id)) {
        log_error ("LARfE", "Regfile-Entry %s already exists in regfile %s", IG_OBJECT (entry)->name, IG_OBJECT (parent)->name);
        ig_rf_entry_free (entry);

        entry = NULL;
    } else {
        g_queue_push_tail (parent->entries, entry);
        ig_obj_ref (IG_OBJECT (entry));

        g_hash_table_insert (db->objects_by_id, l_id, IG_OBJECT (entry));
        ig_obj_ref (IG_OBJECT (entry));
        log_debug ("LARfE", "...added entry %s for regfile %s", name, IG_OBJECT (parent)->name);
    }

    return entry;
}

struct ig_rf_reg *ig_lib_add_regfile_reg (struct ig_lib_db *db, const char *name, struct ig_rf_entry *parent)
{
    if (db == NULL) return NULL;
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;

    log_debug ("LARfR", "new reg %s for regfile-entrty %s...", name, IG_OBJECT (parent)->name);
    struct ig_rf_reg *reg = ig_rf_reg_new (name, parent, db->str_chunks);

    if (reg == NULL) {
        log_error ("LARfR", "error while creating new reg %s for regfile-entry %s", name, IG_OBJECT (parent)->name);
        return NULL;
    }

    char *l_id = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (reg)->id);

    if (g_hash_table_contains (db->objects_by_id, l_id)) {
        log_error ("LARfR", "Regfile-reg %s already exists in regfile-entry %s", IG_OBJECT (reg)->name, IG_OBJECT (parent)->name);
        ig_rf_reg_free (reg);

        reg = NULL;
    } else {
        g_queue_push_tail (parent->regs, reg);
        ig_obj_ref (IG_OBJECT (reg));

        g_hash_table_insert (db->objects_by_id, l_id, IG_OBJECT (reg));
        ig_obj_ref (IG_OBJECT (reg));
        log_debug ("LARfR", "...added reg %s for regfile-entry %s", name, IG_OBJECT (parent)->name);
    }

    return reg;
}


bool ig_lib_connection (struct ig_lib_db *db, const char *signame, struct ig_lib_connection_info *source, GList *targets, struct ig_net **gen_net)
{
    GList *hier_start_list = NULL;

    log_debug ("LConn", "creating individual hierarchies...");
    bool error = false;

    if (source != NULL) {
        source->dir         = IG_LCDIR_UP;
        source->is_explicit = true;
        log_debug ("LConn", "creating startpoint hierarchy...");
        GList *source_hier = ig_lib_gen_hierarchy (db, source);
        if (source_hier == NULL) {
            error = true;
        } else {
            hier_start_list = g_list_prepend (hier_start_list, source_hier);
        }
        log_debug ("LConn", "startpoint hierarchy depth: %d", g_list_length (source_hier));
    }

    for (GList *li = targets; li != NULL; li = li->next) {
        struct ig_lib_connection_info *start = (struct ig_lib_connection_info *)li->data;
        start->is_explicit = true;

        log_debug ("LConn", "creating targetpoint hierarchy...");
        GList *target_hier = ig_lib_gen_hierarchy (db, start);
        if (target_hier == NULL) {
            error = true;
        } else {
            hier_start_list = g_list_prepend (hier_start_list, target_hier);
        }
        log_debug ("LConn", "targetpoint hierarchy depth: %d", g_list_length (target_hier));
    }

    g_list_free (targets);

    bool result = true;

    if (error) {
        result = false;
        goto l_ig_lib_connection_final_free_hierlist;
    }

    if (g_hash_table_contains (db->nets_by_name, signame)) {
        log_error ("LConn", "signal %s already exists", signame);
        result = false;
        goto l_ig_lib_connection_final_free_hierlist;
    }

    log_debug ("LConn", "merging to hierarchy tree...");
    /* create hierarchy tree */
    GNode *hier_tree = ig_lib_merge_hierarchy_list (db, hier_start_list, signame);

    if (hier_tree == NULL) {
        result = false;
        goto l_ig_lib_connection_final_free_hierlist;
    }

    log_debug ("LConn", "printing hierarchy tree...");
    /* debug: printout */
    ig_lib_htree_print (hier_tree);

    log_debug ("LConn", "reducing hierarchy tree...");
    hier_tree = ig_lib_htree_reduce (hier_tree);
    if (hier_tree == NULL) {
        log_warn ("LConn", "Unable to create signal %s, because of insufficient hierarchy information.", signame);
        goto l_ig_lib_connection_final_free_hierlist;
    }

    ig_lib_htree_print (hier_tree);

    log_debug ("LConn", "processing hierarchy tree...");
    GList *gen_objs_res = ig_lib_htree_process_signal (db, hier_tree);
    if (gen_objs_res != NULL) {
        log_info ("LConn", "successfully created signal %s", signame);
    } else {
        log_warn ("LConn", "nothing created for signal %s", signame);
    }

    struct ig_net *net = ig_lib_add_net (db, signame, gen_objs_res);

    if (gen_net != NULL) {
        *gen_net = net;
    }

    g_list_free (gen_objs_res);

    log_debug ("LConn", "deleting hierarchy tree...");
    ig_lib_htree_free (hier_tree);

l_ig_lib_connection_final_free_hierlist:
    for (GList *li = hier_start_list; li != NULL; li = li->next) {
        GList *hier = (GList *)li->data;
        for (GList *lj = hier; lj != NULL; lj = lj->next) {
            struct ig_lib_connection_info *cinfo = (struct ig_lib_connection_info *)lj->data;
            ig_lib_connection_info_free (cinfo);
        }
        g_list_free (hier);
    }
    g_list_free (hier_start_list);

    log_debug ("LConn", "finished...");
    return result;
}

bool ig_lib_parameter (struct ig_lib_db *db, const char *parname, const char *defvalue, GList *targets, GList **gen_objs)
{
    GList *hier_start_list = NULL;

    log_debug ("LParm", "creating individual hierarchies...");
    bool error = false;

    for (GList *li = targets; li != NULL; li = li->next) {
        struct ig_lib_connection_info *start = (struct ig_lib_connection_info *)li->data;
        start->is_explicit = true;

        log_debug ("LParm", "creating targetpoint hierarchy...");
        GList *target_hier = ig_lib_gen_hierarchy (db, start);
        if (target_hier == NULL) {
            error = true;
        } else {
            hier_start_list = g_list_prepend (hier_start_list, target_hier);
        }
        log_debug ("LParm", "targetpoint hierarchy depth: %d", g_list_length (target_hier));
    }

    g_list_free (targets);

    bool result = true;

    if (error) {
        result = false;
        goto l_ig_lib_parameter_final_free_hierlist;
    }

    log_debug ("LParm", "merging to hierarchy tree...");
    /* create hierarchy tree */
    GNode *hier_tree = ig_lib_merge_hierarchy_list (db, hier_start_list, parname);

    if (hier_tree == NULL) {
        result = false;
        goto l_ig_lib_parameter_final_free_hierlist;
    }

    log_debug ("LParm", "printing hierarchy tree...");
    /* debug: printout */
    ig_lib_htree_print (hier_tree);

    log_debug ("LParm", "reducing hierarchy tree...");
    hier_tree = ig_lib_htree_reduce (hier_tree);
    if (hier_tree == NULL) {
        log_warn ("LParm", "Unable to create parameter %s, because of insufficient hierarchy information.", parname);
        goto l_ig_lib_parameter_final_free_hierlist;
    }

    ig_lib_htree_print (hier_tree);

    log_debug ("LParm", "processing hierarchy tree...");
    GList *gen_objs_res = ig_lib_htree_process_parameter (db, hier_tree, defvalue);
    if (gen_objs_res != NULL) {
        log_info ("LParm", "successfully created parameter %s", parname);
    } else {
        log_warn ("LParm", "nothing created for parameter %s", parname);
    }
    for (GList *li = gen_objs_res; li != NULL; li = li->next) {
        struct ig_object *io = PTR_TO_IG_OBJECT (li->data);
        ig_obj_attr_set (io, "parameter", parname, true);
    }
    if (gen_objs != NULL) {
        *gen_objs = gen_objs_res;
    } else {
        g_list_free (gen_objs_res);
    }

    log_debug ("LParm", "deleting hierarchy tree...");
    ig_lib_htree_free (hier_tree);


l_ig_lib_parameter_final_free_hierlist:
    for (GList *li = hier_start_list; li != NULL; li = li->next) {
        GList *hier = (GList *)li->data;
        for (GList *lj = hier; lj != NULL; lj = lj->next) {
            struct ig_lib_connection_info *cinfo = (struct ig_lib_connection_info *)lj->data;
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
    GList                         *lhier_first = (GList *)hier_list->data;
    struct ig_lib_connection_info *cinfo_first = (struct ig_lib_connection_info *)lhier_first->data;

    struct ig_lib_connection_info *cinfo_node = ig_lib_connection_info_copy (db->str_chunks, cinfo_first);
    if (cinfo_node == NULL) return NULL;
    log_debug ("LMrHi", "reference node: %s", cinfo_first->obj->id);

    GList *successor_list = NULL;
    if (lhier_first->next != NULL) {
        successor_list = g_list_prepend (successor_list, lhier_first->next);
    }

    for (GList *li = hier_list->next; li != NULL; li = li->next) {
        GList *lhier = (GList *)li->data;
        if (lhier == NULL) continue;
        struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *)lhier->data;
        log_debug ("LMrHi", "current node: %s", i_cinfo->obj->id);

        /* object equality */
        if (i_cinfo->obj != cinfo_node->obj) {
            log_error ("LMrHi", "hierarchy has no common start (%s and %s)", i_cinfo->obj->id, cinfo_node->obj->id);
            ig_lib_connection_info_free (cinfo_node);
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

        /* inv merge */
        cinfo_node->invert = (cinfo_node->invert || i_cinfo->invert);

        /* explicit */
        if (i_cinfo->is_explicit) cinfo_node->is_explicit = true;

        if (lhier->next != NULL) {
            successor_list = g_list_prepend (successor_list, lhier->next);
        }
    }

    if (cinfo_node->local_name == NULL) cinfo_node->local_name = signame;
    result = g_node_new (cinfo_node);

    log_debug ("LMrHi", "generating subhierarchies (successor_list size is %d)...", g_list_length (successor_list));

    const char *local_default_name = cinfo_node->local_name;
    if (cinfo_node->force_name) {
        local_default_name = ig_lib_rm_suffix_pinport (db, local_default_name);
    }

    /* generate children */
    while (successor_list != NULL) {
        /* pick one */
        GList                         *equal_list    = successor_list;
        GList                         *ref_hier_list = (GList *)equal_list->data;
        struct ig_lib_connection_info *ref_cinfo     = (struct ig_lib_connection_info *)ref_hier_list->data;
        log_debug ("LMrHi", "current node: %s", ref_cinfo->obj->id);

        successor_list = g_list_remove_link (successor_list, equal_list);

        GList *li = successor_list;
        while (li != NULL) {
            GList                         *i_hier_list = (GList *)li->data;
            struct ig_lib_connection_info *i_cinfo     = (struct ig_lib_connection_info *)i_hier_list->data;

            if (i_cinfo->obj != ref_cinfo->obj) {
                li = li->next;
                continue;
            }
            /* don't merge different names */
            if ((i_cinfo->local_name != NULL) && (ref_cinfo->local_name != NULL)) {
                if (strcmp (i_cinfo->local_name, ref_cinfo->local_name) != 0) {
                    li = li->next;
                    continue;
                }
            }

            /* part of equal list */
            GList *li_next = li->next;
            successor_list = g_list_remove_link (successor_list, li);
            equal_list     = g_list_concat (equal_list, li);
            li             = li_next;
        }

        GNode *child_node = ig_lib_merge_hierarchy_list (db, equal_list, local_default_name);

        child_node = g_node_insert (result, 0, child_node);

        g_list_free (equal_list);
    }

    return result;
}


static GList *ig_lib_gen_hierarchy (struct ig_lib_db *db, struct ig_lib_connection_info *cinfo)
{
    GList *result = NULL;

    bool copy_first    = false;
    bool explicit_next = false;

    /* startpoint is instance of generated module? */
    if (cinfo->obj->type == IG_OBJ_INSTANCE) {
        struct ig_instance *inst = IG_INSTANCE (cinfo->obj);
        struct ig_module   *mod  = inst->module;

        if (!mod->resource) {
            cinfo->obj = IG_OBJECT (mod);
            copy_first = true;
        } else {
            explicit_next = true;
        }
    } else if (cinfo->obj->type == IG_OBJ_MODULE) {
        struct ig_module *mod = IG_MODULE (cinfo->obj);
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
            struct ig_instance *inst = IG_INSTANCE (cinfo->obj);
            if (inst->parent == NULL) return result;
            cinfo = ig_lib_connection_info_new (db->str_chunks, IG_OBJECT (inst->parent), NULL, cinfo->dir);
            if (explicit_next) {
                cinfo->is_explicit = true;
                explicit_next      = false;
            }
            continue;
        } else if (cinfo->obj->type == IG_OBJ_MODULE) {
            result = g_list_prepend (result, cinfo);
            struct ig_module *mod = IG_MODULE (cinfo->obj);
            if (mod->default_instance == NULL) return result;
            if (copy_first) {
                bool force_name = cinfo->force_name;
                bool invert     = cinfo->invert;
                cinfo             = ig_lib_connection_info_new (db->str_chunks, IG_OBJECT (mod->default_instance), cinfo->local_name, cinfo->dir);
                cinfo->force_name = force_name;
                cinfo->invert     = invert;
                copy_first        = false;
            } else {
                cinfo = ig_lib_connection_info_new (db->str_chunks, IG_OBJECT (mod->default_instance), NULL, cinfo->dir);
            }
            continue;
        } else {
            log_errorint ("LGnHi", "object of invalid type in module/instance hierarchy");
            ig_lib_connection_info_free (cinfo);
            for (GList *li = result; li != NULL; li = li->next) {
                ig_lib_connection_info_free ((struct ig_lib_connection_info *)li->data);
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

    result->obj         = obj;
    result->dir         = dir;
    result->is_explicit = false;
    result->force_name  = false;
    result->invert      = false;

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

    result->obj         = original->obj;
    result->dir         = original->dir;
    result->is_explicit = original->is_explicit;
    result->force_name  = original->force_name;
    result->invert      = original->invert;

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
    GList *pr_stack  = NULL;
    int    pr_indent = 0;

    pr_stack = g_list_prepend (pr_stack, hier_tree);

    while (pr_stack != NULL) {
        GNode *i_node = (GNode *)pr_stack->data;
        log_debug ("LPHTr", "current node: depth=%d, n_children=%d", g_node_depth (i_node), g_node_n_children (i_node));
        struct ig_lib_connection_info *i_info = (struct ig_lib_connection_info *)i_node->data;

        /* print node */
        GString *str_t = g_string_new (NULL);
        for (int i = 0; i < pr_indent - 1; i++) {
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
        if (i_info->invert) {
            str_t = g_string_append (str_t, "~");
        }
        str_t = g_string_append (str_t, i_info->local_name);
        if (i_info->is_explicit) {
            if (i_info->force_name) {
                str_t = g_string_append (str_t, "(explicit, force)");
            } else {
                str_t = g_string_append (str_t, "(explicit)");
            }
        }

        log_debug ("HTree", "%s", str_t->str);
        g_string_free (str_t, true);

        /* modify stack and continue */
        if (g_node_first_child (i_node) != NULL) {
            log_debug ("LPHTr", "node has child...");
            pr_indent++;
            pr_stack = g_list_prepend (pr_stack, g_node_first_child (i_node));
            continue;
        }

        while (pr_stack != NULL) {
            i_node = (GNode *)pr_stack->data;
            if (g_node_next_sibling (i_node) != NULL) {
                log_debug ("LPHTr", "node has sibling...");
                pr_stack->data = g_node_next_sibling (i_node);
                break;
            }
            log_debug ("LPHTr", "node is last one in subhierarchy...");
            pr_indent--;
            GList *temp = pr_stack;
            pr_stack = g_list_remove_link (pr_stack, temp);
            g_list_free (temp);
        }
    }
}

static GNode *ig_lib_htree_reduce (GNode *hier_tree)
{
    GNode *temp = hier_tree;

    for (;;) {
        if (g_node_n_children (temp) > 1) break;
        temp = g_node_first_child (temp);

        if (temp == NULL) break;

        struct ig_lib_connection_info *cinfo = (struct ig_lib_connection_info *)temp->data;
        if (cinfo->is_explicit) break;
    }

    if (temp == NULL) {
        if (hier_tree != NULL) ig_lib_htree_free (hier_tree);
        log_debug ("HTrRd", "!htree_reduce returns NULL!");
        return NULL;
    }

    g_node_unlink (temp);
    ig_lib_htree_free (hier_tree);

    return temp;
}

struct ig_lib_htree_process_signal_data {
    struct ig_lib_db *db;
    GList            *gen_objs;
};

static GList *ig_lib_htree_process_signal (struct ig_lib_db *db, GNode *hier_tree)
{
    struct ig_lib_htree_process_signal_data data = {db, NULL};

    g_node_traverse (hier_tree, G_PRE_ORDER, G_TRAVERSE_ALL, -1, ig_lib_htree_process_signal_tfunc, &data);

    return data.gen_objs;
}

static gboolean ig_lib_htree_process_signal_tfunc (GNode *node, gpointer data)
{
    struct ig_lib_htree_process_signal_data *pdata = (struct ig_lib_htree_process_signal_data *)data;

    struct ig_lib_connection_info *cinfo = (struct ig_lib_connection_info *)node->data;
    struct ig_lib_db              *db    = (struct ig_lib_db *)pdata->db;

    struct ig_object *obj = cinfo->obj;

    const char *local_name  = cinfo->local_name;
    const char *parent_name = cinfo->parent_name;

    log_debug ("HTrPS", "processing node %s", obj->id);

    if (obj->type == IG_OBJ_INSTANCE) {
        struct ig_instance *inst = IG_INSTANCE (obj);

        const char *conn_name = parent_name;
        if (conn_name == NULL) {
            log_error ("HTrPS", "No connection for signal %s in instance %s", local_name, obj->id);
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
        struct ig_pin *inst_pin = ig_lib_add_pin (db, inst, pin_name, conn_name, (cinfo->invert ? "true" : "false"));
        /* connecting the pin */
        if (inst_pin) {
            pdata->gen_objs = g_list_prepend (pdata->gen_objs, IG_OBJECT (inst_pin));
            log_debug ("CPin", "Created pin \"%s\" in instance \"%s\" connected to \"%s\"", pin_name, IG_OBJECT (inst)->id, conn_name);
        }

        for (GNode *in = g_node_first_child (node); in != NULL; in = g_node_next_sibling (in)) {
            struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *)in->data;
            i_cinfo->parent_name = pin_name;
        }
    } else if (obj->type == IG_OBJ_MODULE) {
        struct ig_module *mod = IG_MODULE (obj);

        const char *signal_name = NULL;

        if (G_NODE_IS_ROOT (node)) {
            if (cinfo->force_name) {
                signal_name = local_name;
            } else {
                signal_name = ig_lib_gen_name_signal (db, local_name);
            }

            /* create a declaration */
            struct ig_decl *mod_decl = ig_decl_new (signal_name, NULL, true, mod, db->str_chunks);
            if (g_hash_table_contains (db->objects_by_id, IG_OBJECT (mod_decl)->id)) {
                log_error ("HTrPS", "Already declared declaration %s", IG_OBJECT (mod_decl)->id);
                ig_decl_free (mod_decl);
            } else {
                g_hash_table_insert (db->objects_by_id, g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (mod_decl)->id), IG_OBJECT (mod_decl));
                ig_obj_ref (IG_OBJECT (mod_decl));
                g_queue_push_tail (mod->decls, mod_decl);
                ig_obj_ref (IG_OBJECT (mod_decl));
                pdata->gen_objs = g_list_prepend (pdata->gen_objs, IG_OBJECT (mod_decl));
                log_debug ("HTrPS", "Created declaration \"%s\" in module \"%s\"", signal_name, IG_OBJECT (mod)->id);
            }
        } else {
            signal_name = parent_name;
            if (signal_name == NULL) {
                log_error ("HTrPS", "No pin for signal %s in instance of module %s", local_name, obj->id);
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
            if (g_hash_table_contains (db->objects_by_id, IG_OBJECT (mod_port)->id)) {
                log_error ("HTrPS", "Already declared port %s", IG_OBJECT (mod_port)->id);
                ig_port_free (mod_port);
            } else {
                g_queue_push_tail (mod->ports, mod_port);
                ig_obj_ref (IG_OBJECT (mod_port));
                g_hash_table_insert (db->objects_by_id, g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (mod_port)->id), IG_OBJECT (mod_port));
                ig_obj_ref (IG_OBJECT (mod_port));
                pdata->gen_objs = g_list_prepend (pdata->gen_objs, IG_OBJECT (mod_port));
                log_debug ("HTrPS", "Created port \"%s\" in module \"%s\"", signal_name, IG_OBJECT (mod)->id);
            }
        }

        for (GNode *in = g_node_first_child (node); in != NULL; in = g_node_next_sibling (in)) {
            struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *)in->data;
            i_cinfo->parent_name = signal_name;
        }
    } else {
        log_errorint ("HTrPS", "invalid object in hierarchy tree");
    }

    return false;
}

struct ig_lib_htree_process_parameter_data {
    struct ig_lib_db *db;
    GList            *gen_objs;
    const char       *defvalue;
    bool              root_local;
};

static GList *ig_lib_htree_process_parameter (struct ig_lib_db *db, GNode *hier_tree, const char *defvalue)
{
    struct ig_lib_htree_process_parameter_data data = {db, NULL, defvalue, false};

    g_node_traverse (hier_tree, G_PRE_ORDER, G_TRAVERSE_ALL, -1, ig_lib_htree_process_parameter_tfunc, &data);

    return data.gen_objs;
}

static gboolean ig_lib_htree_process_parameter_tfunc (GNode *node, gpointer data)
{
    struct ig_lib_htree_process_parameter_data *pdata = (struct ig_lib_htree_process_parameter_data *)data;

    struct ig_lib_connection_info *cinfo    = (struct ig_lib_connection_info *)node->data;
    struct ig_lib_db              *db       = pdata->db;
    const char                    *defvalue = pdata->defvalue;

    struct ig_object *obj = cinfo->obj;

    const char *local_name  = cinfo->local_name;
    const char *parent_name = cinfo->parent_name;

    log_debug ("HTrPP", "processing node %s", obj->id);

    if (obj->type == IG_OBJ_INSTANCE) {
        struct ig_instance *inst = IG_INSTANCE (obj);

        const char *adj_name = parent_name;
        if (adj_name == NULL) {
            log_error ("HTrPP", "No value for parameter adjustment %s in instance %s", local_name, obj->id);
            adj_name = "";
        }

        const char *par_name = local_name;

        /* create an adjustment */
        struct ig_adjustment *inst_adj = ig_adjustment_new (par_name, adj_name, inst, db->str_chunks);
        if (g_hash_table_contains (db->objects_by_id, IG_OBJECT (inst_adj)->id)) {
            log_error ("HTrPP", "Already declared parameter adjustment %s", IG_OBJECT (inst_adj)->id);
            ig_adjustment_free (inst_adj);
        } else {
            g_hash_table_insert (db->objects_by_id, g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (inst_adj)->id), IG_OBJECT (inst_adj));
            ig_obj_ref (IG_OBJECT (inst_adj));
            g_queue_push_tail (inst->adjustments, inst_adj);
            ig_obj_ref (IG_OBJECT (inst_adj));
            pdata->gen_objs = g_list_prepend (pdata->gen_objs, IG_OBJECT (inst_adj));
            log_debug ("HTrPP", "Created adjustment of parameter \"%s\" in instance \"%s\" to value \"%s\"", par_name, IG_OBJECT (inst)->id, adj_name);
        }
        for (GNode *in = g_node_first_child (node); in != NULL; in = g_node_next_sibling (in)) {
            struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *)in->data;
            i_cinfo->parent_name = par_name;
        }
    } else if (obj->type == IG_OBJ_MODULE) {
        struct ig_module *mod = IG_MODULE (obj);

        const char *par_name = NULL;

        if (pdata->root_local && G_NODE_IS_ROOT (node)) {
            par_name = local_name;

            /* create a local parameter */
            struct ig_param *mod_param = ig_param_new (par_name, defvalue, true, mod, db->str_chunks);
            if (g_hash_table_contains (db->objects_by_id, IG_OBJECT (mod_param)->id)) {
                log_error ("HTrPP", "Already declared parameter %s", IG_OBJECT (mod_param)->id);
                ig_param_free (mod_param);
            } else {
                g_hash_table_insert (db->objects_by_id, g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (mod_param)->id), IG_OBJECT (mod_param));
                ig_obj_ref (IG_OBJECT (mod_param));
                g_queue_push_tail (mod->params, mod_param);
                ig_obj_ref (IG_OBJECT (mod_param));
                pdata->gen_objs = g_list_prepend (pdata->gen_objs, IG_OBJECT (mod_param));
                log_debug ("HTrPP", "Created local parameter \"%s\" in module \"%s\"", par_name, IG_OBJECT (mod)->id);
            }
        } else {
            if (G_NODE_IS_ROOT (node)) {
                par_name = local_name;
            } else {
                par_name = parent_name;
            }
            if (par_name == NULL) {
                log_error ("HTrPP", "No module-parameter for parameter %s in module %s", local_name, obj->id);
                par_name = "";
            }

            /* create a parameter */
            struct ig_param *mod_param = ig_param_new (par_name, defvalue, false, mod, db->str_chunks);
            if (g_hash_table_contains (db->objects_by_id, IG_OBJECT (mod_param)->id)) {
                log_error ("HTrPP", "Already declared parameter %s", IG_OBJECT (mod_param)->id);
                ig_param_free (mod_param);
            } else {
                g_hash_table_insert (db->objects_by_id, g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (mod_param)->id), IG_OBJECT (mod_param));
                ig_obj_ref (IG_OBJECT (mod_param));
                g_queue_push_tail (mod->params, mod_param);
                ig_obj_ref (IG_OBJECT (mod_param));
                pdata->gen_objs = g_list_prepend (pdata->gen_objs, IG_OBJECT (mod_param));
                log_debug ("HTrPP", "Created parameter \"%s\" in module \"%s\"", par_name, IG_OBJECT (mod)->id);
            }
        }

        for (GNode *in = g_node_first_child (node); in != NULL; in = g_node_next_sibling (in)) {
            struct ig_lib_connection_info *i_cinfo = (struct ig_lib_connection_info *)in->data;
            i_cinfo->parent_name = par_name;
        }
    } else {
        log_errorint ("HTrPP", "invalid object in hierarchy tree");
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
    struct ig_lib_connection_info *cinfo = (struct ig_lib_connection_info *)node->data;

    ig_lib_connection_info_free (cinfo);
    node->data = NULL;

    return false;
}

static struct ig_net *ig_lib_add_net (struct ig_lib_db *db, const char *netname, GList *objs)
{
    if (db == NULL) return NULL;
    if (netname == NULL) return NULL;

    struct ig_net *net = ig_net_new (netname, db->str_chunks);
    if (net == NULL) return NULL;

    for (GList *li = objs; li != NULL; li = li->next) {
        struct ig_object *obj = PTR_TO_IG_OBJECT (li->data);
        ig_obj_attr_set (obj, "signal",  netname,             true);
        ig_obj_attr_set (obj, "net",     netname,             true);
        ig_obj_attr_set (obj, "netid",   IG_OBJECT (net)->id, true);

        struct ig_net **obj_net_ptr = NULL;

        if (obj->type == IG_OBJ_PORT) {
            obj_net_ptr = &(IG_PORT (obj)->net);
        } else if (obj->type == IG_OBJ_PIN) {
            obj_net_ptr = &(IG_PIN (obj)->net);
        } else if (obj->type == IG_OBJ_DECLARATION) {
            obj_net_ptr = &(IG_DECL (obj)->net);
        } else {
            log_errorint ("NtFre", "Net %s contains object of invalid type %s.", IG_OBJECT (net)->name, ig_obj_type_name (obj->type));
        }

        if (obj_net_ptr != NULL) {
            *obj_net_ptr = net;
        }

        ig_obj_ref (obj);
        g_queue_push_tail (net->objects, obj);
    }

    char *l_name = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (net)->name);
    char *l_id   = g_string_chunk_insert_const (db->str_chunks, IG_OBJECT (net)->id);

    g_hash_table_insert (db->nets_by_name, l_name, net);
    g_hash_table_insert (db->nets_by_id, l_id, net);
    g_hash_table_insert (db->objects_by_id, l_id, IG_OBJECT (net));
    ig_obj_ref (IG_OBJECT (net));
    ig_obj_ref (IG_OBJECT (net));
    ig_obj_ref (IG_OBJECT (net));

    return net;
}

static bool ig_lib_gen_name_iscaps (const char *name)
{
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

static char *ig_lib_rm_suffix_pinport (struct ig_lib_db *db, const char *pinportname)
{
    int len = strlen (pinportname);

    if (len < 3) {
        return g_string_chunk_insert_const (db->str_chunks, pinportname);
    }

    if (pinportname[len - 2] != '_') {
        return g_string_chunk_insert_const (db->str_chunks, pinportname);
    }

    if (ig_lib_gen_name_iscaps (pinportname)) {
        if ((pinportname[len - 1] == 'I') &&
            (pinportname[len - 1] == 'O') &&
            (pinportname[len - 1] == 'B')) {
            return g_string_chunk_insert_const (db->str_chunks, pinportname);
        }
    } else {
        if ((pinportname[len - 1] == 'i') &&
            (pinportname[len - 1] == 'o') &&
            (pinportname[len - 1] == 'b')) {
            return g_string_chunk_insert_const (db->str_chunks, pinportname);
        }
    }

    GString *tstr   = g_string_new_len (pinportname, len - 2);
    char    *result = g_string_chunk_insert_const (db->str_chunks, tstr->str);
    g_string_free (tstr, true);

    return result;
}

