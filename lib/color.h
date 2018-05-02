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

#ifndef __COLOR_H__
#define __COLOR_H__

#include <glib.h>

#ifdef __cplusplus
extern "C" {
#endif

extern gchar color_red     [];
extern gchar color_green   [];
extern gchar color_yellow  [];
extern gchar color_blue    [];
extern gchar color_magenta [];
extern gchar color_cyan    [];
extern gchar color_reset   [];
extern gchar color_bold    [];

void colors_on ();
void colors_off ();

#ifdef __cplusplus
}
#endif

#endif

