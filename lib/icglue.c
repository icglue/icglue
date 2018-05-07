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

#include <tcl.h>
#include <stdio.h>

#include "ig_tcl.h"
#include "ig_logo.h"
#include "logger.h"
#include "color.h"

/* for normal interpreters */
int Icglue_Init (Tcl_Interp *interp)
{

    colors_on ();

    ig_print_logo (stderr);

    ig_add_tcl_commands (interp);

    Tcl_PkgProvide (interp, "ICGlue", "1.0a");
    log_info ("PLoad", "ICGlue v1.0a loaded");

    return TCL_OK;
}

/* for safe interpreters */
int Icglue_SafeInit (Tcl_Interp *interp)
{
    log_error ("PLoad", "safe interpreters not supported!");

    return TCL_ERROR;
}

