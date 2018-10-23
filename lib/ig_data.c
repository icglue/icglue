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

#include "ig_data.h"
#include "logger.h"
#include <stdio.h>

static struct ig_attribute *ig_attribute_new (const char *value, bool constant);
static inline void          ig_attribute_free (struct ig_attribute *attr);
static void                 ig_attribute_free_gpointer (gpointer attr);
static const char          *ig_port_dir_name (enum ig_port_dir dir);

#define IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE(PARENTPTR, QUEUE, CHILDTYPE, CHILDTOPARENT) do { \
        if (PARENTPTR->QUEUE != NULL) { \
            for (GList *li = PARENTPTR->QUEUE->head; li != NULL; li = li->next) { \
                CHILDTYPE *child = (CHILDTYPE *)li->data; \
                if (child->CHILDTOPARENT == PARENTPTR) child->CHILDTOPARENT = NULL; \
                ig_obj_unref (IG_OBJECT (child)); \
            } \
            g_queue_free (PARENTPTR->QUEUE); \
        } \
} while (false)


/*******************************************************
 * object data
 *******************************************************/

static struct ig_attribute *ig_attribute_new (const char *value, bool constant)
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
    ig_attribute_free ((struct ig_attribute *)attr);
}

const char *ig_obj_type_name (enum ig_object_type type)
{
    switch (type) {
        case IG_OBJ_PORT:          return "port";
        case IG_OBJ_PIN:           return "pin";
        case IG_OBJ_PARAMETER:     return "parameter";
        case IG_OBJ_ADJUSTMENT:    return "adjustment";
        case IG_OBJ_DECLARATION:   return "declaration";
        case IG_OBJ_CODESECTION:   return "codesection";
        case IG_OBJ_MODULE:        return "module";
        case IG_OBJ_INSTANCE:      return "instance";
        case IG_OBJ_REGFILE_REG:   return "register";
        case IG_OBJ_REGFILE_ENTRY: return "regfile-entry";
        case IG_OBJ_REGFILE:       return "regfile";
    }

    return "UNKNOWN";
}

void ig_obj_init (enum ig_object_type type, const char *name, struct ig_object *plist[], struct ig_object *obj, GStringChunk *storage)
{
    if (name == NULL) return;
    if (obj  == NULL) return;


    /* id/parent */
    GString *s_id = g_string_new (NULL);
    s_id = g_string_append (s_id, ig_obj_type_name (type));
    s_id = g_string_append (s_id, "##");

    struct ig_object *parent = NULL;
    if (plist != NULL) {
        for (int i = 0; plist[i] != NULL; i++) {
            struct ig_object *ip = plist[i];
            s_id   = g_string_append (s_id, ig_obj_attr_get (ip, "name"));
            s_id   = g_string_append (s_id, "#");
            parent = ip;
        }
    }
    s_id = g_string_append (s_id, name);

    /* init */
    log_debug ("DONew", "Creating object of type %s, name %s, parent %s", ig_obj_type_name (type), name, (parent != NULL ? parent->id : "<none>"));

    obj->type     = type;
    obj->refcount = 0;

    if (storage == NULL) {
        obj->string_storage      = g_string_chunk_new (256);
        obj->string_storage_free = true;
    } else {
        obj->string_storage      = storage;
        obj->string_storage_free = false;
    }

    obj->attributes = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, ig_attribute_free_gpointer);

    ig_obj_attr_set (obj, "type", ig_obj_type_name (type), true);
    ig_obj_attr_set (obj, "id",   s_id->str,               true);
    ig_obj_attr_set (obj, "name", name,                    true);
    if (parent != NULL) {
        ig_obj_attr_set (obj, "parent", parent->id, true);
    }

    g_string_free (s_id, true);

    obj->id = ig_obj_attr_get (obj, "id");
}

void ig_obj_free (struct ig_object *obj)
{
    if (obj == NULL) return;

    g_hash_table_destroy (obj->attributes);

    if (obj->string_storage_free) {
        g_string_chunk_free (obj->string_storage);
    }
}

void ig_obj_free_full (struct ig_object *obj)
{
    if (obj == NULL) return;

    /* type-specific frees call ig_object_free on object */
    switch (obj->type) {
        case IG_OBJ_PORT:          ig_port_free       (IG_PORT       (obj)); break;
        case IG_OBJ_PIN:           ig_pin_free        (IG_PIN        (obj)); break;
        case IG_OBJ_PARAMETER:     ig_param_free      (IG_PARAM      (obj)); break;
        case IG_OBJ_ADJUSTMENT:    ig_adjustment_free (IG_ADJUSTMENT (obj)); break;
        case IG_OBJ_DECLARATION:   ig_decl_free       (IG_DECL       (obj)); break;
        case IG_OBJ_CODESECTION:   ig_code_free       (IG_CODE       (obj)); break;
        case IG_OBJ_MODULE:        ig_module_free     (IG_MODULE     (obj)); break;
        case IG_OBJ_INSTANCE:      ig_instance_free   (IG_INSTANCE   (obj)); break;
        case IG_OBJ_REGFILE_REG:   ig_rf_reg_free     (IG_RF_REG     (obj)); break;
        case IG_OBJ_REGFILE_ENTRY: ig_rf_entry_free   (IG_RF_ENTRY   (obj)); break;
        case IG_OBJ_REGFILE:       ig_rf_regfile_free (IG_RF_REGFILE (obj)); break;
    }
}

void ig_obj_ref (struct ig_object *obj)
{
    if (obj == NULL) return;

    obj->refcount++;
}

void ig_obj_unref (struct ig_object *obj)
{
    if (obj == NULL) return;

    obj->refcount--;
    if (obj->refcount <= 0) {
        log_debug ("DOUrf", "Freeing object %s of type %s after unref", obj->id, ig_obj_type_name (obj->type));
        ig_obj_free_full (obj);
    }
}

bool ig_obj_attr_set (struct ig_object *obj, const char *name, const char *value, bool constant)
{
    if (obj == NULL) return false;
    if (name == NULL) return false;
    if (value == NULL) return false;

    struct ig_attribute *old_val = (struct ig_attribute *)g_hash_table_lookup (obj->attributes, name);

    if ((old_val != NULL) && (old_val->constant)) return false;

    char                *local_name         = g_string_chunk_insert_const (obj->string_storage, name);
    char                *local_value_string = g_string_chunk_insert_const (obj->string_storage, value);
    struct ig_attribute *value_entry        = ig_attribute_new (local_value_string, constant);

    g_hash_table_insert (obj->attributes, local_name, value_entry);

    return true;
}

const char *ig_obj_attr_get (struct ig_object *obj, const char *name)
{
    if (obj == NULL) return NULL;
    if (name == NULL) return NULL;

    struct ig_attribute *value = (struct ig_attribute *)g_hash_table_lookup (obj->attributes, name);

    if (value == NULL) return NULL;
    return value->value;
}

GList *ig_obj_attr_get_keys (struct ig_object *obj)
{
    if (obj == NULL) return NULL;

    return g_hash_table_get_keys (obj->attributes);
}

bool ig_obj_attr_set_from_gslist (struct ig_object *obj, GList *list)
{
    if (obj == NULL) return false;

    bool result = true;

    if (g_list_length (list) % 2 == 1) {
        log_error ("OStAt", "need a value for every attribute in attribute list");
        return false;
    }

    for (GList *li = list; li != NULL; li = li->next) {
        char *name = (char *)li->data;
        li = li->next;
        char *val = (char *)li->data;

        if (!ig_obj_attr_set (obj, name, val, false)) {
            log_error ("OStAt", "could not set attribute %s", name);
            result = false;
        }
    }

    return result;
}

static const char *ig_port_dir_name (enum ig_port_dir dir)
{
    switch (dir) {
        case IG_PD_IN:    return "input";
        case IG_PD_OUT:   return "output";
        case IG_PD_BIDIR: return "bidirectional";
    }

    return "UNKNOWN";
}

/*******************************************************
 * port data
 *******************************************************/

struct ig_port *ig_port_new (const char *name, enum ig_port_dir dir, struct ig_module *parent, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;

    struct ig_port   *port     = g_slice_new (struct ig_port);
    struct ig_object *plist[2] = {IG_OBJECT (parent), NULL};
    ig_obj_init (IG_OBJ_PORT, name, plist, IG_OBJECT (port), storage);

    ig_obj_attr_set (IG_OBJECT (port), "direction", ig_port_dir_name (dir), true);

    port->name   = ig_obj_attr_get (IG_OBJECT (port), "name");
    port->dir    = dir;
    port->parent = parent;

    return port;
}

void ig_port_free (struct ig_port *port)
{
    if (port == NULL) return;

    ig_obj_free (IG_OBJECT (port));
    g_slice_free (struct ig_port, port);
}

/*******************************************************
 * parameter data
 *******************************************************/

struct ig_param *ig_param_new (const char *name, const char *value, bool local, struct ig_module *parent, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;
    if (value == NULL) return NULL;

    struct ig_param  *param    = g_slice_new (struct ig_param);
    struct ig_object *plist[2] = {IG_OBJECT (parent), NULL};
    ig_obj_init (IG_OBJ_PARAMETER, name, plist, IG_OBJECT (param), storage);

    ig_obj_attr_set (IG_OBJECT (param), "value",  value, true);
    ig_obj_attr_set (IG_OBJECT (param), "local",  (local ? "true" : "false"), true);

    param->name   = ig_obj_attr_get (IG_OBJECT (param), "name");
    param->value  = ig_obj_attr_get (IG_OBJECT (param), "value");
    param->local  = local;
    param->parent = parent;

    return param;
}

void ig_param_free (struct ig_param *param)
{
    if (param == NULL) return;

    ig_obj_free (IG_OBJECT (param));
    g_slice_free (struct ig_param, param);
}


/*******************************************************
 * declaration data
 *******************************************************/

struct ig_decl *ig_decl_new (const char *name, const char *assign, bool default_type, struct ig_module *parent, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;

    struct ig_decl   *decl     = g_slice_new (struct ig_decl);
    struct ig_object *plist[2] = {IG_OBJECT (parent), NULL};
    ig_obj_init (IG_OBJ_DECLARATION, name, plist, IG_OBJECT (decl), storage);

    ig_obj_attr_set (IG_OBJECT (decl), "default_type", (default_type ? "true" : "false"), true);
    if (assign != NULL) ig_obj_attr_set (IG_OBJECT (decl), "assign", assign, true);

    decl->name               = ig_obj_attr_get (IG_OBJECT (decl), "name");
    decl->default_assignment = ig_obj_attr_get (IG_OBJECT (decl), "assign");
    decl->default_type       = default_type;
    decl->parent             = parent;

    return decl;
}

void ig_decl_free (struct ig_decl *decl)
{
    if (decl == NULL) return;

    ig_obj_free (IG_OBJECT (decl));
    g_slice_free (struct ig_decl, decl);
}

/*******************************************************
 * codesection data
 *******************************************************/

struct ig_code *ig_code_new (const char *name, const char *codesection, struct ig_module *parent, GStringChunk *storage)
{
    if (codesection == NULL) return NULL;
    if (parent == NULL) return NULL;
    if (parent->resource) {
        log_error ("DCsNw", "Cannot add codesection to resource module");
        return NULL;
    }

    GString *s_name = g_string_new (NULL);
    if (name == NULL) {
        g_string_printf (s_name, "_cs_%d", g_queue_get_length (parent->code));
    } else {
        s_name = g_string_append (s_name, name);
    }

    struct ig_code   *code     = g_slice_new (struct ig_code);
    struct ig_object *plist[2] = {IG_OBJECT (parent), NULL};
    ig_obj_init (IG_OBJ_CODESECTION, s_name->str, plist, IG_OBJECT (code), storage);

    ig_obj_attr_set (IG_OBJECT (code), "code",   codesection,        true);

    code->name   = ig_obj_attr_get (IG_OBJECT (code), "name");
    code->code   = ig_obj_attr_get (IG_OBJECT (code), "code");
    code->parent = parent;

    g_string_free (s_name, true);

    return code;
}

void ig_code_free (struct ig_code *code)
{
    if (code == NULL) return;

    ig_obj_free (IG_OBJECT (code));
    g_slice_free (struct ig_code, code);
}

/*******************************************************
 * regfile data
 *******************************************************/

struct ig_rf_reg *ig_rf_reg_new (const char *name, struct ig_rf_entry *parent, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;

    struct ig_rf_reg *reg      = g_slice_new (struct ig_rf_reg);
    struct ig_object *plist[4] = {IG_OBJECT (parent->parent->parent), IG_OBJECT (parent->parent), IG_OBJECT (parent), NULL};
    ig_obj_init (IG_OBJ_REGFILE_REG, name, plist, IG_OBJECT (reg), storage);

    reg->name   = ig_obj_attr_get (IG_OBJECT (reg), "name");
    reg->parent = parent;

    return reg;
}

void ig_rf_reg_free (struct ig_rf_reg *reg)
{
    if (reg == NULL) return;

    ig_obj_free (IG_OBJECT (reg));
    g_slice_free (struct ig_rf_reg, reg);
}

struct ig_rf_entry *ig_rf_entry_new (const char *name, struct ig_rf_regfile *parent, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;

    struct ig_rf_entry *entry    = g_slice_new (struct ig_rf_entry);
    struct ig_object   *plist[3] = {IG_OBJECT (parent->parent), IG_OBJECT (parent), NULL};
    ig_obj_init (IG_OBJ_REGFILE_ENTRY, name, plist, IG_OBJECT (entry), storage);

    entry->name   = ig_obj_attr_get (IG_OBJECT (entry), "name");
    entry->parent = parent;
    entry->regs   = g_queue_new ();

    return entry;
}

void ig_rf_entry_free (struct ig_rf_entry *entry)
{
    if (entry == NULL) return;

    ig_obj_free (IG_OBJECT (entry));

    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (entry, regs, struct ig_rf_reg, parent);

    g_slice_free (struct ig_rf_entry, entry);
}

struct ig_rf_regfile *ig_rf_regfile_new (const char *name, struct ig_module *parent, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;
    if (parent->resource) {
        log_error ("DRfNw", "Cannot add regfile to resource module");
        return NULL;
    }

    struct ig_rf_regfile *regfile  = g_slice_new (struct ig_rf_regfile);
    struct ig_object     *plist[2] = {IG_OBJECT (parent), NULL};
    ig_obj_init (IG_OBJ_REGFILE, name, plist, IG_OBJECT (regfile), storage);

    regfile->name    = ig_obj_attr_get (IG_OBJECT (regfile), "name");
    regfile->parent  = parent;
    regfile->entries = g_queue_new ();

    return regfile;
}

void ig_rf_regfile_free (struct ig_rf_regfile *regfile)
{
    if (regfile == NULL) return;

    ig_obj_free (IG_OBJECT (regfile));

    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (regfile, entries, struct ig_rf_entry, parent);

    g_slice_free (struct ig_rf_regfile, regfile);
}

/*******************************************************
 * module data
 *******************************************************/

struct ig_module *ig_module_new (const char *name, bool ilm, bool resource, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    log_debug ("DMNew", "Generating module %s", name);

    struct ig_module *module   = g_slice_new (struct ig_module);
    struct ig_object *plist[1] = {NULL};
    ig_obj_init (IG_OBJ_MODULE, name, plist, IG_OBJECT (module), storage);

    ig_obj_attr_set (IG_OBJECT (module), "ilm",      (ilm      ? "true" : "false"), true);
    ig_obj_attr_set (IG_OBJECT (module), "resource", (resource ? "true" : "false"), true);

    module->name     = ig_obj_attr_get (IG_OBJECT (module), "name");
    module->ilm      = ilm;
    module->resource = resource;

    module->params        = g_queue_new ();
    module->ports         = g_queue_new ();
    module->mod_instances = g_queue_new ();

    if (resource) {
        module->decls            = NULL;
        module->code             = NULL;
        module->child_instances  = NULL;
        module->regfiles         = NULL;
        module->default_instance = NULL;
    } else {
        module->decls            = g_queue_new ();
        module->code             = g_queue_new ();
        module->child_instances  = g_queue_new ();
        module->regfiles         = g_queue_new ();
        module->default_instance = ig_instance_new (name, module, NULL, storage);

        g_queue_push_tail (module->mod_instances, module->default_instance);
        ig_obj_ref (IG_OBJECT (module->default_instance));
    }

    return module;
}

void ig_module_free (struct ig_module *module)
{
    if (module == NULL) return;

    if (!module->resource) {
        if (module->default_instance != NULL) {
            if (module->default_instance->parent == NULL) {
                module->default_instance->parent = NULL;
            }
        }
    }

    ig_obj_free (IG_OBJECT (module));

    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (module, params,          struct ig_param,      parent);
    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (module, ports,           struct ig_port,       parent);
    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (module, mod_instances,   struct ig_instance,   module);
    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (module, decls,           struct ig_decl,       parent);
    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (module, code,            struct ig_code,       parent);
    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (module, child_instances, struct ig_instance,   parent);
    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (module, regfiles,        struct ig_rf_regfile, parent);

    g_slice_free (struct ig_module, module);
}


/*******************************************************
 * pin data
 *******************************************************/

struct ig_pin *ig_pin_new (const char *name, const char *connection, struct ig_instance *parent, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    if (connection == NULL) return NULL;
    if (parent == NULL) return NULL;

    struct ig_pin    *pin      = g_slice_new (struct ig_pin);
    struct ig_object *plist[2] = {IG_OBJECT (parent), NULL};
    ig_obj_init (IG_OBJ_PIN, name, plist, IG_OBJECT (pin), storage);

    ig_obj_attr_set (IG_OBJECT (pin), "connection", connection, true);

    pin->name       = ig_obj_attr_get (IG_OBJECT (pin), "name");
    pin->connection = ig_obj_attr_get (IG_OBJECT (pin), "connection");
    pin->parent     = parent;

    return pin;
}

void ig_pin_free (struct ig_pin *pin)
{
    if (pin == NULL) return;

    ig_obj_free (IG_OBJECT (pin));
    g_slice_free (struct ig_pin, pin);
}


/*******************************************************
 * adjustment data
 *******************************************************/

struct ig_adjustment *ig_adjustment_new (const char *name, const char *value, struct ig_instance *parent, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    if (parent == NULL) return NULL;
    if (value == NULL) return NULL;

    struct ig_adjustment *adjustment = g_slice_new (struct ig_adjustment);
    struct ig_object     *plist[2]   = {IG_OBJECT (parent), NULL};
    ig_obj_init (IG_OBJ_ADJUSTMENT, name, plist, IG_OBJECT (adjustment), storage);

    ig_obj_attr_set (IG_OBJECT (adjustment), "value",  value, true);

    adjustment->name   = ig_obj_attr_get (IG_OBJECT (adjustment), "name");
    adjustment->value  = ig_obj_attr_get (IG_OBJECT (adjustment), "value");
    adjustment->parent = parent;

    return adjustment;
}

void ig_adjustment_free (struct ig_adjustment *adjustment)
{
    if (adjustment == NULL) return;

    ig_obj_free (IG_OBJECT (adjustment));
    g_slice_free (struct ig_adjustment, adjustment);
}


/*******************************************************
 * instance data
 *******************************************************/

struct ig_instance *ig_instance_new (const char *name, struct ig_module *module, struct ig_module *parent, GStringChunk *storage)
{
    if (name == NULL) return NULL;
    if (module == NULL) return NULL;
    log_debug ("DINew", "Generating instance %s", name);

    if ((parent != NULL) && (parent->resource)) {
        log_error ("DINew", "Cannot create instances within resource module %s", parent->name);
        return NULL;
    }

    struct ig_instance *instance = g_slice_new (struct ig_instance);
    struct ig_object   *plist[2] = {(parent == NULL ? NULL : IG_OBJECT (parent)), NULL};
    ig_obj_init (IG_OBJ_INSTANCE, name, plist, IG_OBJECT (instance), storage);

    ig_obj_attr_set (IG_OBJECT (instance), "module", IG_OBJECT (module)->id, true);

    instance->name   = ig_obj_attr_get (IG_OBJECT (instance), "name");
    instance->module = module;
    instance->parent = parent;

    instance->adjustments = g_queue_new ();
    instance->pins        = g_queue_new ();

    return instance;
}

void ig_instance_free (struct ig_instance *instance)
{
    if (instance == NULL) return;

    ig_obj_free (IG_OBJECT (instance));

    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (instance, adjustments, struct ig_adjustment, parent);
    IG_OBJECT_CHILD_QUEUE_UNREF_AND_FREE (instance, pins,        struct ig_pin,        parent);

    g_slice_free (struct ig_instance, instance);
}

