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

    GHashTable *instances_by_name; /* key: (const char *) -> value: (struct ig_instance *) */
    GHashTable *instances_by_id;   /* key: (const char *) -> value: (struct ig_instance *) */

    /* TODO: remaining */

    GStringChunk *str_chunks;
};

enum ig_lib_connection_dir {
    IG_LCDIR_UP,
    IG_LCDIR_DOWN,
    IG_LCDIR_BIDIR,
    IG_LCDIR_DEFAULT
};

struct ig_lib_connection_info {
    struct ig_object          *obj;
    const char                *parent_name;
    const char                *local_name;
    bool                       is_explicit;
    bool                       force_name;
    enum ig_lib_connection_dir dir;
};

struct ig_lib_db *ig_lib_db_new  ();
void              ig_lib_db_free (struct ig_lib_db *db);

struct ig_module   *ig_lib_add_module      (struct ig_lib_db *db, const char *name, bool ilm, bool resource);
struct ig_instance *ig_lib_add_instance    (struct ig_lib_db *db, const char *name, struct ig_module *type, struct ig_module *parent);
struct ig_code     *ig_lib_add_codesection (struct ig_lib_db *db, const char *name, const char *code, struct ig_module *parent);

struct ig_rf_regfile *ig_lib_add_regfile       (struct ig_lib_db *db, const char *name, struct ig_module *parent);
struct ig_rf_entry   *ig_lib_add_regfile_entry (struct ig_lib_db *db, const char *name, struct ig_rf_regfile *parent);
struct ig_rf_reg     *ig_lib_add_regfile_reg   (struct ig_lib_db *db, const char *name, struct ig_rf_entry *parent);

struct ig_lib_connection_info *ig_lib_connection_info_new  (GStringChunk *str_chunks, struct ig_object *obj, const char *local_name, enum ig_lib_connection_dir dir);
struct ig_lib_connection_info *ig_lib_connection_info_copy (GStringChunk *str_chunks, struct ig_lib_connection_info *original);
void                           ig_lib_connection_info_free (struct ig_lib_connection_info *cinfo);

bool ig_lib_connection (struct ig_lib_db *db, const char *signame, struct ig_lib_connection_info *source, GList *targets, GList **gen_objs);
bool ig_lib_parameter  (struct ig_lib_db *db, const char *parname, const char *defvalue, GList *targets, GList **gen_objs);

#ifdef __cplusplus
}
#endif

#endif

