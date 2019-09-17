#!/usr/bin/env tclsh

#
#   ICGlue is a Tcl-Library for scripted HDL generation
#   Copyright (C) 2017-2019  Andreas Dixius, Felix Neumärker
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# set package path and load ICGlue package
lappend auto_path [file normalize [file join [file dirname [file dirname [file normalize $::argv0]]] lib]]
set icglue_silent_load "true"
package require ICGlue 3.4

foreach ns [list ig::] {
    set ::syntax(${ns}aux::max_set) {n x}
}

unset ns

source "$::env(NAGELFAR_SYNTAXBUILD)"

