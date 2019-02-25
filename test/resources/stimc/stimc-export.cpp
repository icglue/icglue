/*
 *  stimc is a leightweight verilog-vpi wrapper for stimuli generation.
 *  Copyright (C) 2019  Andreas Dixius, Felix Neumärker
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

/* declaration */
#define STIMC_EXPORT(module) \
    void _stimc_module_ ## module ## _register (void);

#include "stimc-export.inl"

#undef STIMC_EXPORT
#define STIMC_EXPORT(module) \
    _stimc_module_ ## module ## _register,

/* vlog startup vec */
void (*vlog_startup_routines[])(void) = {
#   include "stimc-export.inl"
    0,
};

