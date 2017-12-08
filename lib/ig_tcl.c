#include "ig_data.h"
#include "ig_data_helpers.h"
#include "ig_lib.h"
#include "ig_tcl.h"

/* Tcl helper function for parsing lists in GSLists */
static int ig_tclc_tcl_string_list_parse (ClientData client_data, Tcl_Obj *obj, void *dest_ptr);

/* tcl proc declarations */
static int ig_tclc_create_module (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);
static int ig_tclc_set_attribute (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);


void ig_add_tcl_commands (Tcl_Interp *interp)
{
    if (interp == NULL) return;

    struct ig_lib_db *lib_db = ig_lib_db_new ();

    Tcl_CreateObjCommand (interp, "create_module", ig_tclc_create_module, lib_db, NULL);
    Tcl_CreateObjCommand (interp, "set_attribute", ig_tclc_set_attribute, lib_db, NULL);

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

    struct ig_object *obj = (struct ig_object *) g_hash_table_lookup (db->objects, obj_name);
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
