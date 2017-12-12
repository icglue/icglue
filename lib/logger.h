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

#ifdef __cplusplus
extern "C" {
#endif

    enum log_level {
        LOGLEVEL_INVALID  = -1,
        LOGLEVEL_DEBUG    =  0,
        LOGLEVEL_INFO     =  1,
        LOGLEVEL_WARNING  =  2,
        LOGLEVEL_ERROR    =  3,
        LOGLEVEL_ERRORINT =  4,
    };

    /* TODO: file/line */
    #define log_debug(id, format...) log_base (LOGLEVEL_DEBUG,    id, NULL, 0, format)
    #define log_info(id, format...) log_base (LOGLEVEL_INFO,     id, NULL, 0, format)
    #define log_warn(id, format...) log_base (LOGLEVEL_WARNING,  id, NULL, 0, format)
    #define log_error(id, format...) log_base (LOGLEVEL_ERROR,    id, NULL, 0, format)
    /* TODO: file/line */
    #define log_errorint(id, format...) log_base (LOGLEVEL_ERRORINT, id, NULL, 0, format)

    void log_base  (enum log_level level, const char *id, const char *sfile, int sline, const char *format, ...) __attribute__((format(printf, 5, 6)));
    void log_basev (enum log_level level, const char *id, const char *sfile, int sline, const char *format, va_list arg_list) __attribute__((format(printf, 5, 0)));

#ifdef __cplusplus
}
#endif

#endif
