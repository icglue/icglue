
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

package provide ICGlue 1.0a1

namespace eval ig::aux {
    proc foreach_array {iter array_list body} {
        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            uplevel 1 $body
        }
    }
    proc foreach_array_with {iter array_list condition body} {
        foreach __iter $array_list {
            uplevel 1 array set $iter [list ${__iter}]
            uplevel 1 if [list $condition] [list $body]
        }
    }
    proc max_entry_len {data_list transform_proc} {
        set len 0
        foreach i_entry $data_list {
            set i_len [string length [$transform_proc $i_entry]]
            set len [expr {max ($len, $i_len)}]
        }
        return $len
    }

    proc max_array_entry_len {array_list array_entry} {
        set len 0
        foreach i_entry $array_list {
            array set i_a $i_entry
            set i_len [string length $i_a($array_entry)]
            set len [expr {max ($len, $i_len)}]
        }
        return $len
    }

    proc is_last {lst entry} {
        if {[lindex $lst end] eq $entry} {
            return "true"
        } else {
            return "false"
        }
    }

    proc object_name {obj} {
        return [ig::db::get_attribute -object $obj -attribute "name"]
    }

    proc adapt_codesection {codesection} {
        set do_adapt [ig::db::get_attribute -object $codesection -attribute "adapt" -default "false"]
        set code [ig::db::get_attribute -object $codesection -attribute "code"]
        if {!$do_adapt} {
            return $code
        }

        set parent_mod [ig::db::get_attribute -object $codesection -attribute "parent"]
        set signal_replace [list]
        foreach i_port [ig::db::get_ports -of $parent_mod -all] {
            set i_rep [list \
                [ig::db::get_attribute -object $i_port -attribute "signal"] \
                [ig::db::get_attribute -object $i_port -attribute "name"] \
            ]
            lappend signal_replace $i_rep
        }
        foreach i_decl [ig::db::get_declarations -of $parent_mod -all] {
            set i_rep [list \
                [ig::db::get_attribute -object $i_decl -attribute "signal"] \
                [ig::db::get_attribute -object $i_decl -attribute "name"] \
            ]
            lappend signal_replace $i_rep
        }

        foreach i_rep $signal_replace {
            set i_orig  "\\m[lindex $i_rep 0]\\M"
            set i_subst [lindex $i_rep 1]

            regsub -all $i_orig $code $i_subst code
        }

        return $code
    }

    proc adapt_signalname {signalname mod_id} {
        foreach i_port [ig::db::get_ports -of $mod_id -all] {
            if {[ig::db::get_attribute -object $i_port -attribute "signal"] eq $signalname} {
                return [ig::db::get_attribute -object $i_port -attribute "name"]
            }
        }
        foreach i_decl [ig::db::get_declarations -of $mod_id -all] {
            if {[ig::db::get_attribute -object $i_decl -attribute "signal"] eq $signalname} {
                return [ig::db::get_attribute -object $i_decl -attribute "name"]
            }
        }
        ig::log -warning "Signal $signalname not defined in module [ig::db::get_attribute -object $mod_id -attribute "name"]"
        return $signalname
    }
}
