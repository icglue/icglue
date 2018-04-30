
#
#   ICGlue is a Tcl-Library for scripted HDL generation
#   Copyright (C) 2017-2018  Andreas Dixius, Felix Neumärker
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

package provide ICGlue 0.0.1

namespace eval ig::vlog {
    proc bitrange {size} {
        if {[string is integer $size]} {
            if {$size == 1} {
                return ""
            } else {
                return "\[[expr {$size-1}]:0\]"
            }
        } else {
            return "\[$size-1:0\]"
        }
    }

    proc obj_bitrange {obj} {
        set size [ig::db::get_attribute -object $obj -attribute "size"]
        return [bitrange $size]
    }

    proc port_dir {port} {
        set dir [ig::db::get_attribute -object $port -attribute "direction"]
        if {$dir eq "input"} {return "input"}
        if {$dir eq "output"} {return "output"}
        if {$dir eq "bidirectional"} {return "inout"}
        return ""
    }

    proc param_type {param} {
        if {[ig::db::get_attribute -object $param -attribute "local"]} {
            return "localparam"
        } else {
            return "parameter"
        }
    }

    proc declaration_type {decl} {
        if {[ig::db::get_attribute -object $decl -attribute "default_type"]} {
            return "wire"
        } else {
            return "reg"
        }
    }
}
