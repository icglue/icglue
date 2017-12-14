/*       _\|/_
         (o o)
 +----oOO-{_}-OOo-------------+
 |          _      ^..^       |
 |    _   _(_     ( oo )  )~  |
 |  _) /)(// (/     ,,  ,,    |
 |                2017-12-13  | 
 +---------------------------*/

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


