#include "ig_lib.h"

#include <stdio.h>

struct ig_lib_db *ig_lib_db_new ()
{
    struct ig_lib_db *result = g_slice_new (struct ig_lib_db);

    result->objects = g_hash_table_new (g_str_hash, g_str_equal);
    result->modules = g_hash_table_new (g_str_hash, g_str_equal);

    result->str_chunks = g_string_chunk_new (128);

    return result;
}

void ig_lib_db_free (struct ig_lib_db *db)
{
    if (db == NULL) return;

    g_hash_table_destroy (db->objects);
    g_hash_table_destroy (db->modules);

    g_string_chunk_free (db->str_chunks);
}

struct ig_module *ig_lib_add_module (struct ig_lib_db *db, const char *name, bool ilm, bool resource)
{
    if (db == NULL) return NULL;
    if (name == NULL) return NULL;

    if (g_hash_table_contains (db->modules, name)) {
        fprintf (stderr, "Error: module %s already exists\n", name);
        return NULL;
    }

    struct ig_module *mod = ig_module_new (name, ilm, resource, db->str_chunks);

    if (g_hash_table_contains (db->objects, mod->object->id)) {
        fprintf (stderr, "Error: object %s already exists\n", mod->object->id);
        ig_module_free (mod);
        return NULL;
    }

    char *l_name = g_string_chunk_insert_const (db->str_chunks, mod->name);
    char *l_id   = g_string_chunk_insert_const (db->str_chunks, mod->object->id);

    g_hash_table_insert (db->modules, l_name, mod);
    g_hash_table_insert (db->modules, l_id,   mod);
    g_hash_table_insert (db->objects, l_id,   mod->object);

    return mod;
}

