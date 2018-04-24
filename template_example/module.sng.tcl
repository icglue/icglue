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

proc sng_name_to_icglue {name} {
    set nsp [split $name ":"]

    set nsp1 [lindex $nsp 0]

    if {[catch {set insp1 [ig::db::get_instances -name $nsp1]}] && [catch {set insp1 [ig::db::get_modules -name $nsp1]}]} {
        error "could not find module/instance for ${nsp1}"
    }

    if {[llength $nsp] > 1} {
        return "${insp1}->[lindex $nsp 1]"
    }

    return $insp1
}

set parse_sng_line_codemod  ""
set parse_sng_line_codelist {}

proc parse_sng_line {number line} {
    variable parse_sng_line_codemod
    variable parse_sng_line_codelist

    if {$parse_sng_line_codemod eq ""} {
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
        } elseif {[regexp {^[\s]*S:[\s]*([[:alnum:]_]+)(\[(.*):(.*)\])?[\s]*(\((.*)\))?[\s]*:=[\s]*([^ \t]+)[\s]*(<-|<->|->)(.*)} $line mline msig m_range m_rng_start m_rng_stop m_assign massign mstart marrow mtargets]} {
            set sig $msig
            set assign $massign
            set arrow $marrow
            set start $mstart
            set targets [split $mtargets " \t"]
            set targets [lsearch -inline -all -not $targets {}]
            if {$m_range eq ""} {
                set size 1
            } else {
                if {[string is integer $m_rng_start] && [string is integer $m_rng_stop]} {
                    set size [expr {$m_rng_start - $m_rng_stop + 1}]
                } elseif {[string is integer $m_rng_stop] && ($m_rng_stop == 0)} {
                    if {[string match "*-1" $m_rng_start]} {
                        set size [string range $m_rng_start 0 end-2]
                    } else {
                        set size "${m_rng_start}+1"
                    }
                } else {
                    error "could not parse range of signal $msig in line $number"
                }
            }
            return [list $number "signal" $sig $size $assign $arrow [sng_split_instances $start] [sng_split_instances $targets]]
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
            set modid [ig::db::create_module -resource -name $modname]
        } elseif {$ilm} {
            set modid [ig::db::create_module -ilm -name $modname]
        } else {
            set modid [ig::db::create_module -name $modname]
        }
        ig::db::set_attribute -object $modid -attribute "language" -value $lang
        ig::db::set_attribute -object $modid -attribute "mode"     -value $mode
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
                    ig::db::create_instance \
                        -name $inst_name \
                        -of-module [ig::db::get_modules -name $mod] \
                        -parent-module [ig::db::get_modules -name $parentmod] \
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
            if {[catch {lappend targets [sng_name_to_icglue $i_tr]}]} {
                error "line ${linenumber}: could not find module/instance for ${i_tr}"
            }
        }

        ig::db::parameter -targets $targets -name $name -value $value
    }

    # signals
    foreach i_sig [lsearch -all -inline -index 1 $parsed_lines "signal"] {
        set linenumber [lindex $i_sig 0]
        set name       [lindex $i_sig 2]
        set size       [lindex $i_sig 3]
        set assign     [lindex $i_sig 4]
        set arrow      [lindex $i_sig 5]
        set targets_raw_left  [lindex $i_sig 6]
        set targets_raw_right [lindex $i_sig 7]

        if {$arrow eq "->"} {
            set src_raw  $targets_raw_left
            set targets_raw $targets_raw_right
        } elseif {$arrow eq "<-"} {
            set src_raw  $targets_raw_right
            set targets_raw $targets_raw_left
        } elseif {$arrow eq "<->"} {
            set src_raw  {}
            set targets_raw [concat $targets_raw_left $targets_raw_right]
        } else {
            error "line ${linenumber}: invalid arrow: ${arrow}"
        }

        set targets [list]
        foreach i_tr $targets_raw {
            set i_tr [lindex $i_tr 1]
            if {[catch {lappend targets [sng_name_to_icglue $i_tr]}]} {
                error "line ${linenumber}: could not find module/instance for ${i_tr}"
            }
        }
        if {$arrow eq "<->"} {
            ig::db::connect -bidir $targets -signal-name $name -signal-size $size
        } else {
            if {[llength $src_raw] != 1} {
                error "line ${linenumber}: expected exactly 1 source of signal ${name}"
            } else {
                set src_raw [lindex $src_raw 0 1]
            }
            if {[catch {set src [sng_name_to_icglue $src_raw]}]} {
                error "line ${linenumber}: could not find module/instance for ${src_raw}"
            }
            ig::db::connect -from $src -to $targets -signal-name $name -signal-size $size
        }
    }

    # code
    foreach i_cs [lsearch -all -inline -index 1 $parsed_lines "code"] {
        set linenumber [lindex $i_cs 0]
        set mod        [lindex $i_cs 2]
        set code       [lindex $i_cs 3]

        if {[catch {set mod [ig::db::get_modules -name $mod]}]} {
            error "line ${linenumber}: could not find module for ${mod}"
        }

        ig::db::add_codesection -parent-module $mod -code "\n${code}\n"
    }
}

proc parse_sng_file {filename} {
    set f [open $filename "r"]
    set lines [split [read $f] "\n"]
    close $f

    set i 1
    set current ""
    set parsed [list]

    foreach i_l $lines {
        if {[string index $i_l end] eq "\\"} {
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
