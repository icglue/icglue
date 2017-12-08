#include "ig_data.h"
#include "ig_lib.h"
#include "ig_tcl.h"

/* tcl proc declarations */
static int ig_tclc_create_module (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]);


void ig_add_tcl_commands (Tcl_Interp *interp)
{
    if (interp == NULL) return;

    struct ig_lib_db *lib_db = ig_lib_db_new ();

    Tcl_CreateObjCommand (interp, "create_module", ig_tclc_create_module, lib_db, NULL);
}


static int ig_tclc_create_module (ClientData clientdata, Tcl_Interp *interp, int objc, Tcl_Obj *const objv[]) {
    struct ig_lib_db *db = (struct ig_lib_db *) clientdata;

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

    Tcl_SetObjResult (interp, Tcl_NewStringObj (module->object->id, -1));

    return TCL_OK;
}
