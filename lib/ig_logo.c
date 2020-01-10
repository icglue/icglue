/*
 *  ICGlue is a Tcl-Library for scripted HDL generation
 *  Copyright (C) 2017-2020  Andreas Dixius, Felix Neumärker
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

#include "ig_logo.h"

// do not edit directly - use output of  <ICGLUE-ROOT>/logo/logo2c.sh
static const char *const ig_logo_lines[] = {
    "                        ,'.",
    "                       /-. `.",
    "                     ,'   `. \\",
    ",----,--.--,--.--,--/       \\.`.",
    "|    |  |  |  |  |,'        ,,'",
    "|    `__'  `__'  /      _.-'",
    "/----.----------/.  .,-'-|   ___ ____ ____ _",
    "\\____'|    |  ,',,`-_____|  |_ _/ ___/ ___| |_   _  ___",
    "|     |    | .-'   |     |   | | |  | |  _| | | | |/ _ \\",
    "/----.| ,XXXX.     |,----|   | | |__| |_| | | |_| |  __/",
    "\\____.|-XXXXXX-----|`____|  |___\\____\\____|_|\\__,_|\\___|",
    "|     | `XXXX'     |     |",
    "/----.|   `|'      |,----|  ICGlue v4.0",
    "\\____.`____|_______'`____|  a Tcl-Library for scripted HDL generation",
    "|    ,--.  ,--.  ,--.    |  Copyright (C) Andreas Dixius, Felix Neumärker",
    "|    |  |  |  |  |  |    |  Use and redistribute under the terms of the",
    "`----`--'--`--'--`--'----'  GNU General Public License version 3",
    NULL
};

void ig_print_logo (FILE *file)
{
    for (int i = 0; ig_logo_lines[i] != NULL; i++) {
        fprintf (file, "%11s%s\n", "", ig_logo_lines[i]);
    }
    fprintf (file, "\n");
}

