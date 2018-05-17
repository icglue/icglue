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

/**
 * @file
 * @brief Escape sequences for colored terminal output.
 *
 * Escape sequences can be integrated in strings, but should not be modified externally.
 * To switch on/off color use @ref colors_on and @ref colors_off.
 */

#ifndef __COLOR_H__
#define __COLOR_H__

#include <glib.h>

#ifdef __cplusplus
extern "C" {
#endif

extern gchar color_red     []; /**< @brief Escape sequence for red. */
extern gchar color_green   []; /**< @brief Escape sequence for green. */
extern gchar color_yellow  []; /**< @brief Escape sequence for yellow. */
extern gchar color_blue    []; /**< @brief Escape sequence for blue. */
extern gchar color_magenta []; /**< @brief Escape sequence for magenta. */
extern gchar color_cyan    []; /**< @brief Escape sequence for cyan. */
extern gchar color_reset   []; /**< @brief Escape sequence for resetting color. */
extern gchar color_bold    []; /**< @brief Escape sequence for bold output. */

/**
 * @brief Load escape sequences provided with actual color codes.
 */
void colors_on ();

/**
 * @brief Load escape sequences provided with empty values to turn off color.
 */
void colors_off ();

#ifdef __cplusplus
}
#endif

#endif

