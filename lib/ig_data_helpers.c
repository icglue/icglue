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

#include "ig_data_helpers.h"
#include "logger.h"

#include <stdio.h>

bool ig_obj_attr_set_from_gslist (struct ig_object *obj, GSList *list)
{
    if (obj == NULL) return false;

    bool result = true;

    if (g_slist_length (list) % 2 == 1) {
        log_error ("OStAt", "need a value for every attribute in attribute list");
        return false;
    }

    for (GSList *li = list; li != NULL; li = li->next) {
        char *name = (char *)li->data;
        li = li->next;
        char *val = (char *)li->data;

        if (!ig_obj_attr_set (obj, name, val, false)) {
            log_error ("OStAt", "could not set attribute %s", name);
            result = false;
        }
    }

    return result;
}

