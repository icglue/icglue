/*
 *  ICGlue is a Tcl-Library for scripted HDL generation
 *  Copyright (C) 2017-2020  Andreas Dixius, Felix Neumärker
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

#include <logger.h>

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
    IG_OBJ_REGFILE,
    IG_OBJ_NET,
    IG_OBJ_GENERIC
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
 * For initialization/memory free see @ref ig_obj_init, @ref ig_obj_ref, @ref ig_obj_unref,
 * @ref ig_obj_free and @ref ig_obj_free_full.
 */
struct ig_object {
    enum  ig_object_type type;         /**< @brief Type of Object stored in inheriting struct. */
    const char          *id;           /**< @brief Unique Object-ID. */
    const char          *name;         /**< @brief Object name. */

    int refcount;                      /**< @brief Reference count for memory management. */

    GHashTable   *attributes;          /**< @brief Attributes. Key: (const char *), value: (struct @ref ig_attribute *). */
    GStringChunk *string_storage;      /**< @brief Strings used here, in @ref attributes and inheriting struct. */
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
 *
 * For memory allocation/free see @ref ig_port_new and @ref ig_port_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_port {
    struct ig_object object;  /**< @brief Inherited @ref ig_object struct. */

    enum ig_port_dir dir;     /**< @brief Direction of port. */

    struct ig_module *parent; /**< @brief Module containing port. */
    struct ig_net    *net;    /**< @brief Net connected to port or @c NULL. */
};

/**
 * @brief Module parameter data.
 *
 * For memory allocation/free see @ref ig_param_new and @ref ig_param_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_param {
    struct ig_object object;    /**< @brief Inherited @ref ig_object struct. */

    const char *value;          /**< @brief Default value of parameter. */
    bool        local;          /**< @brief Set if local parameter. */

    struct ig_module  *parent;  /**< @brief Module containing parameter. */
    struct ig_generic *generic; /**< @brief Generic belonging to parameter or @c NULL. */
};

/**
 * @brief Module declaration data.
 *
 * For memory allocation/free see @ref ig_decl_new and @ref ig_decl_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_decl {
    struct ig_object object;  /**< @brief Inherited @ref ig_object struct. */

    struct ig_module *parent; /**< @brief Module containing declaration. */
    struct ig_net    *net;    /**< @brief Net connected to decl or @c NULL. */
};

/**
 * @brief Module codesection data.
 *
 * For memory allocation/free see @ref ig_code_new and @ref ig_code_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_code {
    struct ig_object object;  /**< @brief Inherited @ref ig_object struct. */

    const char *code;         /**< @brief Actual code. */

    struct ig_module *parent; /**< @brief Module containing codesection. */
};

/**
 * @brief Regfile single register data.
 *
 * For memory allocation/free see @ref ig_rf_reg_new and @ref ig_rf_reg_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_rf_reg {
    struct ig_object object;    /**< @brief Inherited @ref ig_object struct. */

    struct ig_rf_entry *parent; /**< @brief Regfile-entry containing register. */
};

/**
 * @brief Regfile entry data.
 *
 * For memory allocation/free see @ref ig_rf_entry_new and @ref ig_rf_entry_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_rf_entry {
    struct ig_object object;      /**< @brief Inherited @ref ig_object struct. */

    GQueue *regs;                 /**< @brief Registers of entry. Queue data: (struct @ref ig_rf_reg *) */

    struct ig_rf_regfile *parent; /**< @brief Regfile containing regfile-entry. */
};

/**
 * @brief Regfile data.
 *
 * For memory allocation/free see @ref ig_rf_regfile_new and @ref ig_rf_regfile_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_rf_regfile {
    struct ig_object object;  /**< @brief Inherited @ref ig_object struct. */

    GQueue *entries;          /**< @brief Regfile-entries. Queue data: (struct @ref ig_rf_entry *) */

    struct ig_module *parent; /**< @brief Module containing regfile. */
};

/**
 * @brief Module data.
 *
 * For memory allocation/free see @ref ig_module_new and @ref ig_module_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_module {
    struct ig_object object;  /**< @brief Inherited @ref ig_object struct. */

    bool ilm;                 /**< @brief ILM property. */
    bool resource;            /**< @brief Resource property. */

    /* module content */
    GQueue *params;           /**< @brief Parameters.   Queue data: (struct @ref ig_param *)      */
    GQueue *ports;            /**< @brief Ports.        Queue data: (struct @ref ig_port *)       */
    GQueue *decls;            /**< @brief Declarations. Queue data: (struct @ref ig_decl *)       */
    GQueue *code;             /**< @brief Codesections. Queue data: (struct @ref ig_code *)       */
    GQueue *regfiles;         /**< @brief Regfiles.     Queue data: (struct @ref ig_rf_regfile *) */
    /* child instances inside module */
    GQueue *child_instances;  /**< @brief Instances within module. Queue data: (struct @ref ig_instance *) */
    /* instances of this module elsewhere */
    GQueue *mod_instances;    /**< @brief Instances of module. Queue data: (struct @ref ig_instance *) */
    /* default instance of this module */
    struct ig_instance *default_instance; /**< @brief Default instance of non-resource module. */
};

/**
 * @brief Instance pin data.
 *
 * For memory allocation/free see @ref ig_pin_new and @ref ig_pin_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_pin {
    struct ig_object object;    /**< @brief Inherited @ref ig_object struct. */

    const char *connection;     /**< @brief Value/signal connected to pin. */

    struct ig_instance *parent; /**< @brief Instance containing pin */
    struct ig_net      *net;    /**< @brief Net connected to pin or @c NULL. */
};

/**
 * @brief Instance parameter adjustment data.
 *
 * For memory allocation/free see @ref ig_adjustment_new and @ref ig_adjustment_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_adjustment {
    struct ig_object object;     /**< @brief Inherited @ref ig_object struct. */

    const char *value;           /**< @brief Adjusted value. */

    struct ig_instance *parent;  /**< @brief Instance containing adjustment. */
    struct ig_generic  *generic; /**< @brief Generic belonging to adjustment or @c NULL. */
};

/**
 * @brief Instance data.
 *
 * For memory allocation/free see @ref ig_instance_new and @ref ig_instance_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_instance {
    struct ig_object object;  /**< @brief Inherited @ref ig_object struct. */

    struct ig_module *module; /**< @brief Module instanciated. */

    struct ig_module *parent; /**< @brief Module instanciating instance. */

    /* instance values */
    GQueue *adjustments;      /**< @brief Instance adjustments. Queue data: (struct @ref ig_adjustment *) */
    GQueue *pins;             /**< @brief Instance pins. Queue data: (struct @ref ig_pin *) */
};

/**
 * @brief Net data.
 *
 * For memory allocation/free see @ref ig_net_new and @ref ig_net_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_net {
    struct ig_object object;  /**< @brief Inherited @ref ig_object struct. */

    GQueue *objects;          /**< @brief Objects of net. */
};

/**
 * @brief Generic data.
 *
 * For memory allocation/free see @ref ig_generic_new and @ref ig_generic_free.
 * For reference counted memory management see @ref ig_obj_ref and @ref ig_obj_unref.
 */
struct ig_generic {
    struct ig_object object;  /**< @brief Inherited @ref ig_object struct. */

    GQueue *objects;          /**< @brief Objects of generic. */
};

/*******************************************************
 * Defines
 *******************************************************/

/**
 * @brief Use struct derived from struct ig_object as struct ig_object.
 */
#define IG_OBJECT(x)        (&((x)->object))

/**
 * @brief Cast from any pointer to pointer to struct ig_object.
 */
#define PTR_TO_IG_OBJECT(x) ((struct ig_object *)(x))

/*******************************************************
 * Functions
 *******************************************************/

/**
 * @brief Human readable name of object type.
 * @param type Object type.
 * @return Readable type name.
 */
const char *ig_obj_type_name (enum ig_object_type type);

/**
 * @brief Initialize new object.
 * @param type Type of object to create.
 * @param name Name of object (depending on type this has to be unique).
 * @param plist NULL-Terminated list of Parent-Objects in hierarchy.
 * @param obj object data structure.
 * @param storage GStringChunk string storage for shared string storage or @c NULL to create local string storage.
 * @return The newly created object struct or @c NULL in case of an error.
 *
 * This function should be called within the allocation function of the actual data struct pointed to by @c obj.
 * The initial reference count is set to 0 (see @ref ig_obj_ref and @ref ig_obj_unref).
 */
void ig_obj_init (enum ig_object_type type, const char *name, struct ig_object *plist[], struct ig_object *obj, GStringChunk *storage);

/**
 * @brief Free object data.
 * @param obj Pointer to object to free.
 *
 * This frees the ig_object struct, its attributes and if allocated its string container.
 * It should preferably called from the free function of the data struct pointed to by @c obj->obj.
 */
void ig_obj_free (struct ig_object *obj);

/**
 * @brief Free object data and related data struct.
 * @param obj Pointer to object to free.
 *
 * This frees the ig_object struct, its attributes and if allocated its string container.
 * It calls the free function of the data struct pointed to by @c obj->obj.
 */
void ig_obj_free_full (struct ig_object *obj);

/**
 * @brief Increment objects reference count.
 * @param obj Pointer to object.
 *
 * This increments the object's reference count.
 * References should be managed carefully in order to prevent cycles.
 * The current approach is: References are kept at parts which manage
 * some sort of "children" (not necessarily representing hierarchy) - so
 * for example a list of subobjects (e.g. ports in a module, child-instances
 * in a module, instanciations of a module, pins in an instance).
 * Back-references in this case must not increment the ref-count - currently
 * they are deleted (set to @c NULL) when the managing object is freed.
 */
void ig_obj_ref (struct ig_object *obj);

/**
 * @brief Decrement objects reference count.
 * @param obj Pointer to object.
 *
 * This decrements the object's reference count.
 * If the reference count reaches a value <= 0 the object is freed using
 * @ref ig_obj_free_full.
 */
void ig_obj_unref (struct ig_object *obj);


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

/**
 * @brief Get all available attributes of object.
 * @param obj Object to the attribute list from.
 * @return List with all available attributes
 */
GList *ig_obj_attr_get_keys (struct ig_object *obj);

/**
 * @brief Set multiple object attributes at once.
 * @param obj Object where attributes are to be set.
 * @param list of attributes and values, list data: @c (char*).
 * @return @c true on success or @c false if one or more attributes could not be set.
 *
 * The list must contain attributes and values interleaved (so {attribute 1, value 1, attribute 2, value 2, ...}).
 */
bool ig_obj_attr_set_from_gslist (struct ig_object *obj, GList *list);

/**
 * @brief Create new port data struct.
 * @param name Name of port.
 * @param dir Port direction.
 * @param parent Module where port is to be added.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated port structure or @c NULL in case of an error.
 *
 * This creates the port with the related object and adds the port to the specified parent module.
 * Default attributes are set in the related object.
 */
struct ig_port *ig_port_new  (const char *name, enum ig_port_dir dir, struct ig_module *parent, GStringChunk *storage);

/**
 * @brief Free port data struct.
 * @param port Pointer to port data struct to free.
 *
 * Frees the port data struct together with the related object.
 */
void ig_port_free (struct ig_port *port);

/**
 * @brief Create new parameter data struct.
 * @param name Name of parameter.
 * @param value Value of parameter.
 * @param local Local parameter property.
 * @param parent Module where parameter is to be added.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated parameter structure or @c NULL in case of an error.
 *
 * This creates the parameter with the related object and adds the parameter to the specified parent module.
 * Default attributes are set in the related object.
 */
struct ig_param *ig_param_new  (const char *name, const char *value, bool local, struct ig_module *parent, GStringChunk *storage);

/**
 * @brief Free parameter data struct.
 * @param param Pointer to parameter data struct to free.
 *
 * Frees the parameter data struct together with the related object.
 */
void ig_param_free (struct ig_param *param);

/**
 * @brief Create new declaration data struct.
 * @param name Name of declared variable.
 * @param parent Module where declaration is to be added.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated declaration structure or @c NULL in case of an error.
 *
 * This creates the declaration with the related object and adds the declaration to the specified parent module.
 * Default attributes are set in the related object.
 */
struct ig_decl *ig_decl_new (const char *name, struct ig_module *parent, GStringChunk *storage);

/**
 * @brief Free declaration data struct.
 * @param decl Pointer to declaration data struct to free.
 *
 * Frees the declaration data struct together with the related object.
 */
void ig_decl_free (struct ig_decl *decl);

/**
 * @brief Create new codesection data struct.
 * @param name Name of codesection or @c NULL.
 * @param codesection Code of codesection.
 * @param parent Module where codesection is to be added.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated codesection structure or @c NULL in case of an error.
 *
 * This creates the codesection with the related object and adds the codesection to the specified parent module.
 * Default attributes are set in the related object.
 */
struct ig_code *ig_code_new  (const char *name, const char *codesection, struct ig_module *parent, GStringChunk *storage);

/**
 * @brief Free codesection data struct.
 * @param code Pointer to codesection data struct to free.
 *
 * Frees the codesection data struct together with the related object.
 */
void ig_code_free (struct ig_code *code);

/**
 * @brief Create new register data struct.
 * @param name Name of register.
 * @param parent Regfile-entry where register is to be added.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated register structure or @c NULL in case of an error.
 *
 * This creates the register with the related object and adds the register to the specified parent regfile-entry.
 * Default attributes are set in the related object.
 */
struct ig_rf_reg *ig_rf_reg_new (const char *name, struct ig_rf_entry *parent, GStringChunk *storage);

/**
 * @brief Free register data struct.
 * @param reg Pointer to register data struct to free.
 *
 * Frees the register data struct together with the related object.
 */
void ig_rf_reg_free (struct ig_rf_reg *reg);

/**
 * @brief Create new regfile-entry data struct.
 * @param name Name of regfile-entry.
 * @param parent Regfile where regfile-entry is to be added.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated regfile-entry structure or @c NULL in case of an error.
 *
 * This creates the regfile-entry with the related object and adds the regfile-entry to the specified parent regfile.
 * Default attributes are set in the related object.
 */
struct ig_rf_entry *ig_rf_entry_new (const char *name, struct ig_rf_regfile *parent, GStringChunk *storage);

/**
 * @brief Free regfile-entry data struct.
 * @param entry Pointer to regfile-entry data struct to free.
 *
 * Frees the regfile-entry data struct together with the related object.
 */
void ig_rf_entry_free (struct ig_rf_entry *entry);

/**
 * @brief Create new regfile data struct.
 * @param name Name of regfile.
 * @param parent Module where regfile is to be added.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated regfile structure or @c NULL in case of an error.
 *
 * This creates the regfile with the related object and adds the regfile to the specified parent module.
 * Default attributes are set in the related object.
 */
struct ig_rf_regfile *ig_rf_regfile_new (const char *name, struct ig_module *parent, GStringChunk *storage);

/**
 * @brief Free regfile data struct.
 * @param regfile Pointer to regfile data struct to free.
 *
 * Frees the regfile data struct together with the related object.
 */
void ig_rf_regfile_free (struct ig_rf_regfile *regfile);

/**
 * @brief Create new module data struct.
 * @param name Name of module.
 * @param ilm ILM property.
 * @param resource Resource property. Resource modules must not contain any regfiles, instances, codesections.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated module structure or @c NULL in case of an error.
 *
 * This creates the module with the related object.
 * Default attributes are set in the related object.
 */
struct ig_module *ig_module_new (const char *name, bool ilm, bool resource, GStringChunk *storage);

/**
 * @brief Free module data struct.
 * @param module Pointer to module data struct to free.
 *
 * Frees the module data struct together with the related object.
 */
void ig_module_free (struct ig_module *module);

/**
 * @brief Create new pin data struct.
 * @param name Name of pin.
 * @param connection Value/wire connectod to pin.
 * @param parent Instance where pin is to be added.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated pin structure or @c NULL in case of an error.
 *
 * This creates the pin with the related object and adds the pin to the specified parent instance.
 * Default attributes are set in the related object.
 */
struct ig_pin *ig_pin_new (const char *name, const char *connection, struct ig_instance *parent, GStringChunk *storage);

/**
 * @brief Free pin data struct.
 * @param pin Pointer to pin data struct to free.
 *
 * Frees the pin data struct together with the related object.
 */
void ig_pin_free (struct ig_pin *pin);

/**
 * @brief Create new parameter adjustmen data struct.
 * @param name Name of parameter.
 * @param value Adjusted value for parameter.
 * @param parent Instance where adjustment is to be added.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated adjustment structure or @c NULL in case of an error.
 *
 * This creates the adjustment with the related object and adds the adjustment to the specified parent instance.
 * Default attributes are set in the related object.
 */
struct ig_adjustment *ig_adjustment_new (const char *name, const char *value, struct ig_instance *parent, GStringChunk *storage);

/**
 * @brief Free adjustment data struct.
 * @param adjustment Pointer to adjustment data struct to free.
 *
 * Frees the adjustment data struct together with the related object.
 */
void ig_adjustment_free (struct ig_adjustment *adjustment);

/**
 * @brief Create new instance data struct.
 * @param name Name of instance.
 * @param module Module to be instanciated.
 * @param parent Module where instance is to be added or @c NULL.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated instance structure or @c NULL in case of an error.
 *
 * This creates the instance with the related object and adds the instance to the specified parent module.
 * Default attributes are set in the related object.
 */
struct ig_instance *ig_instance_new (const char *name, struct ig_module *module, struct ig_module *parent, GStringChunk *storage);

/**
 * @brief Free instance data struct.
 * @param instance Pointer to instance data struct to free.
 *
 * Frees the instance data struct together with the related object.
 */
void ig_instance_free (struct ig_instance *instance);


/**
 * @brief Create new net data struct.
 * @param name Name of net.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated net structure or @c NULL in case of an error.
 *
 * Default attributes are set in the related object.
 */
struct ig_net *ig_net_new (const char *name, GStringChunk *storage);

/**
 * @brief Free net data struct.
 * @param net Pointer to net data struct to free.
 *
 * Frees the net data struct together with the related object.
 */
void ig_net_free (struct ig_net *net);

/**
 * @brief Create new generic data struct.
 * @param name Name of generic.
 * @param storage String storage to use or @c NULL.
 * @return The newly allocated generic structure or @c NULL in case of an error.
 *
 * Default attributes are set in the related object.
 */
struct ig_generic *ig_generic_new (const char *name, GStringChunk *storage);

/**
 * @brief Free generic data struct.
 * @param generic Pointer to generic data struct to free.
 *
 * Frees the generic data struct together with the related object.
 */
void ig_generic_free (struct ig_generic *generic);


/*******************************************************
 * Cast inline functions
 *******************************************************/

#define __IG_OBJECT_GEN_CAST(NAME, VTYPE, ETYPE) \
    /**\
       @brief Checked cast from struct ig_object pointer to VTYPE pointer.\
       @param obj ig_object to cast.\
       @return pointer casted to VTYPE.\
     \
       If @c obj is @c NULL, @c NULL will be returned.\
       If @c obj is of wrong type, an internal error is raised.\
     */ \
    static inline VTYPE *NAME (struct ig_object *obj) { \
        if (obj == NULL) return NULL; \
        if (obj->type == ETYPE) { \
            return (VTYPE *)obj; \
        } \
        \
        log_errorint ("DOCst", "Cast of ig_object to %s failed: actual type was %s", ig_obj_type_name (ETYPE), ig_obj_type_name (obj->type)); \
        \
        return NULL; \
    }

__IG_OBJECT_GEN_CAST (IG_PORT,       struct ig_port,       IG_OBJ_PORT)
__IG_OBJECT_GEN_CAST (IG_PIN,        struct ig_pin,        IG_OBJ_PIN)
__IG_OBJECT_GEN_CAST (IG_PARAM,      struct ig_param,      IG_OBJ_PARAMETER)
__IG_OBJECT_GEN_CAST (IG_ADJUSTMENT, struct ig_adjustment, IG_OBJ_ADJUSTMENT)
__IG_OBJECT_GEN_CAST (IG_DECL,       struct ig_decl,       IG_OBJ_DECLARATION)
__IG_OBJECT_GEN_CAST (IG_CODE,       struct ig_code,       IG_OBJ_CODESECTION)
__IG_OBJECT_GEN_CAST (IG_MODULE,     struct ig_module,     IG_OBJ_MODULE)
__IG_OBJECT_GEN_CAST (IG_INSTANCE,   struct ig_instance,   IG_OBJ_INSTANCE)
__IG_OBJECT_GEN_CAST (IG_RF_REG,     struct ig_rf_reg,     IG_OBJ_REGFILE_REG)
__IG_OBJECT_GEN_CAST (IG_RF_ENTRY,   struct ig_rf_entry,   IG_OBJ_REGFILE_ENTRY)
__IG_OBJECT_GEN_CAST (IG_RF_REGFILE, struct ig_rf_regfile, IG_OBJ_REGFILE)
__IG_OBJECT_GEN_CAST (IG_NET,        struct ig_net,        IG_OBJ_NET)
__IG_OBJECT_GEN_CAST (IG_GENERIC,    struct ig_generic,    IG_OBJ_GENERIC)

#undef __IG_OBJECT_GEN_CAST

#ifdef __cplusplus
}
#endif

#endif

