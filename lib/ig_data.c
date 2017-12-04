/*       _\|/_
         (o o)
 +----oOO-{_}-OOo-------------+
 |          _      ^..^       |
 |    _   _(_     ( oo )  )~  |
 |  _) /)(// (/     ,,  ,,    |
 |                2017-12-02  | 
 +---------------------------*/

#include "ig_data.h"

/*******************************************************
 * object data
 *******************************************************/

static struct ig_attribute * ig_attribtue_new (const char *value, bool constant)
{
    struct ig_attribute *result = g_slice_new (struct ig_attribute);

    result->constant = constant;
    result->value    = value;

    return result;
}

static inline void ig_attribute_free (struct ig_attribute *attr)
{
    g_slice_free (struct ig_attribute, attr);
}

static void ig_attribute_free_gpointer (gpointer attr)
{
    ig_attribute_free ((struct ig_attribute *) attr);
}

static const char *ig_obj_type_name (enum ig_object_type type)
{
    switch (type) {
        case IG_OBJ_PORT:        return "port";
        case IG_OBJ_PIN:         return "pin";
        case IG_OBJ_PARAM:       return "parameter";
        case IG_OBJ_DECLARATION: return "declaration";
        case IG_OBJ_MODULE:      return "module";
        case IG_OBJ_INSTANCE:    return "instance";
    };

    return "UNKNOWN";
}

struct ig_object *ig_obj_new (enum ig_object_type type, const char *id, gpointer obj, GStringChunk *storage)
{
    if (id == NULL) return NULL;
    if (obj == NULL) return NULL;

    struct ig_object *result = g_slice_new (struct ig_object);

    result->type = type;
    result->obj  = obj;

    if (storage == NULL) {
        result->string_storage      = g_string_chunk_new (256);
        result->string_storage_free = true;
    } else {
        result->string_storage      = storage;
        result->string_storage_free = false;
    }

    result->attributes = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, ig_attribute_free_gpointer);

    ig_obj_attr_set (result, "type", ig_obj_type_name (type), true);
    ig_obj_attr_set (result, "id",   id, true);

    result->id = ig_obj_attr_get (obj, "id");

    return result;
}

void ig_obj_free (struct ig_object *obj)
{
    if (obj == NULL) return;

    g_hash_table_destroy (obj->attributes);

    if (obj->string_storage_free) {
        g_string_chunk_free (obj->string_storage);
    }

    g_slice_free (struct ig_object, obj);
}

bool ig_obj_attr_set (struct ig_object *obj, const char *name, const char *value, bool constant)
{
    if (obj == NULL) return false;
    if (name == NULL) return false;
    if (value == NULL) return false;

    struct ig_attribute *old_val = (struct ig_attribute *) g_hash_table_lookup (obj->attributes, name);

    if ((old_val != NULL) && (old_val->constant)) return false;

    char *local_name                 = g_string_chunk_insert_const (obj->string_storage, name);
    char *local_value_string         = g_string_chunk_insert_const (obj->string_storage, value);
    struct ig_attribute *value_entry = ig_attribtue_new (local_value_string, constant);

    g_hash_table_insert (obj->attributes, local_name, value_entry);

    return true;
}

const char *ig_obj_attr_get (struct ig_object *obj, const char *name)
{
    if (obj == NULL) return NULL;
    if (name == NULL) return NULL;

    struct ig_attribute *value = (struct ig_attribute *) g_hash_table_lookup (obj->attributes, name);

    if (value == NULL) return NULL;
    return value->value;
}

