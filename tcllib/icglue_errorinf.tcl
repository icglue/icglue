
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

## @brief Error output helpers.
namespace eval ig::errinf {

    ## @brief Split Tcl error stack trace into a list.
    #
    # @param st Tcl stack trace as one string
    #
    # @return list of single stack trace items split into command (out of "invoked from within" part) and information (mostly actual code) part
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

    ## @brief Try to obtain line where an error occurred in given file out of splitted (@ref split_st) stack trace.
    #
    # @param filename Name of file to look for in stack trace.
    # @param stack Stack trace splitted with @ref split_st (list of stack elements).
    #
    # @return Line where the error approximately occurred (might differ because of lines wrapped with "\" or when unable to find relevant parts in stack.
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

    ## @brief print error stack trace and try to print line of given file where the error occurred.
    #
    # @param filename Name of file to look for in current stack trace.
    #
    # Should only be called after an error occurred when sourcing a file (filename)
    # and the error was catched.
    # In this case first the stack trace as logged, then the stack trace is processed trying to obtain the
    # linenumber in the sourced file where the error occurred.
    # In case an approximate line number was found it is logged as well after the stack trace.
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

    namespace export print_st_line
}

# vim: set filetype=icgluetcl syntax=tcl:
