#!/usr/bin/tclsh

proc sng_split_instances {instances} {
    set result {}
    foreach i_e $instances {
        if {[regexp {^(.*)\[(.*)\](:.*)?} $i_e m_e m_mod m_insts m_rem]} {
            foreach i_inst [split $m_insts ","] {
                if {[regexp {^([0-9]*)\.\.([0-9]*)$} $i_inst m_ie m_istart m_iend]} {
                    for {set i $m_istart} {$i <= $m_iend} {incr i} {
                        lappend result [list \
                            $m_mod \
                            "${m_mod}_${i}${m_rem}" \
                        ]
                    }
                } else {
                    lappend result [list \
                        $m_mod \
                        "${m_mod}_${i_inst}${m_rem}" \
                    ]
                }
            }
        } else {
            set sp [split $i_e ":"]
            if {[llength $sp] > 1} {
                lappend result [list [lindex $sp 0] $i_e]
            } else {
                lappend result [list $i_e $i_e]
            }
        }
    }

    return $result
}

set parse_sng_line_codemod  ""
set parse_sng_line_codelist {}

proc parse_sng_line {number line} {
    variable parse_sng_line_codemod
    variable parse_sng_line_codelist

    if {$parse_sng_line_codemod == ""} {
        if {[regexp {^[\s]*#(.*)$} $line mline mcomment]} {
            return [list $number "comment" $mcomment]
        } elseif {[regexp {^[\s]*//(.*)$} $line mline mcomment]} {
            return [list $number "comment" $mcomment]
        } elseif {[regexp {^[\s]*M:[\s]*([[:alnum:]_]+)[\s]*(\((.*)\))?[\s]*:=([^#/]+)?$} $line mline mmodule m_args mmoduleargs minstances]} {
            set args [split [string map {" " {} "\t" {}} $mmoduleargs] ","]
            set insts [split $minstances " \t"]
            set insts [lsearch -inline -all -not $insts {}]
            return [list $number "module" $mmodule $args [sng_split_instances $insts]]
        } elseif {[regexp {^[\s]*S:[\s]*([[:alnum:]_]+)[\s]*(\((.*)\))?[\s]*:=[\s]*([^ \t]+)[\s]*(<-|<->|->)(.*)} $line mline msig m_assign massign mstart marrow mtargets]} {
            set sig $msig
            set assign $massign
            set arrow $marrow
            set start $mstart
            set targets [split $mtargets " \t"]
            set targets [lsearch -inline -all -not $targets {}]
            return [list $number "signal" $sig $assign $arrow [sng_split_instances $start] [sng_split_instances $targets]]
        } elseif {[regexp {^[\s]*G:[\s]*([[:alnum:]_]+)[\s]*(\((.*)\))?[\s]*:=[\s]*([^ \t]+)[\s]*(<-|<->|->)(.*)} $line mline mpar m_assign massign mstart marrow mtargets]} {
            set sig $msig
            set assign $massign
            set arrow $marrow
            set start $mstart
            set targets [split $mtargets " \t"]
            set targets [lsearch -inline -all -not $targets {}]
            return [list $number "signal" $sig $assign $arrow [sng_split_instances $start] [sng_split_instances $targets]]
        } elseif {[regexp {^[\s]*C:[\s]*([[:alnum:]_]+)[\s]*:=[\s]*begin} $line mline mmod]} {
            set parse_sng_line_codemod $mmod
            set parse_sng_line_codelist [list]
            return [list $number "ignore"]
        } else {
            error "could not parse line $number"
        }
    } else {
        if {[regexp {^[\s]*C:[\s]*([[:alnum:]_]+)[\s]*:=[\s]*end} $line mline mmod]} {
            set mod $parse_sng_line_codemod
            set parse_sng_line_codemod ""
            return [list $number "code" $mod [join $parse_sng_line_codelist "\n"]]
        } else {
            lappend parse_sng_line_codelist $line
            return [list $number "ignore"]
        }
    }
}

proc parse_sng_file {filename} {
    set f [open $filename "r"]
    set lines [split [read $f] "\n"]
    close $f

    set i 1
    set current ""
    set parsed {}

    foreach i_l $lines {
        if {[string index $i_l end] == "\\"} {
            set current "${current}[string range $i_l 0 end-1]"
        } else {
            set current "${current}${i_l}"
            lappend parsed [parse_sng_line $i $current]
            set current ""
        }
        incr i
    }
}
