
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

package provide ICGlue 2.0

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
    # @param paramlist Known values of verilog parameters to use in form {{name1 value1} ...}.
    #
    # @return List of form {success value size} where
    # success is a boolean specifying whether the value could be parsed or not,
    # value is the value parsed on success or 0 otherwise and
    # size is the specified number of bits for the value or -1 if unspecified/unsuccessful.
    proc parse_value {value {paramlist {}}} {
        set success  false
        set resval   0
        set ressize -1

        if {[string is integer -strict $value]} {
            # simple integer
            set success true
            set resval $value
        } elseif {[regexp {^\s*([0-9]*)'([a-zA-Z])[0_]*([0-9a-fA-F_]+)\s*$} $value m_whole m_width m_radix m_value]} {
            # verilog number with radix specified
            set wstring $m_width

            set resvalc {}
            append resvalc [string map {h 0x H 0x b 0b B 0b o 0 O 0 d {} D {}} $m_radix] [string map {_ {}} $m_value]

            if {[string is entier -strict $resvalc]} {
                set success true
                set resval $resvalc

                if {$wstring ne {}} {
                    # width specified
                    set ressize $wstring
                }
            }
        } elseif {[regexp {^\s*([a-zA-Z]\w*)\s*$} $value m_whole m_param]} {
            # parameter
            set idx [lsearch -index 0 -exact $paramlist $m_param]
            if {$idx >= 0} {
                return [parse_value [lindex $paramlist $idx 1] [lreplace $paramlist $idx $idx]]
            }
        } elseif {[regexp {^\s*\((.*)\)\s*$} $value m_whole m_content]} {
            # parantheses
            return [parse_value $m_content $paramlist]
        } elseif {[regexp {^\s*\{\s*(.*)\s*\}\s*$} $value m_whole m_content]} {
            # braces
            if {[regexp {^([^{},[:space:]][^{},]+)(\{.*\})} $m_content m_whole m_rep m_val]} {
                # repetition
                lassign [parse_value $m_rep $paramlist] rep_s rep_v rep_w
                if {!$rep_s} {return [list $rep_s 0 -1]}
                lassign [parse_value $m_val $paramlist] val_s val_v val_w
                if {(!$val_s) || ($val_w <= 0)} {return [list $rep_s 0 -1]}

                set ressize 0
                for {set i 0} {$i < $rep_v} {incr i} {
                    incr ressize $val_w
                    set resval [expr {($resval << $val_w) | $val_v}]
                }
                set success true
            } else {
                # concatenation
                # split ...
                set vals [list]
                set balance 0
                set temp [list]
                foreach val [split $m_content ","] {
                    set balance [expr {$balance + [string length [string map {\{ {}} $val]] - [string length [string map {\} {}} $val]]}]
                    lappend temp $val
                    if {$balance == 0} {
                        lappend vals [join $temp ","]
                        set temp [list]
                    }
                }
                if {$balance != 0} {return [list false 0 -1]}

                # concatenate ...
                set first true
                set ressize 0
                foreach val $vals {
                    lassign [parse_value $val $paramlist] val_s val_v val_w
                    if {!$val_s} {return [list false 0 -1]}
                    if {$first} {
                        set first false
                    } else {
                        if {$val_w < 0} {return [list false 0 -1]}
                    }

                    set resval [expr {($resval << $val_w) | $val_v}]
                    if {$ressize >= 0} {
                        incr ressize $val_w
                    }
                }
                set success true
            }
        }

        return [list $success $resval $ressize]
    }

    namespace export *
}

