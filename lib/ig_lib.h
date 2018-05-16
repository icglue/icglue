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

/**
 * @file
 * @brief Core library functions for ICGlue.
 */
#ifndef __IG_LIB_H__
#define __IG_LIB_H__

#include "ig_data.h"

#include <glib.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Database struct with all available objects.
 *
 * For memory allocation/free see @ref ig_lib_db_new and @ref ig_lib_db_free.
 */
struct ig_lib_db {
    GHashTable *objects_by_id;     /**< @brief Mapping of ID to objects. Key: <tt> (const char *) </tt> -> value: <tt> (struct @ref ig_object *) </tt> */

    GHashTable *modules_by_name;   /**< @brief Mapping of module names to module data. Key: <tt> (const char *) </tt> -> value: <tt> (struct @ref ig_module *) </tt> */
    GHashTable *modules_by_id;     /**< @brief Mapping of Object-ID to module data. Key: <tt> (const char *) </tt> -> value: <tt> (struct @ref ig_module *) </tt> */

    GHashTable *instances_by_name; /**< @brief Mapping of instance names to instance data. Key: <tt> (const char *) </tt> -> value: <tt> (struct @ref ig_instance *) </tt> */
    GHashTable *instances_by_id;   /**< @brief Mapping of Object-ID to instance data. Key: <tt> (const char *) </tt> -> value: <tt> (struct @ref ig_instance *) </tt> */

    /* TODO: remaining */

    GStringChunk *str_chunks;      /**< @brief String container used for all generated objects. */
};

/**
 * @brief Logical direction of a signal in hierarchy.
 */
enum ig_lib_connection_dir {
    IG_LCDIR_UP,     /**< Signal towards upper hierarchy elements.*/
    IG_LCDIR_DOWN,   /**< Signal towards lower hierarchy elements. */
    IG_LCDIR_BIDIR,  /**< Bidirectional signal. */
    IG_LCDIR_DEFAULT /**< Direction to be calculated based on other elements. */
};

/**
 * @brief Temporary data for storing signal/parameter data of a single element in hierarchy.
 *
 * For memory allocation/free see @ref ig_lib_connection_info_new, @ref ig_lib_connection_info_copy and @ref ig_lib_connection_info_free.
 */
struct ig_lib_connection_info {
    struct ig_object          *obj;         /**< @brief Object of signal/parameter hierarchy (instance or module object). */
    const char                *parent_name; /**< @brief Signal/parameter name at upper hierarchy level or @c NULL. */
    const char                *local_name;  /**< @brief Signal/parameter name at current hierarchy level or @c NULL. */
    bool                       is_explicit; /**< @brief Signal/parameter name was explicitly set at this hierarchy point. */
    bool                       force_name;  /**< @brief Signal/parameter name must be kept verbatim. */
    enum ig_lib_connection_dir dir;         /**< @brief Signal direction in hierarchy.*/
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

