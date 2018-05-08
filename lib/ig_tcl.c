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
#include "ig_data_helpers.h"
#include "ig_lib.h"
#include "ig_tcl.h"
#include "logger.h"

#include <string.h>

#ifndef ICGLUE_LIB_NAMESPACE
#define ICGLUE_LIB_NAMESPACE "ig::db::"
#endif
#ifndef ICGLUE_LOG_NAMESPACE
#define ICGLUE_LOG_NAMESPACE "ig::"
#endif

/* Tcl helper function for parsing lists in GSLists of char * */
static int ig_tclc_tcl_string_list_parse (ClientData client_data, Tcl_Obj *obj, void *dest_ptr);

static void ig_tclc_connection_parse (const char *input, GString *id, GString *net, bool *adapt);

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
static int ig_tclc_logger           (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_log              (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);

void ig_add_tcl_commands (Tcl_Interp *interp)
{
    if (interp == NULL) return;

    struct ig_lib_db *lib_db = ig_lib_db_new ();

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

    Tcl_CreateObjCommand (interp, ICGLUE_LOG_NAMESPACE "logger",              ig_tclc_logger,          lib_db, NULL);
    Tcl_CreateObjCommand (interp, ICGLUE_LOG_NAMESPACE "log",                 ig_tclc_log,             lib_db, NULL);
}

/* Tcl helper function for parsing lists in GSLists */
static int ig_tclc_tcl_string_list_parse (ClientData client_data, Tcl_Obj *obj, void *dest_ptr)
{
    GSList **list_dest = (GSList **)dest_ptr;

    if (dest_ptr == NULL) {
        return 1;
    }

    GSList *result = NULL;

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
            g_slist_free (result);
            return -1;
        }
        if (lit == NULL) {
            g_slist_free (result);
            return -1;
        }
        char *lit_str = Tcl_GetString (lit);

        result = g_slist_prepend (result, lit_str);
    }

    *list_dest = g_slist_reverse (result);
    return 1;
}


/* TCLDOC
##
# @brief Create a new module.
#
# \param[in] args parsed command arguments:<br>
# -name <module-name><br>
# [ (-ilm | -no-ilm) ]<br>
# [ -resource | -no-resource ]
# \return Object-ID of the newly created module or an error
 */
static int ig_tclc_create_module (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

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
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no name specified", -1));
        return TCL_ERROR;
    }

    struct ig_module *module = ig_lib_add_module (db, name, ilm, resource);

    if (module == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not create module", -1));
        return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, Tcl_NewStringObj (module->object->id, -1));

    return TCL_OK;
}

static int ig_tclc_create_instance (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

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

    if (name == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no name specified", -1));
        return TCL_ERROR;
    }
    if (of_module == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no module specified", -1));
        return TCL_ERROR;
    }
    if (parent_module == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no parent module specified", -1));
        return TCL_ERROR;
    }

    struct ig_module *of_mod = (struct ig_module *)g_hash_table_lookup (db->modules_by_id,   of_module);
    if (of_mod == NULL) of_mod = (struct ig_module *)g_hash_table_lookup (db->modules_by_name, of_module);
    struct ig_module *pa_mod = (struct ig_module *)g_hash_table_lookup (db->modules_by_id,   parent_module);
    if (pa_mod == NULL) pa_mod = (struct ig_module *)g_hash_table_lookup (db->modules_by_name, parent_module);

    if (of_module == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid of-module", -1));
        return TCL_ERROR;
    }
    if (parent_module == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid parent module", -1));
        return TCL_ERROR;
    }

    struct ig_instance *inst = ig_lib_add_instance (db, name, of_mod, pa_mod);

    if (inst == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not create instance", -1));
        return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, Tcl_NewStringObj (inst->object->id, -1));

    return TCL_OK;
}

static int ig_tclc_add_codesection (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

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

    if (code == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no code specified", -1));
        return TCL_ERROR;
    }
    if (parent_module == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no parent module specified", -1));
        return TCL_ERROR;
    }

    struct ig_module *pa_mod = (struct ig_module *)g_hash_table_lookup (db->modules_by_id,   parent_module);
    if (pa_mod == NULL) pa_mod = (struct ig_module *)g_hash_table_lookup (db->modules_by_name, parent_module);

    if (pa_mod == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid parent module", -1));
        return TCL_ERROR;
    }
    struct ig_code *cs = ig_lib_add_codesection (db, name, code, pa_mod);

    if (cs == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not create codesection", -1));
        return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, Tcl_NewStringObj (cs->object->id, -1));

    return TCL_OK;
}

static int ig_tclc_add_regfile (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

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

    if (to_id == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no -to object specified", -1));
        return TCL_ERROR;
    }

    if ((regfile_name != NULL ? 1 : 0) + (entry_name != NULL ? 1 : 0) + (reg_name != NULL ? 1 : 0) != 1) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: need exactly one of -regfile, -entry, -reg", -1));
        return TCL_ERROR;
    }

    struct ig_object *to_obj = (struct ig_object *)g_hash_table_lookup (db->objects_by_id, to_id);
    if ((to_obj == NULL)
        || ((regfile_name != NULL) && ((to_obj->type != IG_OBJ_MODULE) || (((struct ig_module *)to_obj->obj)->resource)))
        || ((entry_name != NULL) && (to_obj->type != IG_OBJ_REGFILE))
        || ((reg_name != NULL) && (to_obj->type != IG_OBJ_REGFILE_ENTRY))) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid -to object specified", -1));
        return TCL_ERROR;
    }

    const char *result_str = "";
    if (regfile_name != NULL) {
        struct ig_rf_regfile *regfile = ig_lib_add_regfile (db, regfile_name, (struct ig_module *)to_obj->obj);
        if (regfile == NULL) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not create regfile", -1));
            return TCL_ERROR;
        }
        result_str = regfile->object->id;
    } else if (entry_name != NULL) {
        struct ig_rf_entry *entry = ig_lib_add_regfile_entry (db, entry_name, (struct ig_rf_regfile *)to_obj->obj);
        if (entry == NULL) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not create entry", -1));
            return TCL_ERROR;
        }
        result_str = entry->object->id;
    } else {
        struct ig_rf_reg *reg = ig_lib_add_regfile_reg (db, reg_name, (struct ig_rf_entry *)to_obj->obj);
        if (reg == NULL) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not create reg", -1));
            return TCL_ERROR;
        }
        result_str = reg->object->id;
    }

    Tcl_SetObjResult (interp, Tcl_NewStringObj (result_str, -1));

    return TCL_OK;
}

static int ig_tclc_set_attribute (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    char   *obj_name   = NULL;
    char   *attr_name  = NULL;
    char   *attr_value = NULL;
    GSList *attr_list  = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-object",      NULL, (void *)&obj_name,   "object id", NULL},
        {TCL_ARGV_STRING,   "-attribute",   NULL, (void *)&attr_name,  "attribute name", NULL},
        {TCL_ARGV_STRING,   "-value",       NULL, (void *)&attr_value, "attribute value", NULL},

        {TCL_ARGV_FUNC,     "-attributes",  (void *)(Tcl_ArgvFuncProc *)ig_tclc_tcl_string_list_parse, (void *)&attr_list, "attributes as list of form <name> <value> <name2> <value2> ...", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (obj_name == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no object specified", -1));
        g_slist_free (attr_list);
        return TCL_ERROR;
    }

    if ((attr_list == NULL) && (attr_name == NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no attribute specified", -1));
        return TCL_ERROR;
    }

    if ((attr_list != NULL) && (attr_name != NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid to specify single attribute and attribute list", -1));
        g_slist_free (attr_list);
        return TCL_ERROR;
    }

    if ((attr_name != NULL) && (attr_value == NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: single attribute without value", -1));
        return TCL_ERROR;
    }

    struct ig_object *obj = (struct ig_object *)g_hash_table_lookup (db->objects_by_id, obj_name);
    if (obj == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: unknown object", -1));
        g_slist_free (attr_list);
        return TCL_ERROR;
    }

    if (attr_name != NULL) {
        if (!ig_obj_attr_set (obj, attr_name, attr_value, false)) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not set attribute", -1));
            return TCL_ERROR;
        }

        Tcl_SetObjResult (interp, Tcl_NewStringObj (attr_value, -1));
        return TCL_OK;
    }

    if (!ig_obj_attr_set_from_gslist (obj, attr_list)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not set attributes", -1));
        g_slist_free (attr_list);
        return TCL_ERROR;
    }

    Tcl_SetObjResult (interp, Tcl_NewStringObj ("", -1));
    g_slist_free (attr_list);
    return TCL_OK;
}

static int ig_tclc_get_attribute (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    char   *obj_name   = NULL;
    char   *attr_name  = NULL;
    char   *defaultval = NULL;
    GSList *attr_list  = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-object",      NULL, (void *)&obj_name,   "object id", NULL},
        {TCL_ARGV_STRING,   "-attribute",   NULL, (void *)&attr_name,  "attribute name", NULL},
        {TCL_ARGV_STRING,   "-default",     NULL, (void *)&defaultval, "default value for single attribute if attribute does not exist", NULL},

        {TCL_ARGV_FUNC,     "-attributes",  (void *)(Tcl_ArgvFuncProc *)ig_tclc_tcl_string_list_parse, (void *)&attr_list, "attributes as list of form <name> <value> <name2> <value2> ...", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (obj_name == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no object specified", -1));
        g_slist_free (attr_list);
        return TCL_ERROR;
    }

    if ((attr_list == NULL) && (attr_name == NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no attribute specified", -1));
        return TCL_ERROR;
    }

    if ((attr_list != NULL) && (attr_name != NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid to specify single attribute and attribute list", -1));
        g_slist_free (attr_list);
        return TCL_ERROR;
    }

    struct ig_object *obj = (struct ig_object *)g_hash_table_lookup (db->objects_by_id, obj_name);
    if (obj == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: unknown object", -1));
        g_slist_free (attr_list);
        return TCL_ERROR;
    }

    if (attr_name != NULL) {
        const char *val = ig_obj_attr_get (obj, attr_name);
        if (val == NULL) {
            if (defaultval != NULL) {
                val = defaultval;
            } else {
                Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not get attribute", -1));
                return TCL_ERROR;
            }
        }

        Tcl_SetObjResult (interp, Tcl_NewStringObj (val, -1));
        return TCL_OK;
    }

    /* check */
    for (GSList *li = attr_list; li != NULL; li = li->next) {
        char *attr = (char *)li->data;
        if (ig_obj_attr_get (obj, attr) == NULL) {
            g_slist_free (attr_list);
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not get attribute", -1));
            return TCL_ERROR;
        }
    }

    /* result list */
    Tcl_Obj *retval = Tcl_NewListObj (0, NULL);
    for (GSList *li = attr_list; li != NULL; li = li->next) {
        char       *attr = (char *)li->data;
        const char *val  = ig_obj_attr_get (obj, attr);

        Tcl_Obj *val_obj = Tcl_NewStringObj (val, -1);
        Tcl_ListObjAppendElement (interp, retval, val_obj);
    }

    Tcl_SetObjResult (interp, retval);
    g_slist_free (attr_list);

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

static int ig_tclc_get_objs_of_obj (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    /* command version */
    const char                          *cmdname = Tcl_GetString (objv[0]);
    enum ig_tclc_get_objs_of_obj_version version = ig_tclc_get_objs_of_obj_version_from_cmd (cmdname);

    if (version == IG_TOOOV_INVALID) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: Invalid command version generated", -1));
        return TCL_ERROR;
    }

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
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: -of <module> needs to be specified", -1));
            return TCL_ERROR;
        } else if ((version == IG_TOOOV_PINS) || (version == IG_TOOOV_ADJ)) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: -of <instance> needs to be specified", -1));
            return TCL_ERROR;
        } else if (version == IG_TOOOV_RF_ENTRIES) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: -of <regfile> needs to be specified", -1));
            return TCL_ERROR;
        } else if (version == IG_TOOOV_RF_REGS) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: -of <regfile-entry> needs to be specified", -1));
            return TCL_ERROR;
        }
    }

    if ((version == IG_TOOOV_CODE) && (child_name != NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid to specify name and for code sections", -1));
        return TCL_ERROR;
    }

    if (all && (child_name != NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid to specify name and -all", -1));
        return TCL_ERROR;
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
        struct ig_module *mod = (struct ig_module *)g_hash_table_lookup (db->modules_by_id, parent_name);
        if (mod == NULL) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid -of <module>", -1));
            return TCL_ERROR;
        }

        if (mod->resource) {
            if ((version == IG_TOOOV_DECLS) || (version == IG_TOOOV_CODE)
                || (version == IG_TOOOV_INSTANCES) || (version == IG_TOOOV_REGFILES)) {

                log_debug ("LTGet", "%s: -of <module> is resource", cmdname);
                Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid -of <module>", -1));
                return TCL_ERROR;
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
        struct ig_instance *inst = (struct ig_instance *)g_hash_table_lookup (db->instances_by_id, parent_name);
        if (inst == NULL) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid -of <instance>", -1));
            return TCL_ERROR;
        }

        if (version == IG_TOOOV_PINS) {
            child_list = inst->pins->head;
        } else if (version == IG_TOOOV_ADJ) {
            child_list = inst->adjustments->head;
        } else if (version == IG_TOOOV_MODULES) {
            child_list      = g_list_prepend (child_list, inst->module);
            child_list_free = true;
        }
    } else if (version == IG_TOOOV_RF_ENTRIES) {
        struct ig_object *obj = (struct ig_object *)g_hash_table_lookup (db->objects_by_id, parent_name);

        if ((obj == NULL) || (obj->type != IG_OBJ_REGFILE)) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid -of <regfile>", -1));
            return TCL_ERROR;
        }

        struct ig_rf_regfile *regfile = (struct ig_rf_regfile *)obj->obj;
        child_list = regfile->entries->head;
    } else if (version == IG_TOOOV_RF_REGS) {
        struct ig_object *obj = (struct ig_object *)g_hash_table_lookup (db->objects_by_id, parent_name);

        if ((obj == NULL) || (obj->type != IG_OBJ_REGFILE_ENTRY)) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid -of <regfile-entry>", -1));
            return TCL_ERROR;
        }

        struct ig_rf_entry *entry = (struct ig_rf_entry *)obj->obj;
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
            struct ig_pin *pin = (struct ig_pin *)li->data;
            i_name = pin->name;
            i_obj  = pin->object;
        } else if (version == IG_TOOOV_ADJ) {
            struct ig_adjustment *adjustment = (struct ig_adjustment *)li->data;
            i_name = adjustment->name;
            i_obj  = adjustment->object;
        } else if (version == IG_TOOOV_PORTS) {
            struct ig_port *port = (struct ig_port *)li->data;
            i_name = port->name;
            i_obj  = port->object;
        } else if (version == IG_TOOOV_PARAMS) {
            struct ig_param *param = (struct ig_param *)li->data;
            i_name = param->name;
            i_obj  = param->object;
        } else if (version == IG_TOOOV_DECLS) {
            struct ig_decl *decl = (struct ig_decl *)li->data;
            i_name = decl->name;
            i_obj  = decl->object;
        } else if (version == IG_TOOOV_CODE) {
            struct ig_code *code = (struct ig_code *)li->data;
            i_name = code->name;
            i_obj  = code->object;
        } else if (version == IG_TOOOV_MODULES) {
            struct ig_module *module = (struct ig_module *)li->data;
            i_name = module->name;
            i_obj  = module->object;
        } else if (version == IG_TOOOV_INSTANCES) {
            struct ig_instance *instance = (struct ig_instance *)li->data;
            i_name = instance->name;
            i_obj  = instance->object;
        } else if (version == IG_TOOOV_REGFILES) {
            struct ig_rf_regfile *rf_regfile = (struct ig_rf_regfile *)li->data;
            i_name = rf_regfile->name;
            i_obj  = rf_regfile->object;
        } else if (version == IG_TOOOV_RF_ENTRIES) {
            struct ig_rf_entry *rf_entry = (struct ig_rf_entry *)li->data;
            i_name = rf_entry->name;
            i_obj  = rf_entry->object;
        } else if (version == IG_TOOOV_RF_REGS) {
            struct ig_rf_reg *rf_reg = (struct ig_rf_reg *)li->data;
            i_name = rf_reg->name;
            i_obj  = rf_reg->object;
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
        if (child_name != NULL) {
            log_debug ("LTGet", "%s: nothing found for %s", cmdname, child_name);
        } else if (parent_name != NULL) {
            log_debug ("LTGet", "%s: nothing found for %s", cmdname, parent_name);
        } else {
            log_debug ("LTGet", "%s: nothing found", cmdname);
        }
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: nothing found", -1));
        return TCL_ERROR;
    } else {
        Tcl_SetObjResult (interp, retval);
    }

    return TCL_OK;
}

static void ig_tclc_connection_parse (const char *input, GString *id, GString *net, bool *adapt)
{
    if (input == NULL) return;
    if (id == NULL) return;
    if (net == NULL) return;
    if (adapt == NULL) return;

    log_debug ("TCnPr", "parsing connection info: %s", input);
    const char *split_net = strstr (input, "->");
    g_string_assign (id, input);
    if (split_net == NULL) {
        g_string_assign (net, "");
        *adapt = true;
        log_debug ("TCnPr", "got only object: %s", input);
        return;
    }

    g_string_truncate (id, (split_net - input));
    g_string_assign (net, split_net + 2);

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
}

static int ig_tclc_connect (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    char   *from    = NULL;
    char   *name    = NULL;
    char   *size    = NULL;
    GSList *to_list = NULL;
    GSList *bd_list = NULL;

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
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: signal name is required", -1));
        result = TCL_ERROR;
    }
    if ((from == NULL) && (bd_list == NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: signal start (-from) is required for unidirectional signals", -1));
        result = TCL_ERROR;
    }
    if ((bd_list != NULL) && ((from != NULL) || (to_list != NULL))) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid to mix bidirectional and unidirectional signal", -1));
        result = TCL_ERROR;
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
        ig_tclc_connection_parse (from, tstr_id, tstr_net, &t_adapt);
        struct ig_object *src_obj = (struct ig_object *)g_hash_table_lookup (db->objects_by_id, tstr_id->str);
        if (src_obj == NULL) goto l_ig_tclc_connect_nfexit;

        if (tstr_net->len > 0) {
            src             = ig_lib_connection_info_new (db->str_chunks, src_obj, tstr_net->str, IG_LCDIR_UP);
            src->force_name = !t_adapt;
        } else {
            src = ig_lib_connection_info_new (db->str_chunks, src_obj, NULL, IG_LCDIR_UP);
        }
    }

    GSList                    *trg_orig_list = to_list;
    enum ig_lib_connection_dir trg_dir       = IG_LCDIR_DEFAULT;
    if (trg_orig_list == NULL) {
        trg_orig_list = bd_list;
        trg_dir       = IG_LCDIR_BIDIR;
    }

    for (GSList *li = trg_orig_list; li != NULL; li = li->next) {
        ig_tclc_connection_parse ((const char *)li->data, tstr_id, tstr_net, &t_adapt);
        struct ig_object *trg_obj = (struct ig_object *)g_hash_table_lookup (db->objects_by_id, tstr_id->str);
        if (trg_obj == NULL) goto l_ig_tclc_connect_nfexit;

        struct ig_lib_connection_info *trg = NULL;
        if (tstr_net->len > 0) {
            trg             = ig_lib_connection_info_new (db->str_chunks, trg_obj, tstr_net->str, trg_dir);
            trg->force_name = !t_adapt;
        } else {
            trg = ig_lib_connection_info_new (db->str_chunks, trg_obj, NULL, trg_dir);
        }
        trg_list = g_list_prepend (trg_list, trg);
    }
    trg_list = g_list_reverse (trg_list);

    log_debug ("TCCon", "starting connection...");
    GList *gen_objs = NULL;

    if (!ig_lib_connection (db, name, src, trg_list, &gen_objs)) {
        g_list_free (gen_objs);
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not generate connection...", -1));
        result = TCL_ERROR;
    }
    log_debug ("TCCon", "... finished connection");

    Tcl_Obj *retval = Tcl_NewListObj (0, NULL);
    for (GList *li = gen_objs; li != NULL; li = li->next) {
        struct ig_object *i_obj = (struct ig_object *)li->data;

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
    g_slist_free (to_list);
    g_slist_free (bd_list);

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
    result = TCL_ERROR;
    Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not find object", -1));
    goto l_ig_tclc_connect_exit_pre;
}

static int ig_tclc_parameter (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *)clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    char   *name     = NULL;
    char   *value    = NULL;
    GSList *ept_list = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-name",        NULL,                                                      (void *)&name,     "parameter name", NULL},
        {TCL_ARGV_STRING,   "-value",       NULL,                                                      (void *)&value,    "default value", NULL},
        {TCL_ARGV_FUNC,     "-targets",     (void *)(Tcl_ArgvFuncProc *)ig_tclc_tcl_string_list_parse, (void *)&ept_list, "list of endpoints for parameter", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) goto l_ig_tclc_parameter_exit;

    if (name == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: parameter name is required", -1));
        result = TCL_ERROR;
    }
    if (value == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: parameter value is required", -1));
        result = TCL_ERROR;
    }
    if (ept_list == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: endpoint list is required for parameters", -1));
        result = TCL_ERROR;
    }

    if (result != TCL_OK) goto l_ig_tclc_parameter_exit;

    log_debug ("TCPar", "generating connection info");

    GList   *trg_list = NULL;
    GString *tstr_id  = g_string_new (NULL);
    GString *tstr_par = g_string_new (NULL);
    bool     t_adapt  = false;

    enum ig_lib_connection_dir trg_dir = IG_LCDIR_DEFAULT;

    for (GSList *li = ept_list; li != NULL; li = li->next) {
        ig_tclc_connection_parse ((const char *)li->data, tstr_id, tstr_par, &t_adapt);
        struct ig_object *trg_obj = (struct ig_object *)g_hash_table_lookup (db->objects_by_id, tstr_id->str);
        if (trg_obj == NULL) goto l_ig_tclc_parameter_nfexit;

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
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not generate parameter...", -1));
        result = TCL_ERROR;
    }

    Tcl_Obj *retval = Tcl_NewListObj (0, NULL);
    for (GList *li = gen_objs; li != NULL; li = li->next) {
        struct ig_object *i_obj = (struct ig_object *)li->data;

        Tcl_Obj *t_obj = Tcl_NewStringObj (i_obj->id, -1);
        Tcl_ListObjAppendElement (interp, retval, t_obj);
    }

    Tcl_SetObjResult (interp, retval);
    g_list_free (gen_objs);

l_ig_tclc_parameter_exit_pre:
    g_string_free (tstr_id, true);
    g_string_free (tstr_par, true);

l_ig_tclc_parameter_exit:
    g_slist_free (ept_list);

    return result;

l_ig_tclc_parameter_nfexit:
    for (GList *li = trg_list; li != NULL; li = li->next) {
        struct ig_lib_connection_info *trg = (struct ig_lib_connection_info *)li->data;
        ig_lib_connection_info_free (trg);
    }
    result = TCL_ERROR;
    Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not find object", -1));
    goto l_ig_tclc_parameter_exit_pre;
}

static int ig_tclc_logger (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    gchar   *loglevel   = NULL;
    gchar   *log_id     = NULL;
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
        gchar *msg = g_strdup_printf ("The following loglevels are available:\n");
        for (int i = 0; i < LOGLEVEL_COUNT; i++) {
            gchar *tmp = g_strdup_printf ("%s\t- %s\n", msg, loglevel_label[i]);
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
                gchar *msg = g_strdup_printf ("Set logID %s loglevel to %s", log_id, loglevel);
                Tcl_SetObjResult (interp, Tcl_NewStringObj ((char *)msg, -1));
                g_free (msg);
            } else {
                // set default log level:
                gchar *msg = g_strdup_printf ("Set default loglevel to %s", loglevel);
                Tcl_SetObjResult (interp, Tcl_NewStringObj ((char *)msg, -1));
                set_default_log_level (i);
                g_free (msg);
            }
        } else {
            // level does not exists:
            gchar *msg = g_strdup_printf ("Error: loglevel %s does not exist - try `-help` for a list of available loglevels", loglevel);
            Tcl_SetObjResult (interp, Tcl_NewStringObj ((char *)msg, -1));
            g_free (msg);
            return TCL_ERROR;
        }
    }

    return TCL_OK;
}

static int ig_tclc_log (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    gchar *log_id   = "Tcl";
    gint   loglevel = LOGLEVEL_INFO;
    gint   abort    = 0;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-id",      NULL,                               (void *)&log_id,       "log id",                              NULL},
        {TCL_ARGV_CONSTANT, "-info",    GINT_TO_POINTER (LOGLEVEL_INFO),    (void *)&loglevel,     "loglevel info",                       NULL},
        {TCL_ARGV_CONSTANT, "-warning", GINT_TO_POINTER (LOGLEVEL_WARNING), (void *)&loglevel,     "loglevel warning",                    NULL},
        {TCL_ARGV_CONSTANT, "-error",   GINT_TO_POINTER (LOGLEVEL_ERROR),   (void *)&loglevel,     "loglevel error",                      NULL},
        {TCL_ARGV_CONSTANT, "-debug",   GINT_TO_POINTER (LOGLEVEL_DEBUG),   (void *)&loglevel,     "loglevel debig",                      NULL},
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

    if (objc > 0) {
        for (int i = 1; i < objc; i++) {
            char *msg = Tcl_GetString (remObjv[i]);
            log_base (loglevel, log_id, "TCL", 0, "%s", msg);
            if (abort) {
                Tcl_SetObjResult (interp, Tcl_NewStringObj (msg, -1));
            }
        }
    }

    if (objc != 0) ckfree (remObjv);

    if (abort) return TCL_ERROR;
    return TCL_OK;
}

