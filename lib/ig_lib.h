/*       _\|/_
         (o o)
 +----oOO-{_}-OOo-------------+
 |          _      ^..^       |
 |    _   _(_     ( oo )  )~  |
 |  _) /)(// (/     ,,  ,,    |
 |                2017-12-08  | 
 +---------------------------*/

#ifndef __IG_LIB_H__
#define __IG_LIB_H__

#include "ig_data.h"

#include <glib.h>

#ifdef __cplusplus
extern "C" {
#endif

struct ig_lib_db {
    GHashTable *objects_by_id;   /* key: (const char *) -> value: (struct ig_object *) */

    GHashTable *modules_by_name; /* key: (const char *) -> value: (struct ig_module *) */
    GHashTable *modules_by_id;   /* key: (const char *) -> value: (struct ig_module *) */

    GHashTable *instances_by_name; /* key: (const char *) -> value: (struct ig_module *) */
    GHashTable *instances_by_id;   /* key: (const char *) -> value: (struct ig_module *) */

    /* TODO: remaining */

    GStringChunk *str_chunks;
};

struct ig_lib_db *ig_lib_db_new  ();
void              ig_lib_db_free (struct ig_lib_db *db);

struct ig_module   *ig_lib_add_module   (struct ig_lib_db *db, const char *name, bool ilm, bool resource);
struct ig_instance *ig_lib_add_instance (struct ig_lib_db *db, const char *name, struct ig_module *type, struct ig_module *parent);


#ifdef __cplusplus
}
#endif

#endif

