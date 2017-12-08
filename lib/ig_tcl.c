#include "ig_data.h"
#include "ig_data_helpers.h"
#include "ig_lib.h"
#include "ig_tcl.h"

/* Tcl helper function for parsing lists in GSLists */
static int ig_tclc_tcl_string_list_parse (ClientData client_data, Tcl_Obj *obj, void *dest_ptr);

/* tcl proc declarations */
static int ig_tclc_create_module   (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_create_instance (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_set_attribute   (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_get_attribute   (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_get_modules     (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_get_instances   (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);


void ig_add_tcl_commands (Tcl_Interp *interp)
{
    if (interp == NULL) return;

    struct ig_lib_db *lib_db = ig_lib_db_new ();

    Tcl_CreateObjCommand (interp, "create_module",   ig_tclc_create_module,   lib_db, NULL);
    Tcl_CreateObjCommand (interp, "create_instance", ig_tclc_create_instance, lib_db, NULL);
    Tcl_CreateObjCommand (interp, "set_attribute",   ig_tclc_set_attribute,   lib_db, NULL);
    Tcl_CreateObjCommand (interp, "get_attribute",   ig_tclc_get_attribute,   lib_db, NULL);
    Tcl_CreateObjCommand (interp, "get_modules",     ig_tclc_get_modules,     lib_db, NULL);
    Tcl_CreateObjCommand (interp, "get_instances",   ig_tclc_get_instances,   lib_db, NULL);

}



/* Tcl helper function for parsing lists in GSLists */
static int ig_tclc_tcl_string_list_parse (ClientData client_data, Tcl_Obj *obj, void *dest_ptr)
{
    GSList **list_dest = (GSList **) dest_ptr;
    if (dest_ptr == NULL) {
        return 1;
    }

    GSList *result = NULL;

    if (obj == NULL) {
        return 1;
    }

    Tcl_Obj *in_list = obj;

    int len = 0;
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

    *list_dest = g_slist_reverse(result);
    return 1;
}


static int ig_tclc_create_module (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    struct ig_lib_db *db = (struct ig_lib_db *) clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    int int_true  = true;
    int int_false = false;

    int     ilm      = int_false;
    int     resource = int_false;
    char   *name     = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-name",        NULL,                        (void *) &name,      "the name of the module to be created", NULL},

        {TCL_ARGV_CONSTANT, "-ilm",         GINT_TO_POINTER (int_true),  (void *) &ilm,       "module is ilm",    NULL},
        {TCL_ARGV_CONSTANT, "-no-ilm",      GINT_TO_POINTER (int_false), (void *) &ilm,       "module is no ilm", NULL},

        {TCL_ARGV_CONSTANT, "-resource",    GINT_TO_POINTER (int_true),  (void *) &resource,  "module is resource",    NULL},
        {TCL_ARGV_CONSTANT, "-no-resource", GINT_TO_POINTER (int_false), (void *) &resource,  "module is no resource", NULL},

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
    struct ig_lib_db *db = (struct ig_lib_db *) clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    char   *name          = NULL;
    char   *of_module     = NULL;
    char   *parent_module = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING, "-name",          NULL, (void *) &name,          "the name of the instance to be created", NULL},
        {TCL_ARGV_STRING, "-of-module",     NULL, (void *) &of_module,     "module of this instance", NULL},
        {TCL_ARGV_STRING, "-parent-module", NULL, (void *) &parent_module, "parent module containing this instance", NULL},

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

    struct ig_module *of_mod   = (struct ig_module *) g_hash_table_lookup (db->modules_by_id,   of_module);
    if (of_mod == NULL) of_mod = (struct ig_module *) g_hash_table_lookup (db->modules_by_name, of_module);
    struct ig_module *pa_mod   = (struct ig_module *) g_hash_table_lookup (db->modules_by_id,   parent_module);
    if (pa_mod == NULL) pa_mod = (struct ig_module *) g_hash_table_lookup (db->modules_by_name, parent_module);

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

static int ig_tclc_set_attribute (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    struct ig_lib_db *db = (struct ig_lib_db *) clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    char   *obj_name   = NULL;
    char   *attr_name  = NULL;
    char   *attr_value = NULL;
    GSList *attr_list  = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-object",      NULL, (void *) &obj_name,   "object id", NULL},
        {TCL_ARGV_STRING,   "-attribute",   NULL, (void *) &attr_name,  "attribute name", NULL},
        {TCL_ARGV_STRING,   "-value",       NULL, (void *) &attr_value, "attribute value", NULL},

        {TCL_ARGV_FUNC,     "-attributes",  (void*) (Tcl_ArgvFuncProc*) ig_tclc_tcl_string_list_parse, (void*) &attr_list, "attributes as list of form <name> <value> <name2> <value2> ...", NULL},

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

    struct ig_object *obj = (struct ig_object *) g_hash_table_lookup (db->objects_by_id, obj_name);
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

static int ig_tclc_get_attribute (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    struct ig_lib_db *db = (struct ig_lib_db *) clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    char   *obj_name   = NULL;
    char   *attr_name  = NULL;
    GSList *attr_list  = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_STRING,   "-object",      NULL, (void *) &obj_name,   "object id", NULL},
        {TCL_ARGV_STRING,   "-attribute",   NULL, (void *) &attr_name,  "attribute name", NULL},

        {TCL_ARGV_FUNC,     "-attributes",  (void*) (Tcl_ArgvFuncProc*) ig_tclc_tcl_string_list_parse, (void*) &attr_list, "attributes as list of form <name> <value> <name2> <value2> ...", NULL},

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

    struct ig_object *obj = (struct ig_object *) g_hash_table_lookup (db->objects_by_id, obj_name);
    if (obj == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: unknown object", -1));
        g_slist_free (attr_list);
        return TCL_ERROR;
    }

    if (attr_name != NULL) {
        const char *val = ig_obj_attr_get (obj, attr_name);
        if (val == NULL) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not get attribute", -1));
            return TCL_ERROR;
        }

        Tcl_SetObjResult (interp, Tcl_NewStringObj (val, -1));
        return TCL_OK;
    }

    /* check */
    for (GSList *li = attr_list; li != NULL; li = li->next) {
        char *attr = (char *) li->data;
        if (ig_obj_attr_get (obj, attr) == NULL) {
            g_slist_free (attr_list);
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: could not get attribute", -1));
            return TCL_ERROR;
        }
    }

    /* result list */
    Tcl_Obj *retval = Tcl_NewListObj (0, NULL);
    for (GSList *li = attr_list; li != NULL; li = li->next) {
        char *attr = (char *) li->data;
        const char *val = ig_obj_attr_get (obj, attr);

        Tcl_Obj *val_obj = Tcl_NewStringObj (val, -1);
        Tcl_ListObjAppendElement (interp, retval, val_obj);
    }

    Tcl_SetObjResult (interp, retval);
    g_slist_free (attr_list);

    return TCL_OK;
}

static int ig_tclc_get_modules (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *) clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    int int_true  = true;
    int int_false = false;

    int     all        = int_false;
    int     check      = int_false;
    char   *mod_name   = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_CONSTANT, "-all",          GINT_TO_POINTER (int_true), (void *) &all,      "return all modules", NULL},
        {TCL_ARGV_CONSTANT, "-check-exists", GINT_TO_POINTER (int_true), (void *) &check,    "check for module, return true if module exists", NULL},
        {TCL_ARGV_STRING,   "-name",         NULL,                       (void *) &mod_name, "module name", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (all && (mod_name != NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid to specify name and -all", -1));
        return TCL_ERROR;
    }

    if ((mod_name == NULL) && check) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: -check-exists requires -name", -1));
        return TCL_ERROR;
    }

    if (mod_name != NULL) {
        struct ig_module *mod = (struct ig_module *) g_hash_table_lookup (db->modules_by_name, mod_name);

        if (check) {
            if (mod == NULL) {
                Tcl_SetObjResult (interp, Tcl_NewBooleanObj (false));
            } else {
                Tcl_SetObjResult (interp, Tcl_NewBooleanObj (true));
            }
            return TCL_OK;
        }

        if (mod == NULL) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no module found", -1));
            return TCL_ERROR;
        }

        Tcl_SetObjResult (interp, Tcl_NewStringObj (mod->object->id, -1));
        return TCL_OK;
    }

    /* list */
    GList *mod_list = g_hash_table_get_values (db->modules_by_id);
    Tcl_Obj *retval = Tcl_NewListObj (0, NULL);
    for (GList *li = mod_list; li != NULL; li = li->next) {
        struct ig_module *i_mod = (struct ig_module *) li->data;

        Tcl_Obj *mod_obj = Tcl_NewStringObj (i_mod->object->id, -1);
        Tcl_ListObjAppendElement (interp, retval, mod_obj);
    }

    Tcl_SetObjResult (interp, retval);
    g_list_free (mod_list);

    return TCL_OK;
}

static int ig_tclc_get_instances (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[])
{
    struct ig_lib_db *db = (struct ig_lib_db *) clientdata;

    if (db == NULL) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Internal Error: database is NULL", -1));
        return TCL_ERROR;
    }

    int int_true  = true;
    int int_false = false;

    int     all        = int_false;
    int     check      = int_false;
    char   *inst_name   = NULL;

    Tcl_ArgvInfo arg_table [] = {
        {TCL_ARGV_CONSTANT, "-all",          GINT_TO_POINTER (int_true), (void *) &all,      "return all instances", NULL},
        {TCL_ARGV_CONSTANT, "-check-exists", GINT_TO_POINTER (int_true), (void *) &check,    "check for instance, return true if it exists", NULL},
        {TCL_ARGV_STRING,   "-name",         NULL,                       (void *) &inst_name, "instance name", NULL},

        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END
    };

    int result = Tcl_ParseArgsObjv (interp, arg_table, &objc, objv, NULL);
    if (result != TCL_OK) return result;

    if (all && (inst_name != NULL)) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: invalid to specify name and -all", -1));
        return TCL_ERROR;
    }

    if ((inst_name == NULL) && check) {
        Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: -check-exists requires -name", -1));
        return TCL_ERROR;
    }

    if (inst_name != NULL) {
        struct ig_instance *inst = (struct ig_instance *) g_hash_table_lookup (db->instances_by_name, inst_name);

        if (check) {
            if (inst == NULL) {
                Tcl_SetObjResult (interp, Tcl_NewBooleanObj (false));
            } else {
                Tcl_SetObjResult (interp, Tcl_NewBooleanObj (true));
            }
            return TCL_OK;
        }

        if (inst == NULL) {
            Tcl_SetObjResult (interp, Tcl_NewStringObj ("Error: no instance found", -1));
            return TCL_ERROR;
        }

        Tcl_SetObjResult (interp, Tcl_NewStringObj (inst->object->id, -1));
        return TCL_OK;
    }

    /* list */
    GList *inst_list = g_hash_table_get_values (db->instances_by_id);
    Tcl_Obj *retval = Tcl_NewListObj (0, NULL);
    for (GList *li = inst_list; li != NULL; li = li->next) {
        struct ig_instance *i_inst = (struct ig_instance *) li->data;

        Tcl_Obj *inst_obj = Tcl_NewStringObj (i_inst->object->id, -1);
        Tcl_ListObjAppendElement (interp, retval, inst_obj);
    }

    Tcl_SetObjResult (interp, retval);
    g_list_free (inst_list);

    return TCL_OK;
}
