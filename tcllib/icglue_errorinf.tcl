
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

namespace eval ig::errinf {

    proc split_st {st} {
        set result {}
        if {[regexp {(^.*?)\s+while executing\n(.*)$} $st m_whole m_msg m_rem]} {
            #puts "st start: $m_msg"
            lappend result $m_msg
            set st $m_rem
        } else {
            log -error -abort "unable to parse stack-trace"
        }

        set stack {}
        while {[string length $st] > 0} {
            if {[regexp {(^.*?)\s*\n\s+\((.*?)\)\s*\n\s+invoked from within\s*\n(.*)$} $st m_whole m_cmd m_info m_rem]} {
                #puts "st step: $m_info"
                set st $m_rem
                lappend stack [list $m_cmd $m_info]
            } else {
                #puts "st end: $st"
                lappend stack [list $st ""]
                set st ""
            }
        }
        lappend result $stack

        return $result
    }

    proc get_file_line {filename stack} {
        set lineacc -1

        foreach i_entry [lreverse $stack] {
            set cmd [lindex $i_entry 0]
            set inf [lindex $i_entry 1]

            if {[regexp {^file\s+"(.*)"\s+line\s+(\d+)$} $inf m_whole m_file m_line]} {
                if {$m_file eq $filename} {
                    set lineacc $m_line
                    #puts "st file: linenumber $m_line"
                    continue
                }
            }

            if {[regexp {^in namespace eval.*\s+line\s+(\d+)$} $inf m_whole m_line]} {
                if {$lineacc > 0} {
                    set lineacc [expr {$lineacc + $m_line - 1}]
                }
                #puts "st namespace: linenumber $m_line, acc: $lineacc"
                continue
            }

            if {$lineacc > 0} {
                break
            }
        }

        return $lineacc
    }

    proc print_st_line {filename} {
        set st $::errorInfo

        ig::log -error "Tcl stack-trace:\n$st"

        if {(![catch {
                set st_list [split_st $st]
                set line [get_file_line $filename [lindex $st_list 1]]
                }]) && ($line >= 0)} {
            ig::log -error "aborted in file \"$filename\" around line $line with:"
            ig::log -error [lindex $st_list 0]
        }
    }


}
