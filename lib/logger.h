/*       _\|/_
         (o o)
 +----oOO-{_}-OOo-------------+
 |          _      ^..^       |
 |    _   _(_     ( oo )  )~  |
 |  _) /)(// (/     ,,  ,,    |
 |                2017-12-12  | 
 +---------------------------*/

#ifndef __LOGGER_H__
#define __LOGGER_H__

#include <stdarg.h>
#include <glib.h>

#ifdef __cplusplus
extern "C" {
#endif

    typedef enum log_level {
        // virtual, reset log_particular_level
        LOGLEVEL_DEFAULT  =  -1,

        // loglevels
        LOGLEVEL_DEBUG    =  0,
        LOGLEVEL_INFO,
        LOGLEVEL_WARNING,
        LOGLEVEL_ERROR,
        LOGLEVEL_ERRORINT,

        // #loglevels
        LOGLEVEL_COUNT
    } log_level_t;
    extern gchar* loglevel_label[LOGLEVEL_COUNT];


    #define log_debug(id, format...)    log_base (LOGLEVEL_DEBUG,    id, __FILE__, __LINE__, format)
    #define log_info(id, format...)     log_base (LOGLEVEL_INFO,     id, __FILE__, __LINE__, format)
    #define log_warn(id, format...)     log_base (LOGLEVEL_WARNING,  id, __FILE__, __LINE__, format)
    #define log_error(id, format...)    log_base (LOGLEVEL_ERROR,    id, __FILE__, __LINE__, format)
    #define log_errorint(id, format...) log_base (LOGLEVEL_ERRORINT, id, __FILE__, __LINE__, format)

    void log_base  (const log_level_t level, const gchar *id, const gchar *sfile, gint sline, const gchar *format, ...) __attribute__((format(printf, 5, 6)));
    void log_basev (const log_level_t level, const gchar *id, const gchar *sfile, gint sline, const gchar *format, va_list arg_list) __attribute__((format(printf, 5, 0)));

    void set_default_log_level(log_level_t);


    void log_particular_level (const gchar *id, const log_level_t level);
    gboolean log_suppress (const log_level_t level, const gchar *id);


    void log_colors_on ();
    void log_colors_off ();

    void log_dump_settings ();

    extern gboolean log_linenumbers;
#ifdef __cplusplus
}
#endif

#endif
