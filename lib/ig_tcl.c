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
#include "ig_lib.h"
#include "ig_tcl.h"
#include "logger.h"
#include "ig_logo.h"

#include <libgen.h>
#include <string.h>

#ifndef ICGLUE_LIB_NAMESPACE
#define ICGLUE_LIB_NAMESPACE "ig::db::"
#endif
#ifndef ICGLUE_LOG_NAMESPACE
#define ICGLUE_LOG_NAMESPACE "ig::"
#endif

/* TCLDOC
## @file ig_tcl.c
# @brief C-file for tcl core-library (db and log) functions.
#
# Actual code can be found in the Core-Library.
# The generated tcl-commands are shortly described here.
#
# @namespace ig::db
# @brief Lowlevel database commands covered by C-library.
*/

/* Tcl helper function for parsing lists in GLists of char * */
static int ig_tclc_tcl_string_list_parse (ClientData client_data, Tcl_Obj *obj, void *dest_ptr);

static void ig_tclc_connection_parse (const char *input, GString *id, GString *net, bool *adapt, bool *inv);
static void ig_tclc_check_name_and_warn (const char *name);

/* tcl proc declarations */
static int ig_tclc_create_module    (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_create_instance  (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_add_codesection  (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_add_regfile      (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_set_attribute    (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_get_attribute    (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_get_objs_of_obj  (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_connect          (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_parameter        (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_create_pin       (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_reset            (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_logger           (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_log              (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_log_stat         (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_print_logo       (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);

static int tcl_error_msg (Tcl_Interp *interp, const char *format, ...) __attribute__((format (printf, 2, 0)));
static int tcl_verror_msg (Tcl_Interp *interp, const char *format, va_list args);

static int tcl_dict_get_str (Tcl_Interp *interp, Tcl_Obj *tcl_dict, char *key, char **value);
static int tcl_dict_get_int (Tcl_Interp *interp, Tcl_Obj *tcl_dict, char *key, int *value);

void ig_add_tcl_commands (Tcl_Interp *interp)
{
    if (interp == NULL) return;

    struct ig_lib_db *lib_db = ig_lib_db_new ();

    Tcl_Namespace *db_ns = Tcl_CreateNamespace (interp, ICGLUE_LIB_NAMESPACE, NULL, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "create_module",       ig_tclc_create_module,   lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "create_instance",     ig_tclc_create_instance, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "add_codesection",     ig_tclc_add_codesection, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "add_regfile",         ig_tclc_add_regfile,     lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "set_attribute",       ig_tclc_set_attribute,   lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_attribute",       ig_tclc_get_attribute,   lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_modules",         ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_instances",       ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_ports",           ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_parameters",      ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_declarations",    ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_codesections",    ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_pins",            ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_adjustments",     ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_regfiles",        ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_regfile_entries", ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "get_regfile_regs",    ig_tclc_get_objs_of_obj, lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "connect",             ig_tclc_connect,         lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "parameter",           ig_tclc_parameter,       lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "create_pin",          ig_tclc_create_pin,      lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LIB_NAMESPACE "reset",               ig_tclc_reset,           lib_db, NULL);
    Tcl_Export (interp, db_ns, "*", true);

    Tcl_Namespace *log_ns = Tcl_CreateNamespace (interp, ICGLUE_LOG_NAMESPACE, NULL, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LOG_NAMESPACE "logger",              ig_tclc_logger,          lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LOG_NAMESPACE "log",                 ig_tclc_log,             lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LOG_NAMESPACE "log_stat",            ig_tclc_log_stat,        lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LOG_NAMESPACE "print_logo",          ig_tclc_print_logo,      lib_db, NULL);
    Tcl_Export (interp, log_ns, "*", true);
}

/* Tcl helper function for parsing lists in GLists */
static int ig_tclc_tcl_string_list_parse (ClientData client_data, Tcl_Obj *obj, void *dest_ptr)
{
    GList **list_dest = (GList **)dest_ptr;

    if (dest_ptr == NULL) {
        return 1;
    }

    GList *result = NULL;

    if (obj == NULL) {
        return 1;
    }

    Tcl_Obj *in_list = obj;

    int len         = 0;
    int temp_result = Tcl_ListObjLength (NULL, in_list, &len);
    if (temp_result != TCL_OK) return -1;

    for (int i = 0; i < len; i++) {
        Tcl_Obj *lit;
        temp_result = Tcl_ListObjIndex (NULL, in_list, i, &lit);
        if (temp_result != TCL_OK) {
            g_list_free (result);
            return -1;
        }
        if (lit == NULL) {
            g_list_free (result);
            return -1;
        }
        char *lit_str = Tcl_GetString (lit);

        result = g_list_prepend (result, lit_str);
    }

    *list_dest = g_list_reverse (result);
    return 1;
}


/* TCLDOC
##
# @brief Create a new module.
#
# @param args Parsed command arguments:<br>
# -name \<module-name\><br>
# [ (-ilm | -no-ilm) ]<br>
# [ -resource | -no-resource ]
#
# @return Object-ID of the newly created module or an error
*/
static int ig_tclc_create_module (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp, "Database is NULL");

    int int_true  = true;
    int int_false = false;

    int   ilm      = int_false;
    int   resource = int_false;
    char *name     = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-name",        NULL,                        (void *)&name,      "the name of the module to be created", NULL},

        {TCL_ARGV_CONSTANT, "-ilm",         GINT_TO_POINTER (int_true),  (void *)&ilm,       "module is ilm",    NULL},
        {TCL_ARGV_CONSTANT, "-no-ilm",      GINT_TO_POINTER (int_false), (void *)&ilm,       "module is no ilm", NULL},

        {TCL_ARGV_CONSTANT, "-resource",    GINT_TO_POINTER (int_true),  (void *)&resource,  "module is resource",    NULL},
        {TCL_ARGV_CONSTANT, "-no-resource", GINT_TO_POINTER (int_false), (void *)&resource,  "module is no resource", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (name == NULL) {
        return tcl_error_msg (interp, "No module name specified");
    }
    ig_tclc_check_name_and_warn (name);

    struct ig_module *module = ig_lib_add_module (db, name, ilm, resource);

    if (module == NULL) {
        return tcl_error_msg (interp, "Unable to create module \"%s\"", name);
    }

    Tcl_SetObjResult (interp, Tcl_NewStringObj (IG_OBJECT (module)->id, -1));

    return TCL_OK;
}

/* TCLDOC
##
# @brief Create a new instance of a module in another (parent) module.
#
# @param args Parsed command arguments:<br>
# -name \<instance-name\><br>
# -of-module \<module-id\><br>
# -parent-module \<parent-module-id\>
#
# @return Object-ID of the newly created instance or an error
*/
static int ig_tclc_create_instance (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    char *name          = NULL;
    char *of_module     = NULL;
    char *parent_module = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING, "-name",          NULL, (void *)&name,          "the name of the instance to be created", NULL},
        {TCL_ARGV_STRING, "-of-module",     NULL, (void *)&of_module,     "module of this instance", NULL},
        {TCL_ARGV_STRING, "-parent-module", NULL, (void *)&parent_module, "parent module containing this instance", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (name == NULL) return tcl_error_msg (interp, "No name specified for instance");
    ig_tclc_check_name_and_warn (name);

    if (of_module == NULL) return tcl_error_msg (interp, "No module specified for instance \"%s\"", name);
    if (parent_module == NULL) return tcl_error_msg (interp, " No parent module specified for instance \"%s\"", name);

    struct ig_module *of_mod = IG_MODULE (PTR_TO_IG_OBJECT (g_hash_table_lookup (db->modules_by_id, of_module)));
    if (of_mod == NULL) of_mod = IG_MODULE (PTR_TO_IG_OBJECT (g_hash_table_lookup (db->modules_by_name, of_module)));
    struct ig_module *pa_mod = IG_MODULE (PTR_TO_IG_OBJECT (g_hash_table_lookup (db->modules_by_id, parent_module)));
    if (pa_mod == NULL) pa_mod = IG_MODULE (PTR_TO_IG_OBJECT (g_hash_table_lookup (db->modules_by_name, parent_module)));

    if (of_module == NULL) return tcl_error_msg (interp, "Unable to find module \"%s\" in database", of_module);
    if (parent_module == NULL) return tcl_error_msg (interp, "Unable to find parent-module \"%s\" in database", parent_module);

    struct ig_instance *inst = ig_lib_add_instance (db, name, of_mod, pa_mod);

    if (inst == NULL) return tcl_error_msg (interp, "Unable to create instance \"%s\"", name);

    Tcl_SetObjResult (interp, Tcl_NewStringObj (IG_OBJECT (inst)->id, -1));

    return TCL_OK;
}

/* TCLDOC
##
# @brief Create a new codesection in a given module.
#
# @param args Parsed command arguments:<br>
# [ -name \<codesection-name\>]<br>
# -code \<code\><br>
# -parent-module \<parent-module-id\>
#
# @return Object-ID of the newly created module or an error
*/
static int ig_tclc_add_codesection (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    char *name          = NULL;
    char *code          = NULL;
    char *parent_module = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING, "-name",          NULL, (void *)&name,          "the name of the codesection to be created", NULL},
        {TCL_ARGV_STRING, "-code",          NULL, (void *)&code,          "code to add", NULL},
        {TCL_ARGV_STRING, "-parent-module", NULL, (void *)&parent_module, "parent module containing this codesection", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (code == NULL) return tcl_error_msg (interp, "No code specified for codesection");
    if (parent_module == NULL) return tcl_error_msg (interp,  "No parent module specified for codesection");

    struct ig_module *pa_mod = IG_MODULE (PTR_TO_IG_OBJECT (g_hash_table_lookup (db->modules_by_id, parent_module)));
    if (pa_mod == NULL) pa_mod = IG_MODULE (PTR_TO_IG_OBJECT (g_hash_table_lookup (db->modules_by_name, parent_module)));

    if (pa_mod == NULL) return tcl_error_msg (interp, "Unable to find parent module \"%s\" in database", parent_module);
    struct ig_code *cs = ig_lib_add_codesection (db, name, code, pa_mod);

    if (cs == NULL) return tcl_error_msg (interp, "Unable to create codesection for module \"%s\"", pa_mod->name);
    Tcl_SetObjResult (interp, Tcl_NewStringObj (IG_OBJECT (cs)->id, -1));

    return TCL_OK;
}

/* TCLDOC
##
# @brief Add regfile objects to another object.
#
# @param args Parsed command arguments:<br>
# ( -regfile \<regfile-name\><br>
# | -entry   \<regfile-entry-name\><br>
# | -reg     \<regfile-register-name\>)<br>
# -to \<parent-object-id\>
#
# @return Object-ID of the newly created object or an error
#
# A regfile can be added to a module,
# a regfile-entry can be added to a regfile,
# a regfile_register can be added to a regfile-entry.
*/
static int ig_tclc_add_regfile (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    char *regfile_name = NULL;
    char *entry_name   = NULL;
    char *reg_name     = NULL;
    char *to_id        = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-regfile", NULL, (void *)&regfile_name, "name of new regfile",          NULL},
        {TCL_ARGV_STRING,   "-entry",   NULL, (void *)&entry_name,   "name of new regfile-entry",    NULL},
        {TCL_ARGV_STRING,   "-reg",     NULL, (void *)&reg_name,     "name of new regfile-register", NULL},
        {TCL_ARGV_STRING,   "-to",      NULL, (void *)&to_id,        "object id to add to",          NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (to_id == NULL) return tcl_error_msg (interp, "Error: no -to object specified");

    if ((regfile_name != NULL ? 1 : 0) + (entry_name != NULL ? 1 : 0) + (reg_name != NULL ? 1 : 0) != 1) {
        return tcl_error_msg (interp, "Need exactly one flag of {-regfile -entry -reg}");
    }

    ig_tclc_check_name_and_warn (regfile_name);
    ig_tclc_check_name_and_warn (entry_name);
    ig_tclc_check_name_and_warn (reg_name);

    struct ig_object *to_obj = PTR_TO_IG_OBJECT (g_hash_table_lookup (db->objects_by_id, to_id));
    if ((to_obj == NULL)
        || ((regfile_name != NULL) && ((to_obj->type != IG_OBJ_MODULE) || (IG_MODULE (to_obj)->resource)))
        || ((entry_name != NULL) && (to_obj->type != IG_OBJ_REGFILE))
        || ((reg_name != NULL) && (to_obj->type != IG_OBJ_REGFILE_ENTRY))) {
        return tcl_error_msg (interp, "Error: invalid -to object (%s) specified", to_id);
    }

    const char *result_str = "";
    if (regfile_name != NULL) {
        struct ig_rf_regfile *regfile = ig_lib_add_regfile (db, regfile_name, IG_MODULE (to_obj));
        if (regfile == NULL) return tcl_error_msg (interp, "Unable to create regfile \"%s\"", regfile_name);

        result_str = IG_OBJECT (regfile)->id;
    } else if (entry_name != NULL) {
        struct ig_rf_entry *entry = ig_lib_add_regfile_entry (db, entry_name, IG_RF_REGFILE (to_obj));
        if (entry == NULL) return tcl_error_msg (interp, "Unable to create entry \"%s\" in regfile \"%s\"",  entry_name, regfile_name);
        result_str = IG_OBJECT (entry)->id;
    } else {
        struct ig_rf_reg *reg = ig_lib_add_regfile_reg (db, reg_name, IG_RF_ENTRY (to_obj));
        if (reg == NULL) return tcl_error_msg (interp, "Unable to create register \"%s\" in regfile \"%s\"",  reg_name, regfile_name);
        result_str = IG_OBJECT (reg)->id;
    }

    Tcl_SetObjResult (interp, Tcl_NewStringObj (result_str, -1));

    return TCL_OK;
}

/* TCLDOC
##
# @brief Set values of object-attributes.
#
# @param args Parsed command arguments:<br>
# -object \<object-id\><br>
# ( -attribute \<attribute-name\><br>
#   -value \<attribute-value\><br>
# | -attributes {\<name1\> \<value1\> \<name2\> \<value2\> ...})
#
*/
static int ig_tclc_set_attribute (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    char  *obj_name   = NULL;
    char  *attr_name  = NULL;
    char  *attr_value = NULL;
    GList *attr_list  = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-object",      NULL, (void *)&obj_name,   "object id", NULL},
        {TCL_ARGV_STRING,   "-attribute",   NULL, (void *)&attr_name,  "attribute name", NULL},
        {TCL_ARGV_STRING,   "-value",       NULL, (void *)&attr_value, "attribute value", NULL},

        {TCL_ARGV_FUNC,     "-attributes",  (void *)(Tcl_ArgvFuncProc *)ig_tclc_tcl_string_list_parse, (void *)&attr_list, "attributes as list of form <name1> <value1> <name2> <value2> ...", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (obj_name == NULL) {
        g_list_free (attr_list);
        return tcl_error_msg (interp, "No object specified");
    }
    if ((attr_list == NULL) && (attr_name == NULL)) return tcl_error_msg (interp, "No attribute specified");
    if ((attr_list != NULL) && (attr_name != NULL)) {
        g_list_free (attr_list);
        return tcl_error_msg (interp, "Invalid to specify single attribute and attribute list");
    }

    if ((attr_name != NULL) && (attr_value == NULL)) {
        return tcl_error_msg (interp, "Single attribute without value");
    }

    struct ig_object *obj = PTR_TO_IG_OBJECT (g_hash_table_lookup (db->objects_by_id, obj_name));
    if (obj == NULL) {
        g_list_free (attr_list);
        return tcl_error_msg (interp, "Unknown object \"%s\"", obj_name);
    }

    if (attr_name != NULL) {
        if (!ig_obj_attr_set (obj, attr_name, attr_value, false)) {
            return tcl_error_msg (interp, "Unable to attribute \"%s\"(=\"%s\") for object \"%s\"", attr_name, attr_value, obj_name);
        }

        Tcl_SetObjResult (interp, Tcl_NewStringObj (attr_value, -1));
        return TCL_OK;
    }

    if (!ig_obj_attr_set_from_gslist (obj, attr_list)) {
        g_list_free (attr_list);
        return tcl_error_msg (interp, "Unable to attribute list for object \"%s\"", attr_list);
    }

    Tcl_SetObjResult (interp, Tcl_NewStringObj ("", -1));
    g_list_free (attr_list);
    return TCL_OK;
}

/* TCLDOC
##
# @brief Get values of object-attributes.
#
# @param args Parsed command arguments:<br>
# -object \<object-id\><br>
# ( -attribute \<attribute-name\><br>
# [ -default \<default-value\>]<br>
# | -attributes {\<name1\> \<name2\> ...})
#
# @return Value(s) of the specified attribute(s) or if not argument is given a list with alle attribute names and values
*/
static int ig_tclc_get_attribute (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    char  *obj_name        = NULL;
    char  *attr_name       = NULL;
    char  *defaultval      = NULL;
    GList *attr_list       = NULL;
    bool   print_attr_name = false;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-object",      NULL, (void *)&obj_name,    "object id", NULL},
        {TCL_ARGV_STRING,   "-attribute",   NULL, (void *)&attr_name,   "attribute name", NULL},
        {TCL_ARGV_STRING,   "-default",     NULL, (void *)&defaultval,  "default value for single attribute if attribute does not exist", NULL},

        {TCL_ARGV_FUNC,     "-attributes",  (void *)(Tcl_ArgvFuncProc *)ig_tclc_tcl_string_list_parse, (void *)&attr_list, "attributes as list of form <name1> <name2> ...", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (obj_name == NULL) {
        g_list_free (attr_list);
        return tcl_error_msg (interp, "No object specified");
    }

    if ((attr_list != NULL) && (attr_name != NULL)) {
        g_list_free (attr_list);
        return tcl_error_msg (interp, "Specifying single attribute and attribute list is not supported");
    }

    struct ig_object *obj = PTR_TO_IG_OBJECT (g_hash_table_lookup (db->objects_by_id, obj_name));
    if (obj == NULL) {
        g_list_free (attr_list);
        return tcl_error_msg (interp, "Unknown object \"%s\"", obj_name);
    }
    if ((attr_list == NULL) && (attr_name == NULL)) {
        print_attr_name = true;
        attr_list       = ig_obj_attr_get_keys (obj);
    }

    if (attr_name != NULL) {
        const char *val = ig_obj_attr_get (obj, attr_name);
        if (val == NULL) {
            if (defaultval != NULL) {
                val = defaultval;
            } else {
                return tcl_error_msg (interp, "Could not get attribute \"%s\" of object \"%s\"", attr_name, obj_name);
            }
        }

        Tcl_SetObjResult (interp, Tcl_NewStringObj (val, -1));
        return TCL_OK;
    }

    /* check */
    for (GList *li = attr_list; li != NULL; li = li->next) {
        char *attr = (char *)li->data;
        if (ig_obj_attr_get (obj, attr) == NULL) {
            g_list_free (attr_list);
            return tcl_error_msg (interp, "Could not get attribute \"%s\" of object \"%s\"", attr, obj_name);
        }
    }

    /* result list */
    Tcl_Obj *retval = Tcl_NewListObj (0, NULL);
    for (GList *li = attr_list; li != NULL; li = li->next) {
        char       *attr = (char *)li->data;
        const char *val  = ig_obj_attr_get (obj, attr);

        Tcl_Obj *val_obj = Tcl_NewStringObj (val, -1);
        if (print_attr_name) {
            Tcl_ListObjAppendElement (interp, retval, Tcl_NewStringObj (attr, -1));
        }
        Tcl_ListObjAppendElement (interp, retval, val_obj);
    }

    Tcl_SetObjResult (interp, retval);
    g_list_free (attr_list);

    return TCL_OK;
}

enum ig_tclc_get_objs_of_obj_version {
    IG_TOOOV_INVALID,
    IG_TOOOV_PINS,
    IG_TOOOV_PORTS,
    IG_TOOOV_DECLS,
    IG_TOOOV_ADJ,
    IG_TOOOV_PARAMS,
    IG_TOOOV_CODE,
    IG_TOOOV_MODULES,
    IG_TOOOV_INSTANCES,
    IG_TOOOV_REGFILES,
    IG_TOOOV_RF_ENTRIES,
    IG_TOOOV_RF_REGS,
};

static enum ig_tclc_get_objs_of_obj_version ig_tclc_get_objs_of_obj_version_from_cmd (const char *cmdname)
{
    while (true) {
        const char *cmdchomp = strstr (cmdname, "::");
        if (cmdchomp == NULL) break;
        cmdname = cmdchomp + 2;
    }
    enum ig_tclc_get_objs_of_obj_version version = IG_TOOOV_INVALID;
    if (strcmp (cmdname, "get_ports") == 0) {
        version = IG_TOOOV_PORTS;
    } else if (strcmp (cmdname, "get_declarations") == 0) {
        version = IG_TOOOV_DECLS;
    } else if (strcmp (cmdname, "get_parameters") == 0) {
        version = IG_TOOOV_PARAMS;
    } else if (strcmp (cmdname, "get_codesections") == 0) {
        version = IG_TOOOV_CODE;
    } else if (strcmp (cmdname, "get_pins") == 0) {
        version = IG_TOOOV_PINS;
    } else if (strcmp (cmdname, "get_adjustments") == 0) {
        version = IG_TOOOV_ADJ;
    } else if (strcmp (cmdname, "get_modules") == 0) {
        version = IG_TOOOV_MODULES;
    } else if (strcmp (cmdname, "get_instances") == 0) {
        version = IG_TOOOV_INSTANCES;
    } else if (strcmp (cmdname, "get_regfiles") == 0) {
        version = IG_TOOOV_REGFILES;
    } else if (strcmp (cmdname, "get_regfile_entries") == 0) {
        version = IG_TOOOV_RF_ENTRIES;
    } else if (strcmp (cmdname, "get_regfile_regs") == 0) {
        version = IG_TOOOV_RF_REGS;
    }

    return version;
}

/* TCLDOC
##
# @brief Return child object(s) of given parent.
#
# @param args Parsed command arguments:<br>
# (-name \<child-name\><br>
# |-all)<br>
# -of \<parent-object-id\>
#
# @return Object-ID(s) of child object(s) or an error
*/
static int ig_tclc_get_objs_of_obj (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    /* command version */
    const char                          *cmdname = Tcl_GetString (objv[0]);
    enum ig_tclc_get_objs_of_obj_version version = ig_tclc_get_objs_of_obj_version_from_cmd (cmdname);

    if (version == IG_TOOOV_INVALID) return tcl_error_msg (interp, "Internal Error - Invalid command version generated (%s:%d)", __FILE__, __LINE__);

    /* arg parsing */
    int int_true  = true;
    int int_false = false;

    int   all         = int_false;
    char *parent_name = NULL;
    char *child_name  = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_CONSTANT, "-all",    GINT_TO_POINTER (int_true), (void *)&all,         "return all objects", NULL},
        {TCL_ARGV_STRING,   "-name",   NULL,                       (void *)&child_name,  "object name",        NULL},
        {TCL_ARGV_STRING,   "-of",     NULL,                       (void *)&parent_name, "parent object",      NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    /* sanity checks */
    if (parent_name == NULL) {
        if ((version == IG_TOOOV_DECLS) || (version == IG_TOOOV_PORTS) || (version == IG_TOOOV_PARAMS) || (version == IG_TOOOV_CODE) || (version == IG_TOOOV_REGFILES)) {
            return tcl_error_msg (interp, "Flag -of <module> needs to be specified");
        } else if ((version == IG_TOOOV_PINS) || (version == IG_TOOOV_ADJ)) {
            return tcl_error_msg (interp, "Flag -of <instance> needs to be specified");
        } else if (version == IG_TOOOV_RF_ENTRIES) {
            return tcl_error_msg (interp, "Flag -of <regfile> needs to be specified");
        } else if (version == IG_TOOOV_RF_REGS) {
            return tcl_error_msg (interp, "Flag -of <regfile-entry> needs to be specified");
        }
    }

    if ((version == IG_TOOOV_CODE) && (child_name != NULL)) {
        return tcl_error_msg (interp, "Invalid to specify name and for code sections");
    }

    if (all && (child_name != NULL)) {
        return tcl_error_msg (interp, "Invalid to specify name and -all");
    }

    if (child_name == NULL) {
        all = true;
    }

    /* child list */
    GList *child_list      = NULL;
    bool   child_list_free = false;

    if ((version == IG_TOOOV_INSTANCES) && (parent_name == NULL)) {
        if (all) {
            child_list = g_hash_table_get_values (db->instances_by_id);
        } else {
            if (g_hash_table_contains (db->instances_by_name, child_name)) {
                child_list = g_list_prepend (child_list, g_hash_table_lookup (db->instances_by_name, child_name));
            }
        }
        child_list_free = true;
    } else if ((version == IG_TOOOV_MODULES) && (parent_name == NULL)) {
        if (all) {
            child_list = g_hash_table_get_values (db->modules_by_id);
        } else {
            if (g_hash_table_contains (db->modules_by_name, child_name)) {
                child_list = g_list_prepend (child_list, g_hash_table_lookup (db->modules_by_name, child_name));
            }
        }
        child_list_free = true;
    } else if ((version == IG_TOOOV_DECLS) || (version == IG_TOOOV_PORTS) || (version == IG_TOOOV_PARAMS)
               || (version == IG_TOOOV_CODE) || (version == IG_TOOOV_INSTANCES) || (version == IG_TOOOV_REGFILES)) {
        struct ig_module *mod = IG_MODULE (PTR_TO_IG_OBJECT (g_hash_table_lookup (db->modules_by_id, parent_name)));
        if (mod == NULL) {
            return tcl_error_msg (interp, "Unable to find \"%s\" in database", parent_name);
        }

        if (mod->resource) {
            if ((version == IG_TOOOV_DECLS) || (version == IG_TOOOV_CODE)
                || (version == IG_TOOOV_INSTANCES) || (version == IG_TOOOV_REGFILES)) {
                return tcl_error_msg (interp, "Command is not applicable to a resource (\"%s\")", parent_name);
            }
        }

        if (version == IG_TOOOV_DECLS) {
            child_list = mod->decls->head;
        } else if (version == IG_TOOOV_PORTS) {
            child_list = mod->ports->head;
        } else if (version == IG_TOOOV_PARAMS) {
            child_list = mod->params->head;
        } else if (version == IG_TOOOV_CODE) {
            child_list = mod->code->head;
        } else if (version == IG_TOOOV_INSTANCES) {
            child_list = mod->child_instances->head;
        } else if (version == IG_TOOOV_REGFILES) {
            child_list = mod->regfiles->head;
        }
    } else if ((version == IG_TOOOV_PINS) || (version == IG_TOOOV_ADJ) || (version == IG_TOOOV_MODULES)) {
        struct ig_instance *inst = IG_INSTANCE (PTR_TO_IG_OBJECT (g_hash_table_lookup (db->instances_by_id, parent_name)));
        if (inst == NULL) return tcl_error_msg (interp, "Unable to find instance-id \"%s\"", parent_name);

        if (version == IG_TOOOV_PINS) {
            child_list = inst->pins->head;
        } else if (version == IG_TOOOV_ADJ) {
            child_list = inst->adjustments->head;
        } else if (version == IG_TOOOV_MODULES) {
            child_list      = g_list_prepend (child_list, inst->module);
            child_list_free = true;
        }
    } else if (version == IG_TOOOV_RF_ENTRIES) {
        struct ig_object *obj = PTR_TO_IG_OBJECT (g_hash_table_lookup (db->objects_by_id, parent_name));

        if ((obj == NULL) || (obj->type != IG_OBJ_REGFILE)) {
            return tcl_error_msg (interp, "Unable to get regfile \"%s\" from database", parent_name);
        }

        struct ig_rf_regfile *regfile = IG_RF_REGFILE (obj);
        child_list = regfile->entries->head;
    } else if (version == IG_TOOOV_RF_REGS) {
        struct ig_object *obj = PTR_TO_IG_OBJECT (g_hash_table_lookup (db->objects_by_id, parent_name));

        if ((obj == NULL) || (obj->type != IG_OBJ_REGFILE_ENTRY)) {
            return tcl_error_msg (interp, "Unable to get regfile-entry \"%s\" from database", parent_name);
        }

        struct ig_rf_entry *entry = IG_RF_ENTRY (obj);
        child_list = entry->regs->head;
    }

    /* generate result */
    Tcl_Obj *retval = NULL;
    if (all) {
        retval = Tcl_NewListObj (0, NULL);
    }

    for (GList *li = child_list; li != NULL; li = li->next) {
        struct ig_object *i_obj  = NULL;
        const char       *i_name = NULL;

        if (version == IG_TOOOV_PINS) {
            struct ig_pin *pin = IG_PIN (li->data);
            i_name = pin->name;
            i_obj  = IG_OBJECT (pin);
        } else if (version == IG_TOOOV_ADJ) {
            struct ig_adjustment *adjustment = IG_ADJUSTMENT (li->data);
            i_name = adjustment->name;
            i_obj  = IG_OBJECT (adjustment);
        } else if (version == IG_TOOOV_PORTS) {
            struct ig_port *port = IG_PORT (li->data);
            i_name = port->name;
            i_obj  = IG_OBJECT (port);
        } else if (version == IG_TOOOV_PARAMS) {
            struct ig_param *param = IG_PARAM (li->data);
            i_name = param->name;
            i_obj  = IG_OBJECT (param);
        } else if (version == IG_TOOOV_DECLS) {
            struct ig_decl *decl = IG_DECL (li->data);
            i_name = decl->name;
            i_obj  = IG_OBJECT (decl);
        } else if (version == IG_TOOOV_CODE) {
            struct ig_code *code = IG_CODE (li->data);
            i_name = code->name;
            i_obj  = IG_OBJECT (code);
        } else if (version == IG_TOOOV_MODULES) {
            struct ig_module *module = IG_MODULE (li->data);
            i_name = module->name;
            i_obj  = IG_OBJECT (module);
        } else if (version == IG_TOOOV_INSTANCES) {
            struct ig_instance *instance = IG_INSTANCE (li->data);
            i_name = instance->name;
            i_obj  = IG_OBJECT (instance);
        } else if (version == IG_TOOOV_REGFILES) {
            struct ig_rf_regfile *rf_regfile = IG_RF_REGFILE (li->data);
            i_name = rf_regfile->name;
            i_obj  = IG_OBJECT (rf_regfile);
        } else if (version == IG_TOOOV_RF_ENTRIES) {
            struct ig_rf_entry *rf_entry = IG_RF_ENTRY (li->data);
            i_name = rf_entry->name;
            i_obj  = IG_OBJECT (rf_entry);
        } else if (version == IG_TOOOV_RF_REGS) {
            struct ig_rf_reg *rf_reg = IG_RF_REG (li->data);
            i_name = rf_reg->name;
            i_obj  = IG_OBJECT (rf_reg);
        }

        if (all) {
            Tcl_Obj *t_obj = Tcl_NewStringObj (i_obj->id, -1);
            Tcl_ListObjAppendElement (interp, retval, t_obj);
        } else {
            if (strcmp (i_name, child_name) == 0) {
                Tcl_SetObjResult (interp, Tcl_NewStringObj (i_obj->id, -1));
                if (child_list_free) g_list_free (child_list);
                return TCL_OK;
            }
        }
    }

    if (child_list_free) {
        g_list_free (child_list);
        child_list = NULL;
    }

    if (!all) {
        if (child_name != NULL) return tcl_error_msg (interp, "Nothing found for \"%s\"", child_name);
        if (parent_name != NULL) return tcl_error_msg (interp, "Nothing found for \"\%s\"", parent_name);
        return tcl_error_msg (interp, "Nothing found");
    } else {
        Tcl_SetObjResult (interp, retval);
    }

    return TCL_OK;
}

static void ig_tclc_connection_parse (const char *input, GString *id, GString *net, bool *adapt, bool *inv_ptr)
{
    if (input == NULL) return;
    if (id == NULL) return;
    if (net == NULL) return;
    if (adapt == NULL) return;

    bool inv = false;
    if ((strlen (input) >= 2) && (input[0] == '~')) {
        input++;
        inv = true;
    }
    if (inv_ptr != NULL) *inv_ptr = inv;

    log_debug ("TCnPr", "parsing connection info: %s", input);
    const char *split_net = strstr (input, ":");
    g_string_assign (id, input);
    if (split_net == NULL) {
        g_string_assign (net, "");
        *adapt = true;
        log_debug ("TCnPr", "got only object: %s", input);
        return;
    }

    g_string_truncate (id, (split_net - input));
    g_string_assign (net, split_net + 1);

    if (net->len == 0) {
        *adapt = true;
        log_debug ("TCnPr", "got only object: %s", input);
        return;
    }

    if (net->str[net->len - 1] == '!') {
        *adapt = true;
        g_string_truncate (net, net->len - 1);
        log_debug ("TCnPr", "got object + net + adapt: %s -> %s", id->str, net->str);
    } else {
        *adapt = false;
        log_debug ("TCnPr", "got object + net + force: %s -> %s", id->str, net->str);
    }

    /* checks */
    ig_tclc_check_name_and_warn (id->str);
    ig_tclc_check_name_and_warn (net->str);
}

static void ig_tclc_check_name_and_warn (const char *name)
{
    if (name == NULL) return;

    const char unwanted[] = {'"', '\'', '!', ':', '$', ' ', '{', '}', '[', ']', '<', '>', '(', ')', 0};
    for (const char *cp = &(unwanted[0]); *cp != 0; cp++) {
        if (strchr (name, *cp) != NULL) {
            log_warn ("TChkN", "Got identifier \"%s\" containing probably unwanted character \"%c\".", name, *cp);
        }
    }
}

/* TCLDOC
##
# @brief Create a signal connecting modules/instances.
#
# @param args Parsed command arguments:<br>
# -signal-name \<signal-name\><br>
# [-signal-size \<signal-bitwidth\>]<br>
# (-bidir {\<endpoint1\> \<endpoint2\> ...}<br>
# |-from \<startpoint\><br>
#  -to {\<endpoint1\> \<endpoint2\> ...})<br>
#
# @return List of objects being part of the newly created signal or an error
#
# Start-/Endpoints must be of the form "<Object-ID>[-><local name>[!]]"
# where \<Object-ID\> is a module or instance object and optionally
# \<local name\> specifies the name of the signal at the given object (=pin/port).
# The optional [!] adapts the local name suffix at the specified object,
# otherwise the name is kept verbatim.
#
*/
static int ig_tclc_connect (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    char  *from    = NULL;
    char  *name    = NULL;
    char  *size    = NULL;
    GList *to_list = NULL;
    GList *bd_list = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-signal-name", NULL,                                                      (void *)&name,    "signal (prefix) name", NULL},
        {TCL_ARGV_STRING,   "-signal-size", NULL,                                                      (void *)&size,    "signal (bus) size", NULL},
        {TCL_ARGV_STRING,   "-from",        NULL,                                                      (void *)&from,    "start of signal (unidirectional)", NULL},
        {TCL_ARGV_FUNC,     "-to",          (void *)(Tcl_ArgvFuncProc *)ig_tclc_tcl_string_list_parse, (void *)&to_list, "list of signal endpoints", NULL},
        {TCL_ARGV_FUNC,     "-bidir",       (void *)(Tcl_ArgvFuncProc *)ig_tclc_tcl_string_list_parse, (void *)&bd_list, "list of endpoints connected bidirectional", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) goto l_ig_tclc_connect_exit;

    if (name == NULL) {
        result = tcl_error_msg (interp, "Signal name is required");
    }
    if ((from == NULL) && (bd_list == NULL)) {
        result = tcl_error_msg (interp, "Signal \"%s\": -from is required for unidirectional signals", name);
    }
    if ((bd_list != NULL) && ((from != NULL) || (to_list != NULL))) {
        result = tcl_error_msg (interp, "Signal \"%s\": combining bidirectional and unidirectional is invalid.", name);
    }
    if (size == NULL) {
        size = "1";
    }

    if (result != TCL_OK) goto l_ig_tclc_connect_exit;

    log_debug ("TCCon", "generating connection info");

    struct ig_lib_connection_info *src      = NULL;
    GList                         *trg_list = NULL;
    GString                       *tstr_id  = g_string_new (NULL);
    GString                       *tstr_net = g_string_new (NULL);
    bool                           t_adapt  = false;

    if (from != NULL) {
        bool inv = false;
        ig_tclc_connection_parse (from, tstr_id, tstr_net, &t_adapt, &inv);
        struct ig_object *src_obj = PTR_TO_IG_OBJECT (g_hash_table_lookup (db->objects_by_id, tstr_id->str));
        if (src_obj == NULL) {
            log_error ("TCCon", "Signal \"%s\": could not find object for id \"%s\"", name, tstr_id->str);
            goto l_ig_tclc_connect_nfexit;
        }

        if (tstr_net->len > 0) {
            src             = ig_lib_connection_info_new (db->str_chunks, src_obj, tstr_net->str, IG_LCDIR_UP);
            src->force_name = !t_adapt;
        } else {
            src = ig_lib_connection_info_new (db->str_chunks, src_obj, NULL, IG_LCDIR_UP);
        }
        src->invert = inv;
    }

    GList                     *trg_orig_list = to_list;
    enum ig_lib_connection_dir trg_dir       = IG_LCDIR_DEFAULT;
    if (trg_orig_list == NULL) {
        trg_orig_list = bd_list;
        trg_dir       = IG_LCDIR_BIDIR;
    }

    for (GList *li = trg_orig_list; li != NULL; li = li->next) {
        bool inv = false;
        ig_tclc_connection_parse ((const char *)li->data, tstr_id, tstr_net, &t_adapt, &inv);
        struct ig_object *trg_obj = PTR_TO_IG_OBJECT (g_hash_table_lookup (db->objects_by_id, tstr_id->str));
        if (trg_obj == NULL) {
            log_error ("TCCon", "Signal \"%s\": could not find object for id \"%s\"", name, tstr_id->str);
            goto l_ig_tclc_connect_nfexit;
        }

        struct ig_lib_connection_info *trg = NULL;
        if (tstr_net->len > 0) {
            trg             = ig_lib_connection_info_new (db->str_chunks, trg_obj, tstr_net->str, trg_dir);
            trg->force_name = !t_adapt;
        } else {
            trg = ig_lib_connection_info_new (db->str_chunks, trg_obj, NULL, trg_dir);
        }
        trg->invert = inv;
        trg_list    = g_list_prepend (trg_list, trg);
    }
    trg_list = g_list_reverse (trg_list);

    log_debug ("TCCon", "starting connection...");
    GList *gen_objs = NULL;

    if (!ig_lib_connection (db, name, src, trg_list, &gen_objs)) {
        g_list_free (gen_objs);
        result = tcl_error_msg (interp, "Signal \"%s\", error while trying to create connection", name);
    }
    log_debug ("TCCon", "... finished connection");

    Tcl_Obj *retval = Tcl_NewListObj (0, NULL);
    for (GList *li = gen_objs; li != NULL; li = li->next) {
        struct ig_object *i_obj = PTR_TO_IG_OBJECT (li->data);

        ig_obj_attr_set (i_obj, "size", size, true);

        Tcl_Obj *t_obj = Tcl_NewStringObj (i_obj->id, -1);
        Tcl_ListObjAppendElement (interp, retval, t_obj);
    }

    log_debug ("TCCon", "freeing results...");

    Tcl_SetObjResult (interp, retval);
    g_list_free (gen_objs);

l_ig_tclc_connect_exit_pre:
    g_string_free (tstr_id, true);
    g_string_free (tstr_net, true);

l_ig_tclc_connect_exit:
    g_list_free (to_list);
    g_list_free (bd_list);

    log_debug ("TCCon", "... freed results");

    return result;

l_ig_tclc_connect_nfexit:
    if (src != NULL) {
        ig_lib_connection_info_free (src);
    }
    for (GList *li = trg_list; li != NULL; li = li->next) {
        struct ig_lib_connection_info *trg = (struct ig_lib_connection_info *)li->data;
        ig_lib_connection_info_free (trg);
    }
    result = tcl_error_msg (interp, "Error: could not find object");
    goto l_ig_tclc_connect_exit_pre;
}

/* TCLDOC
##
# @brief Create a parameter for modules/instances.
#
# @param args Parsed command arguments:<br>
# -name \<parameter-name\><br>
# -value \<parameter-value\><br>
# -targets {\<endpoint1\> \<endpoint2\> ...}
#
# @return List of objects being part of the newly created parameterization or an error
#
# Start-/Endpoints must be of the form "<Object-ID>[-><local name>]"
# where \<Object-ID\> is a module or instance object and optionally
# \<local name\> specifies the name of the parameter at the given object.
#
*/
static int ig_tclc_parameter (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    char  *name     = NULL;
    char  *value    = NULL;
    GList *ept_list = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-name",        NULL,                                                      (void *)&name,     "parameter name", NULL},
        {TCL_ARGV_STRING,   "-value",       NULL,                                                      (void *)&value,    "default value", NULL},
        {TCL_ARGV_FUNC,     "-targets",     (void *)(Tcl_ArgvFuncProc *)ig_tclc_tcl_string_list_parse, (void *)&ept_list, "list of endpoints for parameter", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) goto l_ig_tclc_parameter_exit;

    if (name == NULL) result = tcl_error_msg (interp, "No parameter name specified");
    ig_tclc_check_name_and_warn (name);
    if (value == NULL) result = tcl_error_msg (interp, "Parameter \"%s\": parameter needs a value", name);
    if (ept_list == NULL) result = tcl_error_msg (interp, "Parameter \"%s\": parameter needs a list of endpoints", name);

    if (result != TCL_OK) goto l_ig_tclc_parameter_exit;

    log_debug ("TCPar", "generating connection info");

    GList   *trg_list = NULL;
    GString *tstr_id  = g_string_new (NULL);
    GString *tstr_par = g_string_new (NULL);
    bool     t_adapt  = false;

    enum ig_lib_connection_dir trg_dir = IG_LCDIR_DEFAULT;

    for (GList *li = ept_list; li != NULL; li = li->next) {
        ig_tclc_connection_parse ((const char *)li->data, tstr_id, tstr_par, &t_adapt, NULL);
        struct ig_object *trg_obj = PTR_TO_IG_OBJECT (g_hash_table_lookup (db->objects_by_id, tstr_id->str));
        if (trg_obj == NULL) {
            result = tcl_error_msg (interp, "Parameter \"%s\": could not find object for id \"%s\"", name, tstr_id->str);
            goto l_ig_tclc_parameter_nfexit;
        }

        struct ig_lib_connection_info *trg = NULL;
        if (tstr_par->len > 0) {
            trg             = ig_lib_connection_info_new (db->str_chunks, trg_obj, tstr_par->str, trg_dir);
            trg->force_name = !t_adapt;
        } else {
            trg = ig_lib_connection_info_new (db->str_chunks, trg_obj, NULL, trg_dir);
        }
        trg_list = g_list_prepend (trg_list, trg);
    }
    trg_list = g_list_reverse (trg_list);

    log_debug ("TCPar", "starting parametrization...");
    GList *gen_objs = NULL;

    if (!ig_lib_parameter (db, name, value, trg_list, &gen_objs)) {
        g_list_free (gen_objs);
        result = tcl_error_msg (interp, "Parameter \"%s\", error while trying to create parameter", name);
    }

    Tcl_Obj *retval = Tcl_NewListObj (0, NULL);
    for (GList *li = gen_objs; li != NULL; li = li->next) {
        struct ig_object *i_obj = PTR_TO_IG_OBJECT (li->data);

        Tcl_Obj *t_obj = Tcl_NewStringObj (i_obj->id, -1);
        Tcl_ListObjAppendElement (interp, retval, t_obj);
    }

    Tcl_SetObjResult (interp, retval);
    g_list_free (gen_objs);

l_ig_tclc_parameter_exit_pre:
    g_string_free (tstr_id, true);
    g_string_free (tstr_par, true);

l_ig_tclc_parameter_exit:
    g_list_free (ept_list);

    return result;

l_ig_tclc_parameter_nfexit:
    for (GList *li = trg_list; li != NULL; li = li->next) {
        struct ig_lib_connection_info *trg = (struct ig_lib_connection_info *)li->data;
        ig_lib_connection_info_free (trg);
    }
    goto l_ig_tclc_parameter_exit_pre;
}


/* TCLDOC
##
# @brief Create a pin for a instances.
#
# @param args Parsed command arguments:<br>
# -instname \<instance name\><br>
# -pinname \<pin name\><br>
# -value \<signalname/value assigned to the the pin\><br>
#
*/
static int ig_tclc_create_pin (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    char *instname = NULL;
    char *pinname  = NULL;
    char *value    = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING, "-instname", NULL, (void *)&instname,  "instance name", NULL},
        {TCL_ARGV_STRING, "-pinname",  NULL, (void *)&pinname,   "pin name", NULL},
        {TCL_ARGV_STRING, "-value",    NULL, (void *)&value,     "signalname/value assigned to the pin", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) {
        return result;
    }

    if (instname == NULL) {
        result = tcl_error_msg (interp, "No instance name specified");
    }
    if (pinname == NULL) {
        result = tcl_error_msg (interp, "No pin name specified");
    }

    struct ig_instance *inst = IG_INSTANCE (PTR_TO_IG_OBJECT (g_hash_table_lookup (db->instances_by_name, instname)));
    if (inst == NULL) {
        return tcl_error_msg (interp, "Could not found instance \"%s\"\n", instname);
    }
    if (!inst->module->resource) {
        return tcl_error_msg (interp, "Unable to add pin - instance \"%s\" is not a resource.", instname);
    }
    ig_lib_add_pin (db, inst, pinname, value, "false");

    return TCL_OK;
}
/* TCLDOC
##
# @brief Clear database of all objects.
#
# This removes everything from the database.
# Can be useful to create multiple individual hierarchy sets with overlapping definitions one after another.
#
*/
static int ig_tclc_reset (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) return tcl_error_msg (interp,  "Database is NULL");

    ig_lib_db_clear (db);

    return TCL_OK;
}

/* TCLDOC
##
# @brief Control log message verbosity.
#
# @param args <b> [OPTION]</b><br>
#    <table style="border:0px; border-spacing:40px 0px;">
#      <tr><td><b> OPTION </b></td><td><br></td></tr>
#      <tr><td><i> &ensp; &ensp; -level  </i></td><td>  specify the loglevel  <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -id  </i></td><td>  specify the logid  <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -list  </i></td><td>  list available loglevels  <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -linenumber</i></td><td>  add file/line number to log-output (debug)  <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -nolinenumber</i></td><td>  do not add file/line number to log-output  <br></td></tr>
#    </table>
#
*/
static int ig_tclc_logger (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    char    *loglevel   = NULL;
    char    *log_id     = NULL;
    gboolean list       = false;
    int      linenumber = 0;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-level",        NULL,                   (void *)&loglevel,   "log level",                                    NULL},
        {TCL_ARGV_STRING,   "-id",           NULL,                   (void *)&log_id,     "log id",                                       NULL},
        {TCL_ARGV_CONSTANT, "-list",         GINT_TO_POINTER (true), (void *)&list,       "list available loglevels",                     NULL},
        {TCL_ARGV_CONSTANT, "-linenumber",   GINT_TO_POINTER (1),    (void *)&linenumber, "add file/line numbers to log-output",          NULL},
        {TCL_ARGV_CONSTANT, "-nolinenumber", GINT_TO_POINTER (-1),   (void *)&linenumber, "do not print file/line numbers in log-output", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);

    if (result != TCL_OK) {
        return result;
    }

    if (list) {
        char *msg = g_strdup_printf ("The following loglevels are available:\n");
        for (int i = 0; i < LOGLEVEL_COUNT; i++) {
            char *tmp = g_strdup_printf ("%s\t- %s\n", msg, loglevel_label[i]);
            g_free (msg);
            msg = tmp;
        }
        Tcl_SetObjResult (interp, Tcl_NewStringObj ((char *)msg, -1));
        g_free (msg);
        return TCL_OK;
    }

    if (linenumber) {
        set_loglinenumbers ((linenumber > 0) ? true : false);
    }
    if (loglevel == NULL && log_id == NULL) {
        // print current settings
        log_dump_settings ();
        return TCL_OK;
    } else if (loglevel != NULL) {
        gboolean found_level = false;
        int      i           = 0;
        for (i = 0; i < LOGLEVEL_COUNT; i++) {
            if (g_strcmp0 (loglevel, loglevel_label[i]) == 0) {
                found_level = true;
                break;
            }
        }
        if (found_level) {
            if (log_id != NULL) {
                // set particular log level:
                log_particular_level (log_id, i);
                char *msg = g_strdup_printf ("Set logID %s loglevel to %s", log_id, loglevel);
                Tcl_SetObjResult (interp, Tcl_NewStringObj ((char *)msg, -1));
                g_free (msg);
            } else {
                // set default log level:
                char *msg = g_strdup_printf ("Set default loglevel to %s", loglevel);
                Tcl_SetObjResult (interp, Tcl_NewStringObj ((char *)msg, -1));
                set_default_log_level (i);
                g_free (msg);
            }
        } else {
            // level does not exists:
            return tcl_error_msg (interp, "Loglevel %s does not exist - try `-help` for a list of available loglevels", loglevel);
        }
    }

    return TCL_OK;
}

/* TCLDOC
##
# @brief Control log message verbosity.
#
# @param args <b> [OPTION] LOGMESSAGE</b><br>
#    <table style="border:0px; border-spacing:40px 0px;">
#      <tr><td><b> LOGMESSAGE </b></td><td> specify the logmessage to be printed </td></tr>
#      <tr><td><b> OPTION </b></td><td><br></td></tr>
#      <tr><td><i> &ensp; &ensp; -id      </i></td><td>  specify the logid                 <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -debug   </i></td><td>  specify debug as max. loglevel    <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -info    </i></td><td>  specify info as max. loglevel     <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -warning </i></td><td>  specify warning as max. loglevel  <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -error   </i></td><td>  specify error as max. loglevel    <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -abort   </i></td><td>  throw TCL_ERROR                   <br></td></tr>
#    </table>
#
*/
static int ig_tclc_log (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    char *log_id   = "Tcl";
    gint  loglevel = LOGLEVEL_INFO;
    gint  abort    = 0;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-id",      NULL,                               (void *)&log_id,       "log id",                              NULL},
        {TCL_ARGV_CONSTANT, "-debug",   GINT_TO_POINTER (LOGLEVEL_DEBUG),   (void *)&loglevel,     "loglevel debug",                      NULL},
        {TCL_ARGV_CONSTANT, "-info",    GINT_TO_POINTER (LOGLEVEL_INFO),    (void *)&loglevel,     "loglevel info",                       NULL},
        {TCL_ARGV_CONSTANT, "-warning", GINT_TO_POINTER (LOGLEVEL_WARNING), (void *)&loglevel,     "loglevel warning",                    NULL},
        {TCL_ARGV_CONSTANT, "-error",   GINT_TO_POINTER (LOGLEVEL_ERROR),   (void *)&loglevel,     "loglevel error",                      NULL},
        {TCL_ARGV_CONSTANT, "-abort",   GINT_TO_POINTER (1),                (void *)&abort,        "return the log message as tcl error", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    Tcl_Obj **remObjv = NULL;
    int       result  = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, &remObjv);

    if (result != TCL_OK) {
        if (objc != 0) ckfree (remObjv);
        return result;
    }

    char *msg = "";
    if (objc > 0) {
        for (int i = 1; i < objc; i++) {
            msg = Tcl_GetString (remObjv[i]);
            char *file       = "TCL-Unknown";
            char *cmd        = NULL;
            int   linenumber = 0;

            if (!log_suppress (loglevel, log_id)) {
                if (Tcl_Eval (interp, "info frame -1") == TCL_OK) {
                    Tcl_Obj *dict_info_frame = Tcl_GetObjResult (interp);

                    if (!tcl_dict_get_str (interp, dict_info_frame, "file", &file)) {
                        if (tcl_dict_get_str (interp, dict_info_frame, "cmd", &cmd)) {
                            cmd  = g_strdup_printf ("TCL-CMD(%s)", cmd);
                            file = cmd;
                        } else if (tcl_dict_get_str (interp, dict_info_frame, "proc", &cmd)) {
                            cmd  = g_strdup_printf ("TCL-PROC(%s)", cmd);
                            file = cmd;
                        }
                    }

                    if (get_loglinenumbers ()) {
                        tcl_dict_get_int (interp, dict_info_frame, "line", &linenumber);
                    }
                }
            }

            log_base (loglevel, log_id, basename (file), linenumber, "%s", msg);
            g_free (cmd);
        }
    }

    if (abort) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj (msg, -1));
    }

    if (objc != 0) ckfree (remObjv);

    if (abort) return TCL_ERROR;
    return TCL_OK;
}

/* TCLDOC
##
# @brief Control log message verbosity.
#
# @param args <b> [OPTION]</b><br>
#    <table style="border:0px; border-spacing:40px 0px;">
#      <tr><td><b> OPTION </b></td><td><br></td></tr>
#      <tr><td><i> &ensp; &ensp; -level  </i></td><td>  specify the loglevel  <br></td></tr>
#      <tr><td><i> &ensp; &ensp; -suppress  </i></td><td>  get number of suppressed log messages  <br></td></tr>
#    </table>
#
*/
static int ig_tclc_log_stat (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    char *loglevel = NULL;
    gint  suppress = 0;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-level",    NULL,                (void *)&loglevel, "log level",                                    NULL},
        {TCL_ARGV_CONSTANT, "-suppress", GINT_TO_POINTER (1), (void *)&suppress, "return the log message as tcl error", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);

    if (result != TCL_OK) {
        return result;
    }

    Tcl_Obj *retval = NULL;
    if (loglevel == NULL) {
        retval = Tcl_NewListObj (0, NULL);
        for (int i = 0; i < LOGLEVEL_COUNT; i++) {
            Tcl_ListObjAppendElement (interp, retval, Tcl_NewStringObj (loglevel_label[i], -1));
            Tcl_Obj *log_count = Tcl_NewIntObj (suppress ? get_log_count_suppressed (i) : get_log_count_print (i));
            Tcl_ListObjAppendElement (interp, retval, log_count);
        }
    } else if (loglevel != NULL) {
        gboolean found_level = false;
        int      i           = 0;
        for (i = 0; i < LOGLEVEL_COUNT; i++) {
            if (g_strcmp0 (loglevel, loglevel_label[i]) == 0) {
                found_level = true;
                break;
            }
        }
        if (found_level) {
            retval = Tcl_NewIntObj (suppress ? get_log_count_suppressed (i) : get_log_count_print (i));
        } else {
            // level does not exists:
            return tcl_error_msg (interp, "Loglevel %s does not exist - try `-help` for a list of available loglevels", loglevel);
        }
    }

    Tcl_SetObjResult (interp, retval);
    return TCL_OK;
}

/* TCLDOC
##
# @brief print the icglue logo
#
*/
static int ig_tclc_print_logo (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    ig_print_logo (stderr);
    return TCL_OK;
}
static int tcl_error_msg (Tcl_Interp *interp, const char *format, ...)
{
    int     result;
    va_list args;

    va_start (args, format);
    result = tcl_verror_msg (interp, format, args);
    va_end (args);
    return result;
}

static int tcl_verror_msg (Tcl_Interp *interp, const char *format, va_list args)
{
    const char *scriptFile = NULL;

    if (Tcl_Eval (interp, "lindex [dict get [info frame -1] cmd] 0") == TCL_OK) {
        scriptFile = Tcl_GetString (Tcl_GetObjResult (interp));
    }
    char *user_msg  = g_strdup_vprintf (format, args);
    char *error_msg = g_strdup_printf ("ERROR(%s): %s", scriptFile, user_msg);
    Tcl_SetObjResult (interp, Tcl_NewStringObj (error_msg, -1));
    g_free (user_msg);
    g_free (error_msg);
    return TCL_ERROR;
}

static int tcl_dict_get_str (Tcl_Interp *interp, Tcl_Obj *tcl_dict, char *key, char **value)
{
    Tcl_Obj *tcl_dict_key   = Tcl_NewStringObj (key, -1);
    Tcl_Obj *tcl_dict_value = NULL;
    int      retval         = 0;

    Tcl_IncrRefCount (tcl_dict_key);
    if ((Tcl_DictObjGet (interp, tcl_dict, tcl_dict_key, &tcl_dict_value) == TCL_OK) && (tcl_dict_value != NULL)) {
        *value = Tcl_GetString (tcl_dict_value);
        retval = 1;
    }
    Tcl_DecrRefCount (tcl_dict_key);
    return retval;
}

static int tcl_dict_get_int (Tcl_Interp *interp, Tcl_Obj *tcl_dict, char *key, int *value)
{
    Tcl_Obj *tcl_dict_key   = Tcl_NewStringObj (key, -1);
    Tcl_Obj *tcl_dict_value = NULL;
    int      retval         = 0;

    Tcl_IncrRefCount (tcl_dict_key);
    if ((Tcl_DictObjGet (interp, tcl_dict, tcl_dict_key, &tcl_dict_value) == TCL_OK) && (tcl_dict_value != NULL)) {
        retval = Tcl_GetIntFromObj (interp, tcl_dict_value, value);
    }
    Tcl_DecrRefCount (tcl_dict_key);
    return retval;
}

