/*       _\|/_
         (o o)
 +----oOO-{_}-OOo-------------+
 |          _      ^..^       |
 |    _   _(_     ( oo )  )~  |
 |  _) /)(// (/     ,,  ,,    |
 |                2017-12-13  | 
 +---------------------------*/

#include "color.h"

#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_MAGENTA "\x1b[35m"
#define ANSI_COLOR_CYAN    "\x1b[36m"
#define ANSI_RESET         "\x1b[0m"
#define ANSI_BOLD          "\x1b[1m"

gchar color_red     [CHAR_COLOR_SIZE] = "";
gchar color_green   [CHAR_COLOR_SIZE] = "";
gchar color_yellow  [CHAR_COLOR_SIZE] = "";
gchar color_blue    [CHAR_COLOR_SIZE] = "";
gchar color_magenta [CHAR_COLOR_SIZE] = "";
gchar color_cyan    [CHAR_COLOR_SIZE] = "";
gchar color_reset   [CHAR_COLOR_SIZE] = "";
gchar color_bold    [CHAR_COLOR_SIZE] = "";

/* colors */
void colors_on ()
{
    g_stpcpy (color_red,     ANSI_COLOR_RED);
    g_stpcpy (color_green,   ANSI_COLOR_GREEN);
    g_stpcpy (color_yellow,  ANSI_COLOR_YELLOW);
    g_stpcpy (color_blue,    ANSI_COLOR_BLUE);
    g_stpcpy (color_magenta, ANSI_COLOR_MAGENTA);
    g_stpcpy (color_cyan,    ANSI_COLOR_CYAN);
    g_stpcpy (color_reset,   ANSI_RESET);
    g_stpcpy (color_bold,    ANSI_BOLD);
}

void colors_off ()
{
    *color_red     = '\0';
    *color_green   = '\0';
    *color_yellow  = '\0';
    *color_blue    = '\0';
    *color_magenta = '\0';
    *color_cyan    = '\0';
    *color_reset   = '\0';
    *color_bold    = '\0';

}


