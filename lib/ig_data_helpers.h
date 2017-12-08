/*       _\|/_
         (o o)
 +----oOO-{_}-OOo-------------+
 |          _      ^..^       |
 |    _   _(_     ( oo )  )~  |
 |  _) /)(// (/     ,,  ,,    |
 |                2017-12-08  | 
 +---------------------------*/

#ifndef __IG_DATA_HELPERS_H__
#define __IG_DATA_HELPERS_H__

#include "ig_data.h"

#include <glib.h>

#ifdef __cplusplus
extern "C" {
#endif

bool ig_obj_attr_set_from_gslist (struct ig_object *obj, GSList *list);

#ifdef __cplusplus
}
#endif

#endif
