#!/usr/bin/tclsh

load ../lib/icglue.so

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
        } elseif {[regexp {^[\s]*$} $line mline]} {
            return [list $number "ignore"]
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
            set par $mpar
            set assign $massign
            set arrow $marrow
            set start $mstart
            set targets [split $mtargets " \t"]
            set targets [lsearch -inline -all -not $targets {}]
            return [list $number "parameter" $par $assign $arrow [sng_split_instances $start] [sng_split_instances $targets]]
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

proc evaluate_sng_lines {parsed_lines} {
    # modules
    foreach i_mod [lsearch -all -inline -index 1 $parsed_lines "module"] {
        set linenumber [lindex $i_mod 0]
        set modname    [lindex $i_mod 2]
        set modargs    [lindex $i_mod 3]

        set lang "verilog"
        set mode "rtl"

        set ilm      "false"
        set resource "false"
        foreach i_arg $modargs {
            switch $i_arg {
                "verilog"       {set lang $i_arg}
                "vhdl"          {set lang $i_arg}
                "systemverilog" {set lang $i_arg}
                "rtl"           {set mode $i_arg}
                "tb"            {set mode $i_arg}
                "behavioral"    {set mode $i_arg}
                "ilm"           {set ilm      "true"}
                "resource"      {set resource "true"}
                default         {error "line ${linenumber}: could not parse module args"}
            }
        }
        if {$resource} {
            set modid [create_module -resource -name $modname]
        } elseif {$ilm} {
            set modid [create_module -ilm -name $modname]
        } else {
            set modid [create_module -name $modname]
        }
        set_attribute -object $modid -attribute "language" -value $lang
        set_attribute -object $modid -attribute "mode"     -value $mode
    }

    # instances
    foreach i_mod [lsearch -all -inline -index 1 $parsed_lines "module"] {
        set linenumber [lindex $i_mod 0]
        set parentmod  [lindex $i_mod 2]
        set insts      [lindex $i_mod 4]
        foreach i_inst $insts {
            set mod       [lindex $i_inst 0]
            set inst_name [lindex $i_inst 1]

            if {[catch {\
                    create_instance \
                        -name $inst_name \
                        -of-module [get_modules -name $mod] \
                        -parent-module [get_modules -name $parentmod] \
                }]} {
                error "line ${linenumber}: could not create instance for ${mod}"
            }
        }
    }

    # parameter
    foreach i_param [lsearch -all -inline -index 1 $parsed_lines "parameter"] {
        set linenumber [lindex $i_param 0]
        set name       [lindex $i_param 2]
        set value      [lindex $i_param 3]
        set targets    [list]
        set targets_raw [concat [lindex $i_param 5] [lindex $i_param 6]]
        foreach i_tr $targets_raw {
            set i_tr [lindex $i_tr 1]
            if {![catch {set i_t [get_instances -name $i_tr]}]} {
                lappend targets ${i_t}
            } elseif {![catch {set i_t [get_modules -name $i_tr]}]} {
                lappend targets ${i_t}
            } else {
                error "line ${linenumber}: could find module/instance for ${i_tr}"
            }
        }

        parameter -targets $targets -name $name -value $value
    }

    # TODO: code, signals
}

proc parse_sng_file {filename} {
    set f [open $filename "r"]
    set lines [split [read $f] "\n"]
    close $f

    set i 1
    set current ""
    set parsed [list]

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

    evaluate_sng_lines $parsed
}
