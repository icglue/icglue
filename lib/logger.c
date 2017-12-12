#include "logger.h"

#include <stdio.h>
#include <stdbool.h>
#include <glib.h>

void log_base (enum log_level level, const char *id, const char *sfile, int sline, const char *format, ...)
{
    va_list argptr;
    va_start (argptr, format);
    log_basev (level, id, sfile, sline, format, argptr);
    va_end (argptr);
}

void log_basev (enum log_level level, const char *id, const char *sfile, int sline, const char *format, va_list arg_list)
{
    GString *log_string = g_string_new (NULL);
    g_string_vprintf (log_string, format, arg_list);

    /* TODO... */
    fprintf (stderr, "%s: %s\n", "DEBUG", log_string->str);

    g_string_free (log_string, true);
}
