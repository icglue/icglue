#include "ig_lib.h"

#include <stdio.h>
#include <string.h>

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

