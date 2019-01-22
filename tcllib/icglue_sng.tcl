
#
#   ICGlue is a Tcl-Library for scripted HDL generation
#   Copyright (C) 2017-2019  Andreas Dixius, Felix Neumärker
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

package provide ICGlue 3.0a1

## @brief Functions for sng-file processing
#
# Function for external usage is @ref parse_file.
namespace eval ig::sng {
    ## @brief Split sng instance expression into list of single instances.
    #
    # @param instances SNG instances expression
    #
    # @return List of sublists of form {\<module\> \<instance-with-signal-info\> \<icglue-instance-with-signal-info\>}.<br>
    # \<module\>: SNG module name.<br>
    # \<instance-with-signal-info\>: extended sng instance-with-signal name, e.g. "mod_a:signal_i".
    # \<instance-with-signal-info\>: extended icglue instance-with-signal name, e.g. "mod<a>:signal_i".
    proc split_instances {instances} {
        set result {}
        foreach i_e $instances {
            if {[regexp {^(.*)\[(.*)\](:.*)?} $i_e m_e m_mod m_insts m_rem]} {
                foreach i_inst [split $m_insts ","] {
                    if {[regexp {^([0-9]*)\.\.([0-9]*)$} $i_inst m_ie m_istart m_iend]} {
                        for {set i $m_istart} {$i <= $m_iend} {incr i} {
                            lappend result [list \
                                $m_mod \
                                "${m_mod}_${i}${m_rem}" \
                                "${m_mod}<${i}>${m_rem}" \
                            ]
                        }
                    } else {
                        lappend result [list \
                            $m_mod \
                            "${m_mod}_${i_inst}${m_rem}" \
                            "${m_mod}<${i_inst}>${m_rem}" \
                        ]
                    }
                }
            } else {
                set sp [split $i_e ":"]
                if {[llength $sp] > 1} {
                    lappend result [list [lindex $sp 0] $i_e $i_e]
                } else {
                    lappend result [list $i_e $i_e $i_e]
                }
            }
        }

        return $result
    }

    ## @brief Create ICGlue db identifier from single sng instance/signal identifier.
    #
    # @param name Preprocessed SNG identifier from @ref split_instances.
    #
    # @return ICGlue db command identifier.
    #
    # Tries to find an instance or module matching the identifier.
    proc sng_name_to_icglue {name} {
        set nsp [split $name ":"]

        set nsp1 [lindex $nsp 0]

        if {[catch {set insp1 [ig::db::get_instances -name $nsp1]}] && [catch {set insp1 [ig::db::get_modules -name $nsp1]}]} {
            error "could not find module/instance for ${nsp1}"
        }

        if {[llength $nsp] > 1} {
            return "${insp1}:[lindex $nsp 1]"
        }

        return $insp1
    }

    variable parse_sng_line_codemod  ""
    variable parse_sng_line_codelist {}

    ## @brief Incrementally parse lines of SNG-file.
    #
    # @param number Current linenumber.
    # @param line Current SNG Line content.
    #
    # @return Sublist for preprocessod lines list of form {\<number\> \<identifier\> ...}.
    proc parse_line {number line} {
        variable parse_sng_line_codemod
        variable parse_sng_line_codelist

        if {$parse_sng_line_codemod eq ""} {
            if {[regexp -expanded {
                    ^[\s]*
                    \#(.*)
                    $
                } $line mline mcomment]} {
                # comment
                return [list $number "comment" $mcomment]
            } elseif {[regexp -expanded {
                    ^[\s]*
                    //(.*)
                    $
                } $line mline mcomment]} {
                # comment
                return [list $number "comment" $mcomment]
            } elseif {[regexp -expanded {
                    ^[\s]*
                    $
                } $line mline]} {
                # blank line
                return [list $number "ignore"]
            } elseif {[regexp -expanded {
                    ^[\s]*
                    M:[\s]*
                    (([[:alnum:]_]+)[\s]*:[\s]*)?
                    ([[:alnum:]_]+)[\s]*
                    (\((.*)\))?[\s]*
                    (:=)?
                    ([^#/]+)?
                    ([#/]+.*)?
                    $
                } $line mline m_parent mparent mmodule m_args mmoduleargs massign minstances mcomment]} {
                # module/instance definition
                set args [split [string map {" " {} "\t" {}} $mmoduleargs] ","]
                set insts [split $minstances " \t"]
                set insts [lsearch -inline -all -not $insts {}]
                set parent [expr {($mparent ne "") ? $mparent : $mmodule}]
                return [list $number "module" $mmodule $parent $args [split_instances $insts]]
            } elseif {[regexp -expanded {
                    ^[\s]*
                    S:[\s]*
                    ([[:alnum:]_]+)
                    (\[(.*):(.*)\])?[\s]*
                    (\((.*)\))?[\s]*
                    :=[\s]*
                    ([^ \t]+)[\s]*
                    (<-|<->|->)
                    ([^#/]*)
                    ([#/]+.*)?
                    $
                } $line mline msig m_range m_rng_start m_rng_stop m_assign massign mstart marrow mtargets mcomment]} {
                # signal definition
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
                return [list $number "signal" $sig $size $assign $arrow [split_instances $start] [split_instances $targets]]
            } elseif {[regexp -expanded {
                    ^[\s]*
                    G:[\s]*
                    ([[:alnum:]_]+)[\s]*
                    (\((.*)\))?[\s]*
                    :=[\s]*
                    ([^ \t]+)[\s]*
                    (<-|<->|->)
                    ([^#/]*)
                    ([#/]+.*)?
                    $
                } $line mline mpar m_assign massign mstart marrow mtargets mcomment]} {
                # parameter definition
                set par $mpar
                set assign $massign
                set arrow $marrow
                set start $mstart
                set targets [split $mtargets " \t"]
                set targets [lsearch -inline -all -not $targets {}]
                return [list $number "parameter" $par $assign $arrow [split_instances $start] [split_instances $targets]]
            } elseif {[regexp {^[\s]*C:[\s]*([[:alnum:]_]+)[\s]*:=[\s]*begin} $line mline mmod]} {
                # code definition
                set parse_sng_line_codemod $mmod
                set parse_sng_line_codelist [list]
                return [list $number "ignore"]
            } else {
                error "could not parse line $number"
            }
        } else {
            if {[regexp -expanded {
                    ^[\s]*
                    C:[\s]*
                    ([[:alnum:]_]+)[\s]*
                    :=[\s]*
                    end
                } $line mline mmod]} {
                set mod $parse_sng_line_codemod
                set parse_sng_line_codemod ""
                return [list $number "code" $mod [join $parse_sng_line_codelist "\n"]]
            } else {
                lappend parse_sng_line_codelist $line
                return [list $number "ignore"]
            }
        }
    }

    ## @brief Process list of lines preparsed by @ref parse_line.
    #
    # @param parsed_lines List of parsed lines by @ref parse_line.
    proc evaluate_lines {parsed_lines} {
        # modules
        foreach i_mod [lsearch -all -inline -index 1 $parsed_lines "module"] {
            set linenumber [lindex $i_mod 0]
            set modname    [lindex $i_mod 2]
            set parent     [lindex $i_mod 3]
            set modargs    [lindex $i_mod 4]

            set lang "verilog"
            set mode "rtl"

            set ilm      "false"
            set resource "false"
            foreach i_arg $modargs {
                switch $i_arg {
                    "verilog"       {set lang $i_arg}
                    "v"             {set lang "verilog"}
                    "vhdl"          {set lang $i_arg}
                    "systemverilog" {set lang $i_arg}
                    "sv"            {set lang "systemverilog"}
                    "rtl"           {set mode $i_arg}
                    "tb"            {set mode $i_arg}
                    "behavioral"    {set mode $i_arg}
                    "ilm"           {set ilm      "true"}
                    "resource"      {set resource "true"}
                    default         {error "line ${linenumber}: could not parse module args"}
                }
            }
            if {[catch {
                    if {$resource} {
                        set modid [ig::db::create_module -resource -name $modname]
                    } elseif {$ilm} {
                        set modid [ig::db::create_module -ilm -name $modname]
                    } else {
                        set modid [ig::db::create_module -name $modname]
                    }
                    ig::db::set_attribute -object $modid -attribute "language"   -value $lang
                    ig::db::set_attribute -object $modid -attribute "mode"       -value $mode
                    ig::db::set_attribute -object $modid -attribute "parentunit" -value $parent
                }]} {
                error "line ${linenumber}: could not create module for ${modname}"
            }
        }

        # instances
        foreach i_mod [lsearch -all -inline -index 1 $parsed_lines "module"] {
            set linenumber [lindex $i_mod 0]
            set parentmod  [lindex $i_mod 2]
            set insts      [lindex $i_mod 5]
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

            if {[catch {
                    ig::db::parameter -targets $targets -name $name -value $value
                }]} {
                error "line ${linenumber}: G: failed to create parameter"
            }
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
            if {[catch {
                    if {$arrow eq "<->"} {
                        ig::db::connect -bidir $targets -signal-name $name -signal-size $size
                    } else {
                        if {[llength $src_raw] != 1} {
                            error "line ${linenumber}: expected exactly 1 source of signal ${name}"
                        } else {
                            set src_mod [lindex $src_raw 0 0]
                            set src_raw [lindex $src_raw 0 1]
                        }
                        if {[catch {set src [sng_name_to_icglue $src_raw]}]} {
                            error "line ${linenumber}: could not find module/instance for ${src_raw}"
                        }
                        ig::db::connect -from $src -to $targets -signal-name $name -signal-size $size

                        if {$assign ne ""} {
                            ig::log -debug "sng signal assignment: get module..."
                            set mod [ig::db::get_modules -name $src_mod]
                            ig::log -debug "sng signal assignment: add codesection..."
                            set cs [ig::db::add_codesection -parent-module $mod -code "    assign ${name}! = ${assign};\n"]
                            ig::log -debug "sng signal assignment: add codesection attributes..."
                            ig::db::set_attribute -object $cs -attribute "adapt" -value "selective"
                            ig::log -debug "sng signal assignment: ...done"
                        }
                    }
                }]} {
                error "line ${linenumber}: S: failed to connect"
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

            if {[catch {ig::db::add_codesection -parent-module $mod -code "\n${code}\n"}]} {
                error "line ${linenumber}: C: failed to create codesection"
            }
        }
    }

    ## @brief Create module tree command from list of module-lines preparsed by @ref parse_line.
    #
    # @param mod_lines List of parsed lines containing module commands.
    # @return List of lines of generated module-tree commands.
    proc convert_modules {mod_lines} {
        set mod_trees [dict create]
        set mod_standa {}

        set timeout [llength $mod_lines]

        while {[llength $mod_lines] > 0} {
            set modname [lindex $mod_lines 0 2]
            set unit    [lindex $mod_lines 0 3]
            set modargs [lindex $mod_lines 0 4]
            set insts   [lindex $mod_lines 0 5]

            set insts_valid "true"
            foreach i_inst $insts {
                set inst_mod [lindex $i_inst 0]
                if {![dict exists $mod_trees $inst_mod]} {
                    set insts_valid "false"
                    break
                }
            }

            # try next
            if {! $insts_valid} {
                # rotate
                set first [lindex $mod_lines 0]
                set mod_lines [lrange $mod_lines 1 end]
                lappend mod_lines $first

                # timeout check
                incr timeout -1
                if {$timeout == 0} {
                    ig::log -error "could not create module tree"
                    return {}
                }
                continue
            }

            # process tree
            set mtree {}
            if {[llength $insts] > 0} {
                lappend mtree {|}
                foreach i_inst $insts {
                    set inst_mod [lindex $i_inst 0]
                    set inst_data [dict get $mod_trees $inst_mod]

                    set args [dict get $inst_data "args"]
                    if {![dict get $inst_data "res"]} {
                        set iunit [dict get $inst_data "unit"]
                        if {$iunit ne $unit} {
                            lappend args "unit=${iunit}"
                        }
                    }

                    if {[llength $args] > 0} {
                        lappend mtree "+-- [lindex $i_inst 2] .. ([join $args ","])"
                    } else {
                        lappend mtree "+-- [lindex $i_inst 2]"
                    }

                    if {[lindex $insts end] eq $i_inst} {
                        set bar " "
                    } else {
                        set bar "|"
                    }

                    foreach item [dict get $inst_data "tree"] {
                        if {[string length $item] > 0} {
                            lappend mtree "${bar}   $item"
                        } else {
                            if {$bar ne " "} {
                                lappend mtree "${bar}"
                            } else {
                                lappend mtree {}
                            }
                        }
                    }

                    set idx [lsearch $mod_standa $inst_mod]
                    if {$idx >= 0} {
                        set mod_standa [lreplace $mod_standa $idx $idx]
                    }
                }
                lappend mtree {}
            }

            # args
            set args {}
            set res  "false"
            foreach i_arg $modargs {
                switch $i_arg {
                    "verilog"       -
                    "v"             {}
                    "vhdl"          {lappend args "vhdl"}
                    "systemverilog" -
                    "sv"            {lappend args "sv"}
                    "rtl"           {
                                        # although rtl is default, printing it is comfortable in case of adding flags like "rf" or "unit"
                                        lappend args "rtl"
                                    }
                    "tb"            {lappend args "tb"}
                    "behavioral"    {lappend args "behavioral"}
                    "ilm"           {lappend args "ilm"}
                    "resource"      {
                                        lappend args "res"
                                        set res "true"
                                    }
                    default         {}
                }
            }

            dict set mod_trees $modname "args" $args
            dict set mod_trees $modname "tree" $mtree
            dict set mod_trees $modname "res"  $res
            dict set mod_trees $modname "unit" $unit

            lappend mod_standa $modname

            # next
            set mod_lines [lrange $mod_lines 1 end]
        }

        set result {}

        # return
        foreach i_mod $mod_standa {
            set mtree {}
            set mod_data [dict get $mod_trees $i_mod]
            lappend mtree "$i_mod ... ([join [dict get $mod_data "args"] ","])"
            lappend mtree {*}[dict get $mod_data "tree"]

            set unit [dict get $mod_data "unit"]
            if {$unit eq {}} {
                set unit $i_mod
            }

            lappend result "M -unit \"${unit}\" -tree \{"

            # fill dots
            set midx 0
            foreach item $mtree {
                set midx [expr {max([string first "(" $item], $midx)}]
            }

            foreach item $mtree {
                set idx [string first "(" $item]
                if {$idx < $midx} {
                    set item [string replace $item [expr {$idx - 2}] [expr {$idx - 2}] [string repeat "." [expr {$midx - $idx + 1}]]]
                }

                if {$item ne ""} {
                    lappend result "    $item"
                } else {
                    lappend result {}
                }
            }
            lappend result "\}"
            lappend result {}
        }

        return $result
    }

    ## @brief Create construction command from a line preparsed by @ref parse_line.
    #
    # @param line parsed line containing icsng command.
    # @return Line of generated icglue construction command or comment.
    proc convert_other {line} {
        set type [lindex $line 1]

        if {$type eq "comment"} {
            set txt [lindex $line 2]
            if {[string index [string trimleft $txt] 0] ne "#"} {
                set txt "#${txt}"
            }
            return $txt
        } elseif {$type eq "ignore"} {
            return {}
        } elseif {$type eq "signal"} {
            set sig  [lindex $line 2]
            set size [lindex $line 3]
            set val  [lindex $line 4]
            set arr  [lindex $line 5]
            set ilft [lindex $line 6]
            set irgt [lindex $line 7]

            set cmd "S"

            append cmd " \"${sig}\""
            if {$size > 1} {
                if {[string is integer $size]} {
                    append cmd " -w [list $size]"
                } else {
                    append cmd " -w {[list $size]}"
                }
            }

            if {$val ne ""} {
                append cmd " = [list $val]"
            }

            foreach iinst $ilft {
                append cmd " [lindex $iinst 2]"
            }
            if {$arr eq "->"} {
                set arr "-->"
            } elseif {$arr eq "<-"} {
                set arr "<--"
            }
            append cmd " ${arr}"

            foreach iinst $irgt {
                append cmd " [lindex $iinst 2]"
            }

            return $cmd
        } elseif {$type eq "parameter"} {
            set par  [lindex $line 2]
            set val  [lindex $line 3]
            set ilft [lindex $line 5]
            set irgt [lindex $line 6]

            set cmd "P"
            append cmd " ${par}"
            if {$val ne ""} {
                append cmd " = [list $val]"
            }
            foreach iinst [concat $ilft $irgt] {
                append cmd " \"[lindex $iinst 2]\""
            }

            return $cmd
        } elseif {$type eq "code"} {
            set mod  [lindex $line 2]
            set code "\n[lindex $line 3]\n"

            set cmd "C -verbatim"
            append cmd " ${mod}"
            append cmd " "
            append cmd [list $code]

            return $cmd
        } else {
            return {}
        }
    }

    ## @brief Convert list of lines preparsed by @ref parse_line into list of lines for a construction script.
    #
    # @param parsed_lines List of parsed lines by @ref parse_line.
    # @return List of lines for construction script.
    proc convert {parsed_lines} {
        set result {}

        lappend result "#!/usr/bin/env icglue"
        lappend result {}
        lappend result "# icglue file converted from icsng"
        lappend result {}

        set mod_lines [lsearch -all -inline -index 1 $parsed_lines "module"]
        set rem_lines [lsearch -all -inline -index 1 -not $parsed_lines "module"]
        set pre_lines [list]

        if {[llength $mod_lines] > 0} {
            set first_mod_line [lindex $mod_lines 0 0]
        } else {
            set first_mod_line 0
        }

        for {set i 0} {$i < [llength $rem_lines]} {incr i} {
            set line [lindex $rem_lines $i 0]
            set type [lindex $rem_lines $i 1]

            if {$line >= $first_mod_line} {
                set pre_lines [lrange $rem_lines 0 [expr {$i - 1}]]
                set rem_lines [lrange $rem_lines $i end]
                break
            }

            if {($type ne "comment") && ($type ne "ignore")} {
                # more than comment/empty before first module command
                break
            }
        }

        foreach i_line $pre_lines {
            lappend result [convert_other $i_line]
        }

        lappend result {*}[convert_modules $mod_lines]

        foreach i_line $rem_lines {
            lappend result [convert_other $i_line]
        }

        return $result
    }

    ## @brief Parse SNG file.
    #
    # @param filename Filename of SNG file.
    proc parse_file {filename} {
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
                lappend parsed [parse_line $i $current]
                set current ""
            }
            incr i
        }

        return $parsed
    }

    ## @brief Parse and process SNG file.
    #
    # @param filename Filename of SNG file.
    proc evaluate_file {filename} {
        set parsed [parse_file $filename]

        evaluate_lines $parsed
    }

    ## @brief Parse and convert SNG file into icglue script.
    #
    # @param in_filename Filename of SNG file.
    # @param out_filename Filename of icglue script.
    proc convert_file {in_filename out_filename} {
        set parsed [parse_file $in_filename]

        # for check + pragma-update
        evaluate_lines $parsed

        set outlines [convert $parsed]

        set f [open $out_filename "w"]
        ig::log -info -id "SNGCv" "Generating icglue construction script $out_filename"
        puts $f [join $outlines "\n"]
        close $f
    }

    ## @brief Parse sng pragmas in existing module file and insert icglue template keep blocks
    #
    # @param modid Object ID of module to process
    # @param projdir Root-directory of project - file lookup for pragma replacement starts there.
    proc update_file_pragmas {modid {projdir .}} {

        set name [ig::db::get_attribute -object $modid -attribute "name"]
        set unit [ig::db::get_attribute -object $modid -attribute "parentunit" -default $name]
        set mode [ig::db::get_attribute -object $modid -attribute "mode" -default "rtl"]

        set path [file join $projdir "units" $unit "source/$mode/verilog" "${name}.v"]
        if {![file exists $path]} {
            return
        }

        ig::log -info -id "SNGCv" "Converting SNG pragmas of file $path"

        set f [open $path "r"]
        set vlog [read $f]
        close $f

        set icg_blocks [ig::templates::parse_keep_blocks $vlog ".v"]
        if {[llength $icg_blocks] > 0} {
            ig::log -warn -id "SNGCv" "Module $name: file $path already contains icglue keep blocks... skipping."
            return
        }

        set vlogl [split $vlog "\n"]
        set vlogl [linsert $vlogl -1 "/* icglue keep begin head */"]

        set sng_pragma_data {
            "// pragma ICSNG %%sng_verilog_module_begin%%"    "/* icglue keep end */"
            "// pragma ICSNG %%sng_verilog_module_end%%"      "    /* icglue keep begin declarations */"
            "// pragma ICSNG %%sng_verilog_instances_begin%%" "    /* icglue keep end */"
            "// pragma ICSNG %%sng_verilog_instances_end%%"   "    /* icglue keep begin instances */"
            "// pragma ICSNG %%sng_verilog_code_begin%%"      "    /* icglue keep end */"
            "// pragma ICSNG %%sng_verilog_code_end%%"        "    /* icglue keep begin code */"
            "endmodule"                                       "    /* icglue keep end */\n\nendmodule"
        }

        foreach {ipragma irepl} $sng_pragma_data {
            set idx [lsearch $vlogl $ipragma]
            if {$idx < 0} {
                ig::log -warn -id "SNGCv" "Module $name: file $path does not contain expected \"${ipragma}\"... skipping."
                return
            }

            lset vlogl $idx $irepl
        }

        set f [open $path "w"]
        puts $f [join $vlogl "\n"]
        close $f
    }

    namespace export evaluate_file convert_file update_file_pragmas
}

