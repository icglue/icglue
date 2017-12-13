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


#define CHAR_COLOR_SIZE 10
extern gchar color_red     [CHAR_COLOR_SIZE];
extern gchar color_green   [CHAR_COLOR_SIZE];
extern gchar color_yellow  [CHAR_COLOR_SIZE];
extern gchar color_blue    [CHAR_COLOR_SIZE];
extern gchar color_magenta [CHAR_COLOR_SIZE];
extern gchar color_cyan    [CHAR_COLOR_SIZE];
extern gchar color_reset   [CHAR_COLOR_SIZE];
extern gchar color_bold    [CHAR_COLOR_SIZE];

void colors_on ();
void colors_off ();

#ifdef __cplusplus
}
#endif

#endif


