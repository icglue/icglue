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
 * @brief Log message functionality.
 */

#ifndef __LOGGER_H__
#define __LOGGER_H__

#include <stdarg.h>
#include <glib.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Loglevel.
 *
 * Can be used for basic logging functions and to set logging for particular levels.
 */
typedef enum log_level {
    LOGLEVEL_DEFAULT =  -1, /**< @brief Virtual level, reset log_particular_level */

    /* actual loglevels */
    LOGLEVEL_DEBUG =  0,    /**< @brief Logging for debug messages. */
    LOGLEVEL_INFO,          /**< @brief Logging for info messages. */
    LOGLEVEL_WARNING,       /**< @brief Logging for warning messages. */
    LOGLEVEL_ERROR,         /**< @brief Logging for error messages. Program should usally exit on errors. */
    LOGLEVEL_ERRORINT,      /**< @brief Logging for interal library errors. */

    LOGLEVEL_COUNT          /**< @brief Virtual level, count of log levels. */
} log_level_t;

/**
 * @brief Mapping of @ref log_level to identifier.
 */
extern gchar *loglevel_label[LOGLEVEL_COUNT];

/**
 * @brief Printf-like debug logging.
 * @param id Identifier for log messages. Is printed next to message and can be used for selective enabling/disabling.
 * @param format Printf-like format string.
 * @param ... Optinal printf-like variadic arguments.
 */
#define log_debug(id, format, ...)    log_base (LOGLEVEL_DEBUG, id, __FILE__, __LINE__, format, ## __VA_ARGS__)

/**
 * @brief Printf-like informational logging.
 * @param id Identifier for log messages. Is printed next to message and can be used for selective enabling/disabling.
 * @param format Printf-like format string.
 * @param ... Optinal printf-like variadic arguments.
 */
#define log_info(id, format, ...)     log_base (LOGLEVEL_INFO, id, __FILE__, __LINE__, format, ## __VA_ARGS__)

/**
 * @brief Printf-like warning-message logging.
 * @param id Identifier for log messages. Is printed next to message and can be used for selective enabling/disabling.
 * @param format Printf-like format string.
 * @param ... Optinal printf-like variadic arguments.
 */
#define log_warn(id, format, ...)     log_base (LOGLEVEL_WARNING, id, __FILE__, __LINE__, format, ## __VA_ARGS__)

/**
 * @brief Printf-like error-message logging.
 * @param id Identifier for log messages. Is printed next to message and can be used for selective enabling/disabling.
 * @param format Printf-like format string.
 * @param ... Optinal printf-like variadic arguments.
 */
#define log_error(id, format, ...)    log_base (LOGLEVEL_ERROR, id, __FILE__, __LINE__, format, ## __VA_ARGS__)

/**
 * @brief Printf-like error-message logging for library internal errors.
 * @param id Identifier for log messages. Is printed next to message and can be used for selective enabling/disabling.
 * @param format Printf-like format string.
 * @param ... Optinal printf-like variadic arguments.
 */
#define log_errorint(id, format, ...) log_base (LOGLEVEL_ERRORINT, id, __FILE__, __LINE__, format, ## __VA_ARGS__);

/**
 * @brief Basic log function.
 * @param level Loglevel to use.
 * @param id Identifier printed on start of line and used for selective log enable/disable.
 * @param sfile File which issues the log message, used if logging of linenumbers is enabled.
 * @param sline Line of file where log message is issued, used if logging of linenumbers is enabled.
 * @param format Printf-like format string.
 * @param ... Variadic arguments for printf-like format output.
 */
void log_base (const log_level_t level, const gchar *id, const gchar *sfile, gint sline, const gchar *format, ...) __attribute__((format (printf, 5, 6)));

/**
 * @brief Basic log function with va_list.
 * @param level Loglevel to use.
 * @param id Identifier printed on start of line and used for selective log enable/disable.
 * @param sfile File which issues the log message, used if logging of linenumbers is enabled.
 * @param sline Line of file where log message is issued, used if logging of linenumbers is enabled.
 * @param format Printf-like format string.
 * @param arg_list Variadic arguments for printf-like format output.
 */
void log_basev (const log_level_t level, const gchar *id, const gchar *sfile, gint sline, const gchar *format, va_list arg_list) __attribute__((format (printf, 5, 0)));

/**
 * @brief Specify the current basic log level.
 * @param log_level Specified log level.
 *
 * All log messages with a level lower than @c log_level will be suppressed.
 */
void set_default_log_level (log_level_t log_level);

/**
 * @brief Enable/disable logging of file and linenumber.
 * @param value @c true enables file/line logging, @c false disables file/line logging.
 */
void set_loglinenumbers (gboolean value);

/**
 * @brief Specify identifier-based specific log level.
 * @param id Identifier.
 * @param level Log level.
 *
 * Loglevel for all log-messages with specified identifier is set to @c level.
 */
void log_particular_level (const gchar *id, const log_level_t level);

/**
 * @brief Check whether log output should be suppressed for specific level/identifier.
 * @param level Log level of message to check.
 * @param id Identifier of message to check.
 * @return @c true if message is to be suppressed, false if message is to be printed.
 */
gboolean log_suppress (const log_level_t level, const gchar *id);

/**
 * @brief Print current log level settings to stderr.
 */
void log_dump_settings ();

#ifdef __cplusplus
}
#endif

#endif

