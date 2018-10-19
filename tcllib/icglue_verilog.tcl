
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

package provide ICGlue 2.0a1

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

    ## @brief Try to parse a (simple) verilog value into an integer.
    #
    # @param value The value to parse.
    # @param paramlist Known values of verilog parameters to use (currently unused).
    #
    # @return List of form {success value size} where
    # success is a boolean specifying whether the value could be parsed or not,
    # value is the value parsed on success or 0 otherwise and
    # size is the specified number of bits for the value or -1 if unspecified/unsuccessful.
    proc parse_value {value {paramlist {}}} {
        set success  false
        set resval   0
        set ressize -1

        if {[string is integer $value]} {
            # width necessary to represent actual integer value
            set success true
            set resval $value
        } elseif {[string first {'} $value] >= 0} {
            # width specified
            set wsplit  [split $value {'}]
            set wstring [lindex $wsplit 0]

            # unspecified size
            set resvalc [string map {h 0x b 0b o 0} [lindex $wsplit 1]]
            if {[string index $resvalc 0] eq "d"} {
                set resvalc [string range $resvalc 1 end]
                while {([string length $resvalc] > 1) && ([string index $resvalc 0] eq "0")} {
                    set resvalc [string range $resvalc 1 end]
                }
            }
            if {[string is integer $resvalc]} {
                set success true
                set resval $resvalc

                if {$wstring ne {}} {
                    set ressize $wstring
                }
            }
        }

        return [list $success $resval $ressize]
    }

    namespace export *
}

# vim: set filetype=icgluetcl syntax=tcl:
