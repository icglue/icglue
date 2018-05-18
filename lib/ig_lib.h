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
    bool                       is_explicit; /**< @brief Hierarchy element is explicitly set. */
    bool                       force_name;  /**< @brief Signal/parameter name must be kept verbatim. */
    enum ig_lib_connection_dir dir;         /**< @brief Signal direction in hierarchy.*/
};

/**
 * @brief Create and initialize new icglue database struct.
 * @return The newly created struct.
 */
struct ig_lib_db *ig_lib_db_new  ();

/**
 * @brief Free icglue database content.
 * @param db Database to clear.
 */
void ig_lib_db_clear (struct ig_lib_db *db);

/**
 * @brief Free icglue database struct.
 * @param db Database to free.
 */
void ig_lib_db_free (struct ig_lib_db *db);

/**
 * @brief Add a new module to the database.
 * @param db Database to modify.
 * @param name Name of the module.
 * @param ilm ILM property of module to add.
 * @param resource Resource property of module to add.
 * @return The newly created module data or @c NULL.
 */
struct ig_module *ig_lib_add_module      (struct ig_lib_db *db, const char *name, bool ilm, bool resource);

/**
 * @brief Add a new module instance to the database.
 * @param db Database to modify.
 * @param name Name of the instance.
 * @param type Module to instanciate.
 * @param parent Module in which instance is to be added.
 * @return The newly created instance data or @c NULL.
 */
struct ig_instance *ig_lib_add_instance    (struct ig_lib_db *db, const char *name, struct ig_module *type, struct ig_module *parent);

/**
 * @brief Add a new codesection to the database.
 * @param db Database to modify.
 * @param name Name of new codesection or @c NULL.
 * @param code Code to add.
 * @param parent Module in which codesection is to be added.
 * @return The newly created codesection data or @c NULL.
 */
struct ig_code *ig_lib_add_codesection (struct ig_lib_db *db, const char *name, const char *code, struct ig_module *parent);

/**
 * @brief Add a new regfile to the database.
 * @param db Database to modify.
 * @param name Name of new regfile.
 * @param parent Module in which regfile is to be added.
 * @return The newly created regfile data or @c NULL.
 */
struct ig_rf_regfile *ig_lib_add_regfile       (struct ig_lib_db *db, const char *name, struct ig_module *parent);

/**
 * @brief Add a new regfile-entry to the database.
 * @param db Database to modify.
 * @param name Name of new regfile-entry.
 * @param parent Regfile in which regfile-entry is to be added.
 * @return The newly created regfile-entry data or @c NULL.
 */
struct ig_rf_entry *ig_lib_add_regfile_entry (struct ig_lib_db *db, const char *name, struct ig_rf_regfile *parent);

/**
 * @brief Add a new register to the database.
 * @param db Database to modify.
 * @param name Name of new register.
 * @param parent Regfile-entry in which register is to be added.
 * @return The newly created register data or @c NULL.
 */
struct ig_rf_reg *ig_lib_add_regfile_reg   (struct ig_lib_db *db, const char *name, struct ig_rf_entry *parent);

/**
 * @brief Create new connection info data.
 * @param str_chunks String container to use for newly created strings.
 * @param obj Object represented by this hierarchy element.
 * @param local_name Local name of signal/paramater at this hierarchy element or @c NULL.
 * @param dir Signal direction at this element.
 * @return The newly created connection info data or @c NULL.
 */
struct ig_lib_connection_info *ig_lib_connection_info_new  (GStringChunk *str_chunks, struct ig_object *obj, const char *local_name, enum ig_lib_connection_dir dir);

/**
 * @brief Create a copy of existing connection info data.
 * @param str_chunks String container to use for copies of strings.
 * @param original connection info to copy.
 * @return A copy of @c original or NULL.
 */
struct ig_lib_connection_info *ig_lib_connection_info_copy (GStringChunk *str_chunks, struct ig_lib_connection_info *original);

/**
 * @brief Free connection info data.
 * @param cinfo connection info data to free.
 */
void ig_lib_connection_info_free (struct ig_lib_connection_info *cinfo);

/**
 * @brief Create hierarchical signal.
 * @param db Database to use.
 * @param signame Signal name.
 * @param source Signal source or @c NULL. Will be freed after usage.
 * @param targets List of signal endpoints. List data: <tt> (struct @ref ig_lib_connection_info *) </tt>. Will be freed after usage.
 * @param[out] gen_objs List of newly created hierarchy pin/port/declaration elements of signal. List data: <tt> (struct ig_object *) </tt>.
 * @return true on success.
 *
 * @c source and @c targets will be freed on return, @c *gen_objs must be freed by caller.
 */
bool ig_lib_connection (struct ig_lib_db *db, const char *signame, struct ig_lib_connection_info *source, GList *targets, GList **gen_objs);

/**
 * @brief Create hierarchical parameter.
 * @param db Database to use.
 * @param parname Parameter name.
 * @param defvalue Parameter default value.
 * @param targets List of parameter endpoints. List data: <tt> (struct @ref ig_lib_connection_info *) </tt>. Will be freed after usage.
 * @param[out] gen_objs List of newly created hierarchy parameter/adjustment elements of parameter. List data: <tt> (struct ig_object *) </tt>.
 * @return true on success.
 *
 * @c targets will be freed on return, @c *gen_objs must be freed by caller.
 */
bool ig_lib_parameter  (struct ig_lib_db *db, const char *parname, const char *defvalue, GList *targets, GList **gen_objs);

#ifdef __cplusplus
}
#endif

#endif

