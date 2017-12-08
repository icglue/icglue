#include <tcl.h>
#include <stdio.h>

#include "ig_tcl.h"

/* for normal interpreters */
int Icglue_Init (Tcl_Interp *interp) {
    printf ("ICGlue v0.0.1\n");

    ig_add_tcl_commands (interp);

    return TCL_OK;
}

/* for safe interpreters */
int Icglue_SafeInit (Tcl_Interp *interp) {
    fprintf (stderr, "Error: safe interpreters not supported!\n");
    return TCL_ERROR;
}

