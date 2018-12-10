
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

package provide ICGlue 1.3

## @brief Helper functions for verilog output
namespace eval ig::vlog {
    ## @brief Convert a size to a verilog (declaration) bitrange expression.
    #
    # @param size Size to convert.
    #
    # @return Bitrange of form "[size-1:0]".
    proc bitrange {size} {
        if {[string is integer $size]} {
            if {$size == 1} {
                return ""
            } else {
                return "\[[expr {$size-1}]:0\]"
            }
        } elseif {[regexp {^(.*)([+-])([1-9]\d*)$} $size m_whole m_prefix m_op m_num]} {
            if {$m_op eq "+"} {
                incr m_num -1
                if {$m_num < 0} {
                    set m_num [expr {-$m_num}]
                    set m_op "-"
                }
            } else {
                incr m_num
            }

            if {$m_num == 0} {
                return "\[${m_prefix}:0\]"
            } else {
                return "\[${m_prefix}${m_op}${m_num}:0\]"
            }
        } else {
            return "\[$size-1:0\]"
        }
    }

    ## @brief Return (declaration) bitrange of database object.
    #
    # @param obj Object-ID to process.
    #
    # @return Bitrange as in @ref bitrange.
    proc obj_bitrange {obj} {
        set size [ig::db::get_attribute -object $obj -attribute "size"]
        return [bitrange $size]
    }

    ## @brief Return (declaration) type of a port for verilog based on its direction.
    #
    # @param port Object-ID of port.
    #
    # @return Verilog port direction.
    proc port_dir {port} {
        set dir [ig::db::get_attribute -object $port -attribute "direction"]
        if {$dir eq "input"} {return "input"}
        if {$dir eq "output"} {return "output"}
        if {$dir eq "bidirectional"} {return "inout"}
        return ""
    }

    ## @brief Return (declaration) type of a parameter for verilog.
    #
    # @param param Object-ID of parameter.
    #
    # @return Verilog parameter type.
    proc param_type {param} {
        if {[ig::db::get_attribute -object $param -attribute "local"]} {
            return "localparam"
        } else {
            return "parameter"
        }
    }

    ## @brief Return (declaration) type of a variable for verilog.
    #
    # @param decl Object-ID of variable.
    #
    # @return Verilog declaration type.
    proc declaration_type {decl} {
        if {[ig::db::get_attribute -object $decl -attribute "default_type"]} {
            return "wire"
        } else {
            return "reg"
        }
    }

    namespace export *
}

# vim: set filetype=icgluetcl syntax=tcl:
