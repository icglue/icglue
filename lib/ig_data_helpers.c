#include "ig_data_helpers.h"

#include <stdio.h>

bool ig_obj_attr_set_from_gslist (struct ig_object *obj, GSList *list)
{
    if (obj == NULL) return false;

    bool result = true;

    if (g_slist_length (list) % 2 == 1) {
        fprintf (stderr, "Error: need a value for every attribute in attribute list\n");
        return false;
    }

    for (GSList *li = list; li != NULL; li = li->next) {
        char *name = (char *) li->data;
        li = li->next;
        char *val  = (char *) li->data;

        if (!ig_obj_attr_set (obj, name, val, false)) {
            fprintf (stderr, "Error: could not set attribute %s\n", name);
            result = false;
        }
    }

    return result;
}
