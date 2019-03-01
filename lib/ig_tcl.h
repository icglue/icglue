/*
 *  ICGlue is a Tcl-Library for scripted HDL generation
 *  Copyright (C) 2017-2019  Andreas Dixius, Felix Neumärker
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
 * @brief Integrate icglue library into Tcl.
 */

#ifndef __IG_TCL_H__
#define __IG_TCL_H__

#include <tcl.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Add ICGlue lib commands to tcl interpreter.
 * @param interp Tcl interpreter to add commands to.
 */
void ig_add_tcl_commands (Tcl_Interp *interp);

#ifdef __cplusplus
}
#endif

#endif

