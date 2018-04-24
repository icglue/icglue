#include <tcl.h>
#include <stdio.h>

#include "ig_tcl.h"
#include "logger.h"
#include "color.h"

/* for normal interpreters */
int Icglue_Init (Tcl_Interp *interp) {

    colors_on ();
    log_info ("PLoad", "ICGlue v0.0.1");

    ig_add_tcl_commands (interp);

    Tcl_PkgProvide (interp, "ICGlue", "0.0.1");

    return TCL_OK;
}

/* for safe interpreters */
int Icglue_SafeInit (Tcl_Interp *interp) {
    log_error ("PLoad", "safe interpreters not supported!");

    return TCL_ERROR;
}

