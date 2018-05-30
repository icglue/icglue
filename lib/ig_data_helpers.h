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
 * @brief Auxiliary helper functions for data structures.
 */
#ifndef __IG_DATA_HELPERS_H__
#define __IG_DATA_HELPERS_H__

#include "ig_data.h"

#include <glib.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Set multiple object attributes at once.
 * @param obj Object where attributes are to be set.
 * @param list of attributes and values, list data: @c (char*).
 * @return @c true on success or @c false if one or more attributes could not be set.
 *
 * The list must contain attributes and values interleaved (so {attribute 1, value 1, attribute 2, value 2, ...}).
 */
bool ig_obj_attr_set_from_gslist (struct ig_object *obj, GList *list);

#ifdef __cplusplus
}
#endif

#endif

