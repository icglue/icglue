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
 * @brief Database lowlevel types and functions.
 */
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

/**
 * @brief Distinguish object types in @ref ig_object.
 */
enum ig_object_type {
    IG_OBJ_PORT,
    IG_OBJ_PIN,
    IG_OBJ_PARAMETER,
    IG_OBJ_ADJUSTMENT,
    IG_OBJ_DECLARATION,
    IG_OBJ_CODESECTION,
    IG_OBJ_MODULE,
    IG_OBJ_INSTANCE,
    IG_OBJ_REGFILE_REG,
    IG_OBJ_REGFILE_ENTRY,
    IG_OBJ_REGFILE
};

/**
 * @brief Attributes used in @ref ig_object
 */
struct ig_attribute {
    bool        constant; /**< @brief Attribute is write-once/read-only. */
    const char *value;    /**< @brief Value of attribute. */
};

/**
 * @brief Common object data type.
 *
 * For memory allocation/free see @ref ig_obj_new and @ref ig_obj_free.
 */
struct ig_object {
    const char          *id;           /**< @brief Unique Object-ID */
    enum  ig_object_type type;         /**< @brief Type of Object stored in @c obj */
    gpointer             obj;          /**< @brief Actual Data. Type depending on @ref type */

    GHashTable   *attributes;          /**< @brief Attributes. Key: (const char *), value: (struct @ref ig_attribute *). */
    GStringChunk *string_storage;      /**< @brief Strings used here, in @ref attributes and @ref obj. */
    bool          string_storage_free; /**< @brief Free @ref string_storage when freeing object. */
};

/**
 * @brief Distinguish port direction in @ref ig_port.
 */
enum ig_port_dir {
    IG_PD_IN,
    IG_PD_OUT,
    IG_PD_BIDIR,
};

/**
 * @brief Module port data.
 */
struct ig_port {
    struct ig_object *object; /**< @brief Related Object. */

    const char      *name;    /**< @brief Name of port. */
    enum ig_port_dir dir;     /**< @brief Direction of port. */

    struct ig_module *parent; /**< @brief Module containing port. */
};

/**
 * @brief Module parameter data.
 */
struct ig_param {
    struct ig_object *object; /**< @brief Related Object. */

    const char *name;         /**< @brief Name of parameter. */
    const char *value;        /**< @brief Default value of parameter. */
    bool        local;        /**< @brief Set if local parameter. */

    struct ig_module *parent; /**< @brief Module containing parameter. */
};

/**
 * @brief Module declaration data.
 */
struct ig_decl {
    struct ig_object *object;       /**< @brief Related Object. */

    const char *name;               /**< @brief Name of declaration. */
    bool default_type;              /**< @brief Set if declaration is of default type (language dependant). */

    const char *default_assignment; /**< @brief Default assignment to declared variable or NULL if unassigned. */

    struct ig_module *parent;       /**< @brief Module containing declaration. */
};

/**
 * @brief Module codesection data.
 */
struct ig_code {
    struct ig_object *object; /**< @brief Related Object. */

    const char *name;         /**< @brief Name of codesection. */
    const char *code;         /**< @brief Actual code. */

    struct ig_module *parent; /**< @brief Module containing codesection. */
};

/**
 * @brief Regfile single register data.
 */
struct ig_rf_reg {
    struct ig_object *object;   /**< @brief Related Object. */

    const char *name;           /**< @brief Name of register. */

    struct ig_rf_entry *parent; /**< @brief Regfile-entry containing register. */
};

/**
 * @brief Regfile entry data.
 */
struct ig_rf_entry {
    struct ig_object *object;     /**< @brief Related Object. */

    const char *name;             /**< @brief Name of entry. */

    GQueue *regs;                 /**< @brief Registers of entry. Queue data: (struct @ref ig_rf_reg *) */

    struct ig_rf_regfile *parent; /**< @brief Regfile containing regfile-entry. */
};

/**
 * @brief Regfile data.
 */
struct ig_rf_regfile {
    struct ig_object *object; /**< @brief Related Object. */

    const char *name;         /**< @brief Name of regfile. */

    GQueue *entries;          /**< @brief Regfile-entries. Queue data: (struct @ref ig_rf_entry *) */

    struct ig_module *parent; /**< @brief Module containing regfile. */
};

/**
 * @brief Module data.
 */
struct ig_module {
    struct ig_object *object;             /**< @brief Related Object. */

    const char *name;                     /**< @brief Name of module. */
    bool        ilm;                      /**< @brief ILM property. */
    bool        resource;                 /**< @brief Resource property. */

    /* module content */
    GQueue *params;                       /**< @brief Parameters.   Queue data: (struct @ref ig_param *)      */
    GQueue *ports;                        /**< @brief Ports.        Queue data: (struct @ref ig_port *)       */
    GQueue *decls;                        /**< @brief Declarations. Queue data: (struct @ref ig_decl *)       */
    GQueue *code;                         /**< @brief Codesections. Queue data: (struct @ref ig_code *)       */
    GQueue *regfiles;                     /**< @brief Regfiles.     Queue data: (struct @ref ig_rf_regfile *) */
    /* child instances inside module */
    GQueue *child_instances;              /**< @brief Instances within module. Queue data: (struct @ref ig_instance *) */
    /* instances of this module elsewhere */
    GQueue *mod_instances;                /**< @brief Instances of module. Queue data: (struct @ref ig_instance *) */
    /* default instance of this module */
    struct ig_instance *default_instance; /**< @brief Default instance of non-resource module. */
};

/**
 * @brief Instance pin data.
 */
struct ig_pin {
    struct ig_object *object;   /**< @brief Related Object. */

    const char *name;           /**< @brief Name of pin */
    const char *connection;     /**< @brief Value/signal connected to pin. */

    struct ig_instance *parent; /**< @brief Instance containing pin */
};

/**
 * @brief Instance parameter adjustment data.
 */
struct ig_adjustment {
    struct ig_object *object;   /**< @brief Related Object. */

    const char *name;           /**< @brief Name of parameter. */
    const char *value;          /**< @brief Adjusted value. */

    struct ig_instance *parent; /**< @brief Instance containing adjustment. */
};

/**
 * @brief Instance data.
 */
struct ig_instance {
    struct ig_object *object; /**< @brief Related Object. */

    const char       *name;   /**< @brief Name of instance. */
    struct ig_module *module; /**< @brief Module instanciated. */

    struct ig_module *parent; /**< @brief Module instanciating instance. */

    /* instance values */
    GQueue *adjustments;      /**< @brief Instance adjustments. Queue data: (struct @ref ig_adjustment *) */
    GQueue *pins;             /**< @brief Instance pins. Queue data: (struct @ref ig_pin *) */
};

/* TODO: net? */

/*******************************************************
 * Functions
 *******************************************************/

/**
 * @brief Create new object.
 * @param type Type of object to create.
 * @param name Name of object (depending on type this has to be unique).
 * @param parent Parent-Object in hierarchy or @c NULL.
 * @param obj Actual data structure for data represented by result object.
 * @param storage GStringChunk string storage for shared string storage or NULL to create local string storage.
 * @return The newly created object struct or NULL in case of an error.
 */
struct ig_object *ig_obj_new (enum ig_object_type type, const char *name, struct ig_object *parent, gpointer obj, GStringChunk *storage);

/**
 * @brief Free object data.
 * @param obj Pointer to object to free.
 *
 * This frees the ig_object struct, its attributes and if allocated its string container.
 */
void ig_obj_free (struct ig_object *obj);


/**
 * @brief Set attribute of object.
 * @param obj Object where attribute is set.
 * @param name Name of attribute to set.
 * @param value Value to set.
 * @param constant Make attribute constant (read-only).
 * @return @c true on success, @c false in case of errors.
 */
bool ig_obj_attr_set (struct ig_object *obj, const char *name, const char *value, bool constant);

/**
 * @brief Get attribute of object.
 * @param obj Object to get attribute from.
 * @param name Name of attribute to get.
 * @return Value of specified attribute of object or @c NULL in case of an error/nonexisting attribute.
 */
const char *ig_obj_attr_get (struct ig_object *obj, const char *name);

struct ig_port *ig_port_new  (const char *name, enum ig_port_dir dir, struct ig_module *parent, GStringChunk *storage);
void            ig_port_free (struct ig_port *port);

struct ig_param *ig_param_new  (const char *name, const char *value, bool local, struct ig_module *parent, GStringChunk *storage);
void             ig_param_free (struct ig_param *param);

struct ig_decl *ig_decl_new (const char *name, const char *assign, bool default_type, struct ig_module *parent, GStringChunk *storage);
void            ig_decl_free (struct ig_decl *decl);

struct ig_code *ig_code_new  (const char *name, const char *codesection, struct ig_module *parent, GStringChunk *storage);
void            ig_code_free (struct ig_code *code);

struct ig_rf_reg *ig_rf_reg_new (const char *name, struct ig_rf_entry *parent, GStringChunk *storage);
void              ig_rf_reg_free (struct ig_rf_reg *reg);

struct ig_rf_entry *ig_rf_entry_new (const char *name, struct ig_rf_regfile *parent, GStringChunk *storage);
void                ig_rf_entry_free (struct ig_rf_entry *entry);

struct ig_rf_regfile *ig_rf_regfile_new (const char *name, struct ig_module *parent, GStringChunk *storage);
void                  ig_rf_regfile_free (struct ig_rf_regfile *regfile);

struct ig_module *ig_module_new (const char *name, bool ilm, bool resource, GStringChunk *storage);
void              ig_module_free (struct ig_module *module);

struct ig_pin *ig_pin_new (const char *name, const char *connection, struct ig_instance *parent, GStringChunk *storage);
void           ig_pin_free (struct ig_pin *pin);

struct ig_adjustment *ig_adjustment_new (const char *name, const char *value, struct ig_instance *parent, GStringChunk *storage);
void                  ig_adjustment_free (struct ig_adjustment *adjustment);

struct ig_instance *ig_instance_new (const char *name, struct ig_module *module, struct ig_module *parent, GStringChunk *storage);
void                ig_instance_free (struct ig_instance *instance);

#ifdef __cplusplus
}
#endif

#endif

