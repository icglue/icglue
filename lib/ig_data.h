/*       _\|/_
         (o o)
 +----oOO-{_}-OOo-------------+
 |          _      ^..^       |
 |    _   _(_     ( oo )  )~  |
 |  _) /)(// (/     ,,  ,,    |
 |                2017-12-02  | 
 +---------------------------*/

#ifndef __IG_DATA_H__
#define __IG_DATA_H__

#include <glib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/*******************************************************
 * Data types
 *******************************************************/

enum ig_object_type {
    IG_OBJ_PORT,
    IG_OBJ_PIN,
    IG_OBJ_PARAM,
    IG_OBJ_DECLARATION,
    IG_OBJ_MODULE,
    IG_OBJ_INSTANCE,
};

struct ig_attribute {
    /* constant = cannot be changed */
    bool constant;
    const char *value;
};

struct ig_object {
    const char           *id;
    enum  ig_object_type  type;
    gpointer              obj;

    GHashTable   *attributes; /* key: (const char *) -> value: (struct ig_attribute *) */
    GStringChunk *string_storage;
    bool          string_storage_free;
};

enum ig_port_dir {
    IG_PD_IN,
    IG_PD_OUT,
    IG_PD_BIDIR,
};

struct ig_port {
    struct ig_object *object;

    const char       *name;
    enum ig_port_dir  dir;
};

struct ig_param {
    struct ig_object *object;

    const char *name;
    const char *value;
    bool        local;
};

struct ig_decl {
    struct ig_object *object;

    const char *name;
    /* is of default signal type? */
    bool default_type;

    /* NULL or value this is assigned to */
    const char *default_assignment;
};

struct ig_module {
    struct ig_object *object;

    const char      *name;
    bool             ilm;
    bool             resource;

    /* module content */
    GList *params; /* data: (struct ig_param *)    */
    GList *ports;  /* data: (struct ig_port *)     */
    GList *decls;  /* data: (struct ig_decl *)     */
    GList *code;   /* data: (const char *)         */
    /* child instances inside module */
    GList *child_instances; /* data: (struct ig_instance *) */
    /* instances of this module elsewhere */
    GList *mod_instances;   /* data: (struct ig_instance *) */
    /* default instance of this module */
    struct ig_instance *default_instance;
};

struct ig_pin {
    struct ig_object *object;

    const char *name;
    const char *net;
};

struct ig_instance {
    struct ig_object *object;

    const char       *name;
    struct ig_module *module;

    /* instance values */
    GList *params; /* data: (struct ig_param *)    */
    GList *ports;  /* data: (struct ig_port *)     */
};

/*******************************************************
 * Functions
 *******************************************************/

struct ig_object *ig_obj_new  (enum ig_object_type type, const char *id, gpointer obj, GStringChunk *storage);
void              ig_obj_free (struct ig_object *obj);

bool              ig_obj_attr_set (struct ig_object *obj, const char *name, const char *value, bool constant);
const char       *ig_obj_attr_get (struct ig_object *obj, const char *name);

/* TODO: remaining */

#ifdef __cplusplus
}
#endif

#endif

