#!/usr/bin/env tclsh

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

proc get_simple_defines {file_lines} {
    set defines {}

    foreach i_line $file_lines {
        if {[regexp -expanded {
                ^ \s* \# define \s+
                ( \w+ ) \s+
                ( .* \S+ )
                \s* $
                } $i_line m_whole m_def m_val]} {
            #puts "found define: ${m_def} -> ${m_val}"
            lappend defines $m_def $m_val
        }
    }

    return $defines
}

proc get_tcl_commands {file_lines defines_list} {
    array set defines $defines_list
    set cmdfunclist {}
    set linenum 0

    foreach i_line $file_lines {
        incr linenum
        if {[regexp -expanded {
                Tcl_CreateObjCommand \s* \(
                [^,]+ ,
                \s* ( [^,]+ [^[:space:],] ) \s* ,
                \s* ( [^,]+ [^[:space:],] ) \s* ,
                [^,]+ ,
                [^\)]+
                \);
                } $i_line m_whole m_cmdname_raw m_funcname]} {
            #puts "found tcl command definition: ${m_cmdname_raw} -> ${m_funcname}"

            set cmdname {}

            foreach i_part [split $m_cmdname_raw " "] {
                if {[string index $i_part 0] eq "\""} {
                    append cmdname [string range $i_part 1 [string last "\"" $i_part]-1]
                } elseif {[info exists defines($i_part)]} {
                    set def $defines($i_part)
                    append cmdname [string range $def [string first "\"" $def]+1 [string last "\"" $def]-1]
                }
            }

            #puts "found tcl command definition: ${cmdname} -> ${m_funcname}"
            lappend cmdfunclist [list $linenum $cmdname $m_funcname]
        }
    }

    return $cmdfunclist
}

proc get_tcldoc {file_lines} {
    set func_doc_list {}

    set lastdoc {}
    set lastdocline -1
    set state "plain"
    set linenum 0

    foreach i_line $file_lines {
        incr linenum
        switch -exact -- $state {
            "plain" {
                if {[regexp -expanded {/\* \s+ TCLDOC} $i_line m_whole]} {
                    set state "doc"
                    set lastdocline $linenum
                    #puts "found tcldoc at line $linenum"
                } elseif {[regexp -expanded {
                        \s* int \s+
                        ( \w+ ) \s*
                        \( \s*
                        ClientData \s [^,]+ , \s*
                        Tcl_Interp \s [^,]+ , \s*
                        int \s [^,]+ , \s*
                        Tcl_Obj \s [^,\)]+ \)
                        [^;]* $
                        } $i_line m_whole m_funcname]} {
                    #puts "found function $m_funcname ... doc is $lastdoc"

                    lappend func_doc_list [list \
                        $linenum $m_funcname \
                        $lastdocline $lastdoc \
                    ]

                    set lastdoc {}
                    set lastdocline -1
                }
            }
            "doc" {
                if {[regexp -expanded {\*/} $i_line m_whole]} {
                    set state "plain"
                } else {
                    append lastdoc "\n" $i_line
                }
            }
        }
    }

    return $func_doc_list
}

proc gen_dummy_tcl {cmdfunclist funcdoclist} {
    set output_list {}

    foreach {i_entry} $cmdfunclist {
        set cmd  [lindex $i_entry 1]
        set func [lindex $i_entry 2]

        set docidx [lsearch -index 1 $funcdoclist $func]
        if {$docidx >= 0} {
            set doc [lindex $funcdoclist $docidx 3]
        } else {
            set doc "\n"
        }

        lappend output_list $doc
        lappend output_list "proc ${cmd} \{args\} \{"
        lappend output_list "    # dummy proc for library function"
        lappend output_list "\}"
        lappend output_list ""
    }

    return [join $output_list "\n"]
}

proc main {} {
    if {$::argc != 2} {
        puts "ERROR: need 2 arguments: <srcfile> <targetfile>"
        exit 1
    }

    set src_filename [lindex $::argv 0]
    set trg_filename [lindex $::argv 1]

    set src_file [open $src_filename "r"]
    set src_lines [split [read $src_file] "\n"]
    close $src_file

    set defines [get_simple_defines $src_lines]
    set cmdfunclist [get_tcl_commands $src_lines $defines]
    set funcdoclist [get_tcldoc $src_lines]
    set tclout [gen_dummy_tcl $cmdfunclist $funcdoclist]

    set trg_file [open $trg_filename "w"]
    puts $trg_file $tclout
    close $trg_file
}

main
