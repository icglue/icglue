#include <tcl.h>
#include <stdio.h>

/* for normal interpreters */
int Icglue_Init (Tcl_Interp *interp) {
    printf ("Hello World!\n");
    return TCL_OK;
}

/* for safe interpreters */
int Icglue_SafeInit (Tcl_Interp *interp) {
    fprintf (stderr, "Error: safe interpreters not supported!\n");
    return TCL_ERROR;
}

