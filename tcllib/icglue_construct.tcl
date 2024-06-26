
#
#   ICGlue is a Tcl-Library for scripted HDL generation
#   Copyright (C) 2017-2020  Andreas Dixius, Felix Neumärker
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

package provide ICGlue 5.0a1

## @brief Main namespace of ICGlue.
# Contains functionality needed in construction scripts.
namespace eval ig {
    ## @brief Construction helpers.
    namespace eval construct {
        ## @brief Expand instance expression list.
        #
        # @param inst_list List of instance expressions.
        # @param ids Return instance object IDs instead of names (default: false).
        # @param merge (Only in combination with ids=true) Return list of merged expressions with IDs and originial expression remainder (default: false).
        # @param num_separator separator between module name and instance suffix for instanciation.
        #
        # @return List of expanded instance expressions {instance-name module-name remainder inverted}.
        #
        # The input list can contain expressions of the form ~module\<instance1,instance2\>:signal.
        # The default result would then contain two lists: {~module_instance1 module:signal} and {~module_instance2 module:signal}.
        #
        # If ids is set, the object ids of module and instance will be returned.
        # If there is no instance of the given instance-name to be found, a module id will be looked up.
        # If merge is set as well, the result-list will be reduced to a single entry for each instance of the form [~]${id}:signal.
        proc expand_instances {inst_list {ids false} {merge false} {num_separator "_"}} {
            set result [list]

            foreach i_entry $inst_list {
                if {[regexp -expanded {
                    ^
                    ([~]?)
                    ([^<>:]+)
                    (<(.*)>)?
                    (:[^\s]+)?
                    $
                } $i_entry m_entry m_inv m_module m_instwrap m_insts m_rem]} {
                    if {$m_instwrap eq ""} {
                        lappend result [list $m_module $m_module $m_rem $m_inv]
                    } else {
                        foreach i_sfx [split $m_insts ","] {
                            set expand_range "true"
                            set insts [list [string trim $i_sfx]]
                            while {$expand_range} {
                                set insts_new {}
                                set expand_range "false"
                                foreach i_inst $insts {
                                    if {[regexp {^(\w*?)(\d+)\.\.(\d+)([[:alnum:]_.]*?)$} $i_inst m_whole m_prefix m_start m_stop m_suffix]} {
                                        # swap if start > stop
                                        if {$m_start > $m_stop} {lassign [list $m_start $m_stop] m_stop m_start}

                                        for {set i $m_start} {$i <= $m_stop} {incr i} {
                                            lappend insts_new "${m_prefix}${i}${m_suffix}"
                                        }
                                        set expand_range "true"
                                    } else {
                                        lappend insts_new $i_inst
                                    }
                                }
                                set insts $insts_new
                            }

                            foreach i_sfx $insts {
                                lappend result [list "${m_module}${num_separator}${i_sfx}" $m_module $m_rem $m_inv]
                            }
                        }
                    }
                } else {
                    error "ig::construct::expand_instances: could not parse $i_entry (arg \$inst_list =  $inst_list)"
                }
            }

            if {$ids} {
                set result_ids [list]

                foreach i_r $result {
                    set inst [lindex $i_r 0]
                    if {[catch {set inst_id [ig::db::get_instances -name $inst]}]} {
                        set inst_id [ig::db::get_modules -name $inst]
                    }
                    if {$merge} {
                        lappend result_ids "[lindex $i_r 3]${inst_id}[lindex $i_r 2]"
                    } else {
                        lappend result_ids [list \
                            $inst_id \
                            [ig::db::get_modules -name [lindex $i_r 1]] \
                            [lindex $i_r 2] \
                            [lindex $i_r 3]
                        ]
                    }
                }

                set result $result_ids
            }

            return $result
        }

        ## @brief Common proc to parse module/rf attribute string in module tree
        #
        # @param attrstring list of 'attribute=>value' pairs, with semicolon as a pair separator.
        #
        # @return a dictionary containing the attribute key value pairs.
        proc parse_modcmd_attributes {attrstring} {
            ig::log -debug -id "Mattr" "Parsing '${attrstring}'"
            set attributes {}
            foreach attrlist $attrstring {
                set attrlist [ig::aux::remove_brackets $attrlist]
                foreach pair [split $attrlist ";"] {
                    set pair [string trim $pair]
                    if {$pair ne {}} {
                        dict set attributes {*}[split [regsub -all {=>} $pair {=}] "="]
                    }
                }
            }

            return $attributes
        }

        ## @brief Common proc to parse and set attributes
        #
        # @param object ID of target object
        # @param attributes dict of attribute key value pairs
        proc set_modcmd_attributes {object attributes} {
            ig::log -debug -id "Mattr" "setting attributes '${attributes}' for $object"
            set userdata [dict create "object" $object "attributes" $attributes]

            ig::templates::current::template_attr $userdata
        }

        ## @brief Parse module instance tree
        #
        # @param instance_tree instance tree string to parse
        # @param origin script line origin to output when logging
        #
        # @return Stride list of parsed modules/instances of form name parent flags ...
        proc mtree_parse {instance_tree {origin {}}} {
            set instance_tree [regsub -all -lineanchor -linestop {#.*$} $instance_tree {}]
            set instance_tree [uplevel 2 subst -nobackslashes [list $instance_tree]]
            set instance_tree [split $instance_tree "\n"]

            set cur_parent {}
            set cur_level {}
            set parents_stack {}
            set level_stack {}
            set last_instance {}
            set module_list {}
            set maxlen_modname 0

            foreach inst $instance_tree {
                # remove spaces of list
                set m_level {}
                set m_instance {}
                set m_flags {}

                if {[regexp -expanded {
                    # Match level dots
                    ^([^a-zA-Z(]*)
                    # Match instance_name
                    ([a-zA-Z][^(]*)\s*
                    # Match flags
                    (\((.*)\))?
                    # remaining line
                    \s*
                    (\#.*)?
                    $
                    } $inst m_whole m_level m_instance m_flags_full m_flags m_comment]} {
                    # MATCH
                } elseif {[regexp -expanded {
                    # Match level dots
                    ^([^a-zA-Z(]*)
                    # Match flags
                    \((.*)\)\s*
                    # Match instance_name
                    ([a-zA-Z][^(]*)
                    # remaining line
                    \s*
                    (\#.*)?
                    $
                    } $inst m_whole m_level m_flags m_instance m_comment]} {
                    # MATCH
                } elseif {[string match {*[a-zA-Z0-9()]*} $inst]} {
                    ig::log -error -abort "M: Can't parse instance_name - syntax error in instance tree \"${inst}\" ($origin)"
                } else {
                    continue
                }

                set level [string length $m_level]
                if {[string first "#" $m_instance] == 0 } {continue}
                set m_instance [string trim $m_instance " \t."]
                set len_modname [string length $m_instance]
                if {$len_modname > $maxlen_modname} {
                    set maxlen_modname $len_modname
                }

                if {$level != 0  && $len_modname == 0} {
                    ig::log -error -abort "M: Can't match instance_name - syntax error in instance tree \"${inst}\" ($origin)"
                }

                if {$level > $cur_level} {
                    # one level up
                    lappend parents_stack $last_instance
                    lappend level_stack $level

                    set cur_parent $last_instance
                    set cur_level  $level
                    set last_instance $m_instance
                } elseif {$level < $cur_level} {
                    # pop levels down
                    set level_stack_size [llength $level_stack]
                    for {set keep_idx 0} {$keep_idx<$level_stack_size} {incr keep_idx} {
                        if {[lindex $level_stack $keep_idx] > $level} {
                            incr keep_idx -1
                            break;
                        }
                    }
                    # reduce level
                    set level_stack [lrange $level_stack 0 $keep_idx]

                    # append new level if not matching
                    if {[lindex $level_stack $keep_idx] != $level} {
                        lappend level_stack $level
                        incr keep_idx 1
                    }
                    set last_instance $m_instance

                    set parents_stack [lrange $parents_stack 0 $keep_idx]
                    set cur_parent [lindex $parents_stack end]
                    set cur_level [lindex $level_stack end]
                } else {
                    set last_instance $m_instance
                }

                lappend module_list $m_instance $cur_parent $m_flags
            }

            foreach {instance_name moduleparent moduleflags} $module_list {
                ig::log -id "MTree" -debug [format "module: %-*s -- parent: %-*s -- Flags: %s" $maxlen_modname $instance_name $maxlen_modname $moduleparent $moduleflags]
            }

            return $module_list
        }

        ## @brief Create modules of parsed instance/module tree
        #
        # @param module_list module list parsed by @ref mtree_parse
        # @param origin script line origin to output when logging
        #
        # @return generated module's ids
        proc mtree_process_modules {module_list {origin {}}} {
            set module_inc_list {}
            set modids {}

            foreach {instance_name moduleparent moduleflags} $module_list {
                set module_name   [lindex [split $instance_name <] 0]

                set film "false"
                set fres "false"
                set finc "false"
                set moduleflags [regsub -all {\s+} ${moduleflags} {}]
                ig::aux::parse_opts [list                    \
                    { {^(ilm|macro)$} "const=true" film {} } \
                    { {^res(ource)?$} "const=true" fres {} } \
                    { {^inc(lude)?$}  "const=true" finc {} } \
                    ] [split $moduleflags ","]

                set cf [list ]
                if {$fres} {
                    lappend cf "-resource"
                }
                if {$film} {
                    lappend cf "-ilm"
                }
                if {$finc} {
                    lappend module_inc_list $module_name
                }

                if {[catch {ig::db::get_modules -name $module_name}]} {
                    ig::log -debug -id MTree "M (module = $module_name): creating..."
                    set modid [ig::db::create_module {*}$cf -name $module_name]
                    ig::db::set_attribute -object $modid -attribute "origin" -value $origin
                    lappend modids $modid
                } else {
                    if {!$fres && !$finc} {
                        if {[lsearch $module_inc_list $module_name] == 0} {
                            ig::log -error -abort "M (module = $module_name): exists multiple times and is neither resource nor included. ($origin)"
                        }
                    }
                }
            }

            return $modids
        }

        ## @brief process instances, register files and attributes of parsed module/instance tree
        #
        # @param module_list module list parsed by @ref mtree_parse
        # @param unit default parent unit name
        # @param mode default mode attribute
        # @param lang default language attribute
        # @param origin script line origin to output when logging
        proc mtree_process_insts_rfs {module_list unit mode lang {origin {}}} {
            foreach {instance_name moduleparent moduleflags} $module_list {
                set funit $unit
                set film "false"
                set fres "false"
                set finc "false"
                set fmode $mode
                set flang $lang
                set fdummy "false"
                set fattributes   {}
                set frfattributes {}
                set frfaddrbits   32
                set frfdatabits   32
                set frfaddralign  {}
                set fregfile      "false"
                set fregfilename  {}
                set fotypes       ""
                set frfotypes     ""

                if {$moduleparent ne ""} {
                    set ppunit [ig::db::get_attribute -object [ig::db::get_modules -name $moduleparent] -attribute "parentunit" -default ""]
                    if {$ppunit ne ""} {
                        set funit $ppunit
                    }
                }

                set moduleflags [regsub -all {([^\\]),\s*} $moduleflags "\\1\n"]
                set funknown [ig::aux::parse_opts [list                                        \
                    { {^u(nit)?(=|$)}                     "string"              funit         {} }  \
                    { {^(ilm|macro)$}                     "const=true"          film          {} }  \
                    { {^res(ource)?$}                     "const=true"          fres          {} }  \
                    { {^(dummy)$}                         "const=true"          fdummy        {} }  \
                                                                                                    \
                    { {^inc(lude)?$}                      "const=true"          finc          {} }  \
                    { {^rtl$}                             "const=rtl"           fmode         {} }  \
                    { {^beh(av(ioral|ioural)?)?$}         "const=behavioral"    fmode         {} }  \
                    { {^(tb|testbench)$}                  "const=tb"            fmode         {} }  \
                                                                                                    \
                    { {^v(erilog)?$}                      "const=verilog"       flang         {} }  \
                    { {^sv|-s(ystemverilog)?$}            "const=systemverilog" flang         {} }  \
                    { {^vhd(l)?$}                         "const=vhdl"          flang         {} }  \
                    { {^systemc$}                         "const=systemc"       flang         {} }  \
                                                                                                    \
                    { {^(rf|(regf(ile)?)?)$}              "const=true"          fregfile      {} }  \
                    { {^(rf|(regf(ile)?)?)=}              "string"              fregfilename  {} }  \
                                                                                                    \
                    { {^attr(ibutes?)?(=|$)}              "list"                fattributes   {} }  \
                    { {^rfattr(ibutes?)?(=|$)}            "list"                frfattributes {} }  \
                    { {^rfa(ddr(ess)?)?w(idth)?(=|$)}     "integer"             frfaddrbits   {} }  \
                    { {^rfa(ddr(ess)?)?align(ment)?(=|$)} "integer"             frfaddralign  {} }  \
                    { {^rfd(ata)?w(idth)?(=|$)}           "integer"             frfdatabits   {} }  \
                                                                                                    \
                    { {^o(ut)?(typ(es)?|tags)(=|$)}       "string"              fotypes       {} }  \
                    { {^rfo(ut)?(typ(es)?|tags)(=|$)}     "string"              frfotypes     {} }  \
                    ] [split $moduleflags "\n"]]

                if {[llength $funknown] != 0} {
                    ig::log -abort -error -id MTree "M (instance $instance_name): Unknown flag(s) - $funknown ($origin)"
                }

                set module_name [lindex [split $instance_name <] 0]
                set modid [ig::db::get_modules -name $module_name]
                if {!$finc} {
                    if {$funit ne ""} {
                        ig::db::set_attribute -object $modid -attribute "parentunit" -value $funit
                    }
                    if {$fmode ne ""} {
                        ig::db::set_attribute -object $modid -attribute "mode"       -value $fmode
                    }
                    if {$flang ne ""} {
                        ig::db::set_attribute -object $modid -attribute "language"   -value $flang
                    }
                    if {$fregfile || ($fregfilename ne "")} {
                        if {$fregfilename eq ""} {
                            set fregfilename $module_name
                        }
                        set rfid [ig::db::add_regfile -regfile $fregfilename -to $modid]
                        if {$frfaddralign eq {}} {
                            set frfaddralign [expr {$frfdatabits / 8}]
                        }
                        ig::db::set_attribute -object $rfid -attribute "origin" -value $origin
                        ig::db::set_attribute -object $rfid -attribute "addrwidth" -value $frfaddrbits
                        ig::db::set_attribute -object $rfid -attribute "addralign" -value $frfaddralign
                        ig::db::set_attribute -object $rfid -attribute "datawidth" -value $frfdatabits
                        ig::db::set_attribute -object $rfid -attribute "outtypes"  -value $frfotypes
                        set_modcmd_attributes $rfid [parse_modcmd_attributes $frfattributes]
                    }
                    if {!$fres} {
                        ig::db::set_attribute -object $modid -attribute "outtypes" -value $fotypes
                        set_modcmd_attributes $modid [parse_modcmd_attributes $fattributes]
                    }
                    ig::db::set_attribute -object $modid -attribute "dummy" -value $fdummy
                }

                if {$moduleparent ne ""} {
                    set instance_name [ig::aux::remove_comma_ws $instance_name]
                    foreach i_inst [expand_instances $instance_name] {
                        set i_name [lindex $i_inst 0]
                        set i_mod  [lindex $i_inst 1]

                        ig::log -debug -id MTree "M (module = $instance_name): creating instance $i_name of module $moduleparent"

                        set instid [ig::db::create_instance \
                            -name $i_name \
                            -of-module [ig::db::get_modules -name $i_mod] \
                            -parent-module [ig::db::get_modules -name $moduleparent]]

                        ig::db::set_attribute -object $instid -attribute "origin" -value $origin
                        if {$fres} {
                            set_modcmd_attributes $instid [parse_modcmd_attributes $fattributes]
                        }
                    }
                }
            }
        }

        ## @brief Run a construction script in encapsulated namespace.
        #
        # @param filename Path to script.
        # @param sargs List of key-value pairs for variables to set before execution
        proc run_script {filename {sargs {}}} {
            namespace eval _construct_run [subst {
                # running in subst mode!! (import local proc args)
                set filename [list $filename]
                set sargs    [list $sargs]
            }]
            namespace eval _construct_run {
                namespace import ::ig::*

                foreach i_arg $sargs {
                    lassign $i_arg k v
                    set $k $v
                }

                set source_cmd {source $filename}
                if {[catch $source_cmd emsg eopts]} {
                    set error_list [split $::errorInfo "\n"]

                    regexp {line\s(\d+)} [lindex $error_list end-2] unused_match line

                    set sep "\n"
                    ig::log -error "${filename}:${line} -- [join [lrange $error_list 0 end-3] $sep]"
                    exit 1;
                }
            }
            namespace delete _construct_run
        }

        ## @brief Auto connection for regfiles
        #
        # Unused outputs will be tied to zero. If destmod is not empty connection to module will be performed
        #
        # @param regfilename Name of the registerfile
        # @param siginfo List with {signalname signalbitwidth regtype port} for derive connection
        # @param destmod Destination module name
        # @param origin code origin for logging
        #
        # This command requires the tcllib yaml package for parsing yaml.
        proc rfautoconnect {regfilename siginfo {destmod {}}  {origin {}}} {
            set regfile_id [ig::db::get_regfiles -name $regfilename]
            set rf_module_name [ig::db::get_attribute -object [ig::db::get_attribute -object $regfile_id -attribute "parent"] -attribute "name"]

            set rf_signals [dict create]
            set rf_signals_dir [dict create]
            foreach {sig sigbits type port} $siginfo {
                if {$sig eq "-"} continue

                dict lappend rf_signals $sig $sigbits $port

                if {[string match *W* $type] || $type eq "C"} {
                    set dir -->
                } else {
                    set dir <--
                }
                if {![dict exists $rf_signals_dir $sig]} {
                    dict set rf_signals_dir $sig $dir
                } else {
                    if {[dict get $rf_signals_dir $sig] ne $dir} {
                        ig::log -id "RYDr" -warn "In-out direction for signal $sig."
                    }
                }
            }

            foreach {sig s_prop} $rf_signals {
                set dir [dict get $rf_signals_dir $sig]

                array set vec {}
                set w 1

                foreach {sigbits port} $s_prop {
                    foreach b $sigbits {
                        lassign [split $b ":"] hb lb
                            if {$lb eq ""} {
                                set  lb $hb
                            }
                        for {set i $lb} {$i <= $hb} {incr i} {
                            set vec($i) 1
                        }
                        ig::aux::max_set w [expr {$hb + 1}]
                    }
                }
                if {$destmod ne ""} {
                    if {$sig ne "-"} {
                        ig::log -id Sauto -info "[subst -nocommands -nobackslashes "S \"$sig\" -w $w $rf_module_name:$port! ${dir} $destmod:$port!"]"
                        ig::S $sig -w $w $rf_module_name:$port! ${dir} $destmod:$port!
                    }
                }

                if {$dir eq "-->"} {
                    for {set i 0} {$i < $w} {incr i} {
                        if {![info exists vec($i)]} {
                            ig::log -id Rcon -info "Missing connection of signal $sig\[$i\] - tieing to 1'b0."
                            ig::log -id Sauto -info "[subst -nocommands -nobackslashes "C \"$rf_module_name\" -as { assign $sig!\[$i\] = 1'b0; }"]"
                            ig::C $rf_module_name -as { assign $sig!\[$i\] = 1'b0; }
                        }
                    }
                }
            }
        }

        ## @brief Process csv registerfile description
        #
        # @param regfilename Name of the registerfile
        # @param rcsv csv description of register file
        # @param sigprefix prefix for automatically created signal names
        # @param origin code origin for logging
        # @return RT compatible register table
        #
        # This command requires the tcllib yaml package for parsing yaml.
        proc rcsv_process {regfilename rcsv addroffset ropts {sigprefix {}} {destmod {}} {origin {}}} {
            if {[llength $rcsv] <= 1} {
                ig::log -error -abort "RT (regfile ${regfilename}): no registers specified ($origin)"
            }

            # get regfile
            set rfid {}
            if {[catch {
                set rfid [ig::db::get_regfiles -name $regfilename]
            }]} {
                if {![catch {
                    set temp_mod [ig::db::get_modules -name $regfilename]
                }]} {
                    set temp_rfs [ig::db::get_regfiles -of $temp_mod]
                    if {[llength $temp_rfs] > 0} {
                        set rfid [lindex $temp_rfs 0]
                    }
                }
            }

            ig::aux::regfile_next_addr $rfid $addroffset
            #order: {entryname ?address? ?protect? ...}
            set r_head [lmap e [lindex $rcsv 0] {string trim $e}]
            set rcsv [lrange $rcsv 1 end]

            set idx_entry     [lsearch $r_head "entryname"]
            set idx_addr      [lsearch $r_head "address"]
            set idx_protect   [lsearch $r_head "protect"]
            set idx_entrybits [lsearch $r_head "entrybits"]
            set idx_type      [lsearch $r_head "entrybits"]
            set idx_signal    [lsearch $r_head "signal"]

            set e_head      {}
            foreach i_h $r_head {
                if {$i_h eq "entryname"} {continue}
                if {$i_h eq "address"}   {continue}
                if {$i_h eq "protect"}   {continue}
                lappend e_head $i_h
            }

            set e_dict      {}
            set e_last_name {}
            set e_last_addr {}
            set e_last_prot {}
            set e_table     {}

            foreach i_row $rcsv {
                set i_row [lmap e $i_row {string trim $e}]
                if {[llength $i_row] < [llength $r_head]} {
                    if {[llength $i_row] > 0} {
                        ig::log -warn "register table row \"${i_row}\" contains too few columns ($origin)"
                    }
                    continue
                }

                set e_row  {}
                set e_name {}
                set e_addr {}
                set e_prot {}

                for {set i 0} {$i < [llength $i_row]} {incr i} {
                    if {($i == $idx_entry)} {
                        set e_name [lindex $i_row $i]
                    } elseif {($i == $idx_addr)} {
                        set e_addr [lindex $i_row $i]
                    } elseif {($i == $idx_protect)} {
                        set e_prot [lindex $i_row $i]
                    } elseif {($i == $idx_entrybits)} {
                        #  strip []
                        lappend e_row [string map {[ {} ] {}} [lindex $i_row $i]]
                    } else {
                        lappend e_row [lindex $i_row $i]
                    }
                }

                if {$e_name eq ""} {set e_name $e_last_name}
                if {$e_name eq ""} {
                    ig::log -warn "register table row \"${i_row}\" has no entry name ($origin)"
                }
                if {$e_name eq $e_last_name} {
                    if {$e_addr eq ""} {set e_addr $e_last_addr}
                    if {$e_prot eq ""} {set e_prot $e_last_prot}
                }

                dict set e_dict $e_name addr $e_addr
                dict set e_dict $e_name prot $e_prot
                if {$e_name ne $e_last_name} {
                    dict set e_dict $e_name table [list $e_head]
                }

                # TODO: dest_signalbits from width or entrybits
                #set e_type [lindex $i_row $i]
                #if {$idx_signal} {
                #    if {$i_signalbits eq ""} {
                #        set dest_signalbits 0
                #        lassign [split $i_bits :]  hbit lbit
                #        if {$lbit eq ""} {
                #            set lbit $hbit
                #        }
                #        set dest_signalbits "[expr {$hbit - $lbit}]:0"
                #    } else {
                #        set dest_signalbits $i_signalbits
                #    }
                #}
                #lappend siginfo $i_signal $dest_signalbits $e_type $port


                dict update e_dict $e_name r_dict {
                    dict lappend r_dict table $e_row
                }

                set e_last_name $e_name
                set e_last_addr $e_addr
            }

            # create
            dict for {e_name e_data} $e_dict {
                set e_addr  [dict get $e_data "addr"]
                set e_prot  [dict get $e_data "prot"]
                set e_table [dict get $e_data "table"]

                set opts {}
                if {$e_addr ne ""} {
                    lappend opts "@[expr {$addroffset + $e_addr}]"
                }
                if {($e_prot ne "") && (($e_prot) || ($e_prot in {x X}))} {
                    lappend opts "-protected"
                }
                ig::R -cmdorigin $origin {*}${ropts} {*}${opts} $regfilename $e_name $e_table
            }

            #rfautoconnect $regfilename $siginfo $destmod $origin
        }
        ## @brief Process ryaml registerfile description
        #
        # @param regfilename Name of the registerfile
        # @param ryaml yaml description of register file
        # @param sigprefix prefix for automatically created signal names
        # @param origin code origin for logging
        #
        # This command requires the tcllib yaml package for parsing yaml.
        proc ryaml_process {regfilename ryaml addroffset ropts {sigprefix {}} {destmod {}} {origin {}}} {
            # use yaml parser from tcllib
            if {[catch {package require yaml}]} {
                ig::log -error "RT (regfile ${regfilename}): need tcllib/yaml for yaml parsing ($origin)"
                return {}
            }
            ##nagelfar syntax ::yaml::yaml2dict x*
            if {[catch {set rfdict [::yaml::yaml2dict $ryaml]} msg]} {
                ig::log -error "RT (regfile ${regfilename}): failed to parse yaml file ($origin):\n${msg}"
            }

            set result [list {entryname address name entrybits type reset signal signalbits comment}]

            if {$sigprefix ne {}} {
                set pfx "${sigprefix}_"
            } else {
                set pfx ""
            }

            set siginfo {}

            if {[lindex $rfdict 0] eq "IC_REGFILE"} {
                # get regfile
                set rfid {}
                if {[catch {
                    set rfid [ig::db::get_regfiles -name $regfilename]
                }]} {
                    if {![catch {
                        set temp_mod [ig::db::get_modules -name $regfilename]
                    }]} {
                        set temp_rfs [ig::db::get_regfiles -of $temp_mod]
                        if {[llength $temp_rfs] > 0} {
                            set rfid [lindex $temp_rfs 0]
                        }
                    }
                }

                ig::aux::regfile_next_addr $rfid $addroffset
                if {$rfid eq ""} {
                    ig::log -error -abort "RT: invalid regfile name specified: ${regfilename} ($origin)"
                }
                set ic_regfile [lindex $rfdict 1]
                foreach {k v} $ic_regfile {
                    switch -exact $k {
                        name {
                            if {$v ne $regfilename} {
                                ig::log -id "ChkRYN" -warn "RT (regfile ${regfilename}): yaml regfile name ($v) differs from regfile name ($origin)"
                            }
                        }
                        dw {
                            set rfdw [ig::db::get_attribute -object $rfid -attribute "datawidth"]
                            if {$rfdw != $v} {
                                ig::log -id "ChRYD" -warn "RT (regfile ${regfilename}): yaml regfile datawidth ($v) differs from regfile datawidth ($rfdw) ($origin)"
                            }
                        }
                        offset_type {
                            set rfalign [ig::db::get_attribute -object $rfid -attribute "addralign"]
                            if {$v eq "reg" && $rfalign != 1} {
                                ig::log -id "ChkRYA" -warn "RT (regfile ${regfilename}): yaml regfile align should be 1 when offset_type \"reg\" is specified ($origin)"
                            } elseif {$v eq "byte" && $rfalign != ($rfdw / 8)} {
                                set rfdw [ig::db::get_attribute -object $rfid -attribute "datawidth"]
                                ig::log -id "ChkRYA" -warn "RT (regfile ${regfilename}): yaml regfile align should be [expr {$rfdw / 8}] when offset_type \"byte\" is specified ($origin)"
                            }
                        }
                    }
                }
                dict unset rfdict "IC_REGFILE"
            }

            set regentry_default {
                name       ""
                entrybits  "0"
                type       ""
                reset      "-"
                signal     "-"
                signalbits "-"
                comment    ""
            }

            foreach {k v} $rfdict {
                if {$k ne "registers"} {
                    ig::log -id "RYChk" -warn "RT (regfile ${regfilename}): unknown key \"$k\" expected \"registers\"."
                } else {
                    foreach entrydict $v {
                        array set entry {
                            default_type "RW"
                            address      ""
                        }

                        set entry(name) [dict get $entrydict "name"]
                        foreach {e_ig e_ry} {
                            address      offset
                            default_type type
                            } {
                            if {[dict exists $entrydict $e_ry]} {
                                set entry($e_ig) [dict get $entrydict $e_ry]
                            }
                        }
                        set reg_entries [list [dict keys $regentry_default]]
                        foreach regdict [dict get $entrydict "fields"] {
                            set reg_entry $regentry_default

                            dict update reg_entry {*}{
                                name       i_name
                                entrybits  i_bits
                                type       i_type
                                reset      i_reset
                                signal     i_signal
                                signalbits i_signalbits
                                comment    i_comment
                            } {
                                set i_name [dict get $regdict "name"]
                                set i_type "$entry(default_type)"
                                if {[dict exists $regdict "type"]} {
                                    set i_type [dict get $regdict "type"]
                                }

                                set port "${entry(name)}_${i_name}"
                                if {$i_type eq "C"} {
                                    set i_signal "-"
                                } else {
                                    set i_signal "${pfx}${entry(name)}_${i_name}"
                                }
                                if {[dict exists $regdict "rst"]} {
                                    set i_reset [expr {[dict get $regdict "rst"]}]
                                }
                                if {$i_reset eq "-"} {
                                    if {[string first "W" $i_type] >= 0} {
                                        set i_reset 0
                                    }
                                }

                                set i_signalbits ""
                                if {[dict exists $regdict "map"]} {
                                    set sigstr [dict get $regdict "map"]
                                    if {[regexp -expanded {
                                        ^
                                        \s*
                                        (\w+?)(_[io])?
                                        \s*
                                        (\((.*)\))?
                                        \s*
                                        $
                                    } $sigstr m_whole m_sig m_sfx m_braces m_bits]} {
                                        set i_signal "${pfx}${m_sig}"
                                        set i_signalbits [string map {.. :} $m_bits]
                                        set port "${m_sig}"
                                    } else {
                                        ig::log -warn "RT (regfile ${regfilename}): could not parse signal mapping \"${sigstr}\" ($origin)"
                                    }
                                }

                                # conversion
                                switch -exact -- $i_type {
                                    C  {set i_type "C"}
                                    RO -
                                    R  {set i_type "R"}
                                    RL {set i_type "RL"}
                                    RH {set i_type "RH"}
                                    RW {set i_type "RW"}
                                    RWT -
                                    WT {set i_type "RWT"}
                                    default {ig::log -error "unknown register type $i_type ($origin)"}
                                }
                                if {[dict exists $regdict "pos"]} {
                                    set i_bits [string map {.. :} [dict get $regdict "pos"]]
                                }

                                if {[dict exists $regdict "desc"]} {
                                    set i_comment [dict get $regdict "desc"]
                                }

                                if {[dict exists $regdict "enum"]} {
                                    set i_enum {}
                                    foreach {k v} [dict get $regdict "enum"] {
                                        lappend i_enum "$k: $v"
                                    }
                                    append i_comment " ([join $i_enum ", "])"
                                }
                            }

                            if {$i_signal ne "-"} {
                                if {$i_signalbits eq ""} {
                                    set dest_signalbits 0
                                    lassign [split $i_bits :]  hbit lbit
                                    if {$lbit eq ""} {
                                        set lbit $hbit
                                    }
                                    set dest_signalbits "[expr {$hbit - $lbit}]:0"
                                } else {
                                    set dest_signalbits $i_signalbits
                                }
                                lappend siginfo $i_signal $dest_signalbits $i_type $port
                            }

                            lappend reg_entries [dict values $reg_entry]
                        }

                        set regaddr {}
                        if {$entry(address) ne ""} {
                            set regaddr "@[expr {$addroffset + $entry(address)}]"
                        }
                        ig::R $regfilename {*}$regaddr $entry(name) {*}$ropts  -cmdorigin $origin  $reg_entries
                    }
                }
            }

            rfautoconnect $regfilename $siginfo $destmod $origin
        }
    }


    ## @brief Create a new module.
    #
    ## @brief Option parser helper wrapper
    #
    # @param args <b> [OPTION]... MODULENAME</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> MODULENAME  </b></td><td> specify a modulename <br></td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -u(nit)(=)                </i></td><td>  specify unit name [directory]      <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -i(nst(ances|anciate))(=) </i></td><td>  specify Module to be instanciated  <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -rtl                      </i></td><td>  specify rtl attribute for module   <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -beh(av(ioral|ioural))    </i></td><td>  specify rtl attribute for module   <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(tb|testbench)           </i></td><td>  specify rtl attribute for module   <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -v(erilog)                </i></td><td>  output verilog language            <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -sv|-s(ystemverilog)      </i></td><td>  output systemverilog language      <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -vhd(l)                   </i></td><td>  output vhdl language               <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(ilm|macro)              </i></td><td>  pass ilm attribute to icglue       <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -res(ource)               </i></td><td>  pass ressource attribute to icglue <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(rf|(regf(ile)))(=)      </i></td><td>  pass regfile attribute to icglue   <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -attr(ibutes)(=)          </i></td><td>  pass an arribute dict to icglue    <br></td></tr>
    #    </table>
    # @return Object-ID of the newly created module.
    proc M args {
        # defaults
        set name          ""
        set unit          ""
        set instance_tree {}
        set mode          "rtl"
        set lang          "verilog"
        set ilm           "false"
        set dummy         "false"
        set resource      "false"
        set instances     {}
        set regfiles      {}
        set attributes    {}
        set rfattributes  {}
        set rfaddrbits    32
        set rfdatabits    32
        set rfaddralign   {}
        set otypes        ""
        set rfotypes      ""
        set origin        [ig::aux::get_origin_here]

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set name [ig::aux::parse_opts [list                                                                                           \
                   { {^-u(nit)?(=|$)}                     "string"              unit          "specify unit name \[directory\]"       }   \
                   { {^-i(nst(ances|anciate)?)?(=|$)}     "string"              instances     "specify Module to be instanciated"     }   \
                   { {^-tree(=)?}                         "string"              instance_tree "specify module instance tree"          }   \
                                                                                                                                          \
                   { {^-rtl$}                             "const=rtl"           mode          "specify rtl attribute for module"      }   \
                   { {^-beh(av(ioral|ioural)?)$}          "const=behavioral"    mode          "specify rtl attribute for module"      }   \
                   { {^-(tb|testbench)$}                  "const=tb"            mode          "specify rtl attribute for module"      }   \
                                                                                                                                          \
                   { {^-v(erilog)?$}                      "const=verilog"       lang          "output verilog language"               }   \
                   { {^-sv|-s(ystemverilog)?$}            "const=systemverilog" lang          "output systemverilog language"         }   \
                   { {^-vhd(l)?$}                         "const=vhdl"          lang          "output vhdl language"                  }   \
                   { {^-systemc$}                         "const=systemc"       lang          "output systemc language"               }   \
                                                                                                                                          \
                   { {^-dummy$}                           "const=true"          dummy         "dummy wrapper - do not generate"       }   \
                   { {^-(ilm|macro)$}                     "const=ilm"           ilm           "pass ilm attribute to icglue"          }   \
                   { {^-res(ource)?$}                     "const=true"          resource      "pass ressource attribute to icglue"    }   \
                                                                                                                                          \
                   { {^-(rf|(regf(ile)?))(=|$)}           "string"              regfiles      "pass regfile attribute to icglue"      }   \
                                                                                                                                          \
                   { {^-attr(ibutes?)?(=|$)}              "string"              attributes    "pass a module arribute dict to icglue" }   \
                   { {^-rfattr(ibutes?)?(=|$)}            "string"              rfattributes  "pass a regfile arribute dict to icglue"}   \
                   { {^-rfa(ddr(ess)?)?w(idth)?(=|$)}     "integer"             rfaddrbits    "regfile address size"                  }   \
                   { {^-rfa(ddr(ess)?)?align(ment)?(=|$)} "integer"             rfaddralign   "regfile address alignment"             }   \
                   { {^-rfd(ata)?w(idth)?(=|$)}           "integer"             rfdatabits    "regfile data size"                     }   \
                                                                                                                                          \
                   { {^-o(typ(es)?|tags)(=|$)}            "string"              otypes        "default output types"                  }   \
                   { {^-rfo(typ(es)?|tags)(=|$)}          "string"              rfotypes      "default regfile output types"          }   \
                                                                                                                                          \
                   { {^-cmdorigin(=|$)}                   "string"              origin        "origin of command call for logging"    }   \
            ] -context "MODULENAME" $args]


        # argument checks
        if {[llength $name] > 1} {
            log -error -abort "M: too many arguments ($name) ($origin)"
        }

        if {$rfaddralign eq {}} {
            set rfaddralign [expr {$rfdatabits / 8}]
        }


        if {$instance_tree ne {}} {
            set module_list [construct::mtree_parse $instance_tree $origin]

            set modids [construct::mtree_process_modules $module_list $origin]

            construct::mtree_process_insts_rfs $module_list $unit $mode $lang $origin

            return $modids
        }

        if {$unit eq ""} {
            set unit $name
        }

        if {$name eq ""} {
            log -error -abort "M: need a module name ($origin)"
        }
        if {$resource && ([llength $instances] > 0)} {
            log -error -abort "M (module ${name}): a resource cannot have instances ($origin)"
        }

        if {[catch {
            catch {
                if {$resource} {
                    set modid [ig::db::create_module -resource -name $name]
                } elseif {$ilm} {
                    set modid [ig::db::create_module -ilm -name $name]
                } else {
                    set modid [ig::db::create_module -name $name]
                }
            }
            ig::db::set_attribute -object $modid -attribute "language"   -value $lang
            ig::db::set_attribute -object $modid -attribute "mode"       -value $mode
            ig::db::set_attribute -object $modid -attribute "parentunit" -value $unit
            ig::db::set_attribute -object $modid -attribute "outtypes"   -value $otypes
            ig::db::set_attribute -object $modid -attribute "dummy"      -value $dummy

            construct::set_modcmd_attributes $modid $attributes

            # instances
            set instances [ig::aux::remove_comma_ws $instances]
            foreach i_inst [construct::expand_instances $instances] {
                set i_name [lindex $i_inst 0]
                set i_mod  [lindex $i_inst 1]

                log -debug "M (module = $name): creating instance $i_name of module $i_mod"

                ig::db::create_instance \
                    -name $i_name \
                    -of-module [ig::db::get_modules -name $i_mod] \
                    -parent-module $modid
            }

            # regfiles
            foreach i_rf $regfiles {
                set rfid [ig::db::add_regfile -regfile $i_rf -to $modid]
                ig::db::set_attribute -object $rfid -attribute "origin" -value $origin
                ig::db::set_attribute -object $rfid -attribute "addrwidth" -value $rfaddrbits
                ig::db::set_attribute -object $rfid -attribute "addralign" -value $rfaddralign
                ig::db::set_attribute -object $rfid -attribute "datawidth" -value $rfdatabits
                ig::db::set_attribute -object $rfid -attribute "outtypes"  -value $rfotypes
                construct::set_modcmd_attributes $rfid $rfattributes
            }
        } emsg]} {
            log -error -abort "M (module ${name}): error while creating module:\n${emsg} ($origin)"
        }

        ig::db::set_attribute -object $modid -attribute "origin" -value $origin
        return $modid
    }

    ## @brief Create a new signal.
    #
    # @param args <b> [OPTION]... SIGNALNAME CONNECTIONPORTS...</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> SIGNALNAME      </b></td><td> The signalname must be a uniq indentifier of the whole icglue script <br></td></tr>
    #      <tr><td><b> CONNECTIONPORTS </b></td><td> The connections ports are follow the syntax scheme MODULENAME[:PORTNAME].<br>
    #                                                If PORTNAME is omitted the SIGNALNAME name is taken.<br>
    #                                                If PORTNAME ends with "!" signal adaption is done by icglue ("_{i,s,o}")<br></td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -w(idth)(=)         </i></td><td>  set signal width                             <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -b(idir(ectional))  </i></td><td>  bidirectional connection                     <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; <->                 </i></td><td>  bidirectional connection                     <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(-)>               </i></td><td>  first element is interpreted as input source <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; <(-)-               </i></td><td>  last element is interpreted as input source  <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -p(in)              </i></td><td>  add a pin to a resource module               <br></td></tr>
    #
    # @return Object-ID of net object of the newly created signal.
    #
    # Source and target-lists will be expanded and can contain local signal-name specifications after a ":" symbol
    # (local signal-name suffixes can be generated when the signal-name is followed by "!")
    # and multi-instance-expressions e.g. module\<1,4..9,a,b\>.
    proc S args {
        # defaults
        set name         ""
        set width        1
        set value        ""
        set bidir        "false"
        set invert       {}
        set resource_pin "false"
        set dimension    {}
        set signed       "false"
        set type         ""
        set origin       [ig::aux::get_origin_here]

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set arguments [ig::aux::parse_opts [list                                                                      \
                { {^-w(idth)?(=)?}         "string"      width        "set signal width" }                            \
                { {^(-v(alue)?(=|$)|=)}    "string"      value        "assign value to signal" }                      \
                { {^-d(imension)?(=)?}     "string"      dimension    "multi-dimensional SV ports" }                  \
                { {^-s(ign(ed)?)?}         "const=true"  signed       "signed SV ports" }                             \
                { {^-t(ype)?$}             "string"      type         "declare signal type"}                          \
                { {^-b(idir(ectional)?)?$} "const=true"  bidir        "bidirectional connection"}                     \
                { {^<->$}                  "const=true"  bidir        "bidirectional connection"}                     \
                { {^-(-)?>$}               "const=false" invert       "first element is interpreted as input source"} \
                { {^<(-)?-$}               "const=true"  invert       "last element is interpreted as input source"}  \
                { {^-p(in)?$}              "const=true"  resource_pin "add a pin to a resource module"}               \
                { {^-cmdorigin(=|$)}       "string"      origin       "origin of command call for logging"}           \
            ] -context "SIGNALNAME CONNECTIONPORTS..." $args]

        set name [lindex $arguments 0]
        # argument checks
        if {$name eq ""} {
            log -error -abort "S: no signal name specified ($origin)"
        }

        if {$resource_pin} {
            if {$bidir} {
                set pdir -inout
                set pinname "${name}_b"
            } elseif {$invert eq "true"} {
                set pdir -out
                set pinname "${name}_o"
            } elseif {$invert eq "false"} {
                set pdir -in
                set pinname "${name}_i"
            } else {
                set pdir {}
                set pinname "${name}"
            }

            set instance_names [lrange $arguments 1 end]
            set instance_names [ig::aux::remove_comma_ws $instance_names]
            if {[llength $instance_names] == 0} {
                log -error -abort "S: no instance names specified ($origin)"
            }

            set retval {}

            foreach inst [construct::expand_instances $instance_names] {
                set instname [lindex $inst 0]
                set inst_pinname [lindex $inst 2]
                if {$inst_pinname ne ""} {
                    # remove leading :
                    set inst_pinname [string range $inst_pinname 1 end]
                } else {
                    set inst_pinname $pinname
                }

                if {[catch {set tmp_pin [ig::db::create_pin -instname $instname -pinname $inst_pinname -value $value -size $width {*}$pdir]} emsg]} {
                    log -error -abort "${emsg}"
                }
                foreach itmp_pin $tmp_pin {
                    ig::db::set_attribute -object $itmp_pin -attribute "adapt" -value "selective"
                    lappend retval $itmp_pin
                }
            }
            return $retval;
        }
        if {$invert eq ""} {
            set invert "false"
        }

        if {!$invert && !$bidir} {
            set con_left  [lindex $arguments 1]

            set con_right {}
            foreach cr [lrange $arguments 2 end] {
                if {[llength $cr] > 0} {
                    lappend con_right {*}$cr
                }
            }
        } elseif {$invert} {
            set con_left  [lindex $arguments end]

            set con_right {}
            foreach cr [lrange $arguments 1 end-1] {
                if {[llength $cr] > 0} {
                    lappend con_right {*}$cr
                }
            }
        } elseif {$bidir} {
            set con_left  {}
            foreach cl [lrange $arguments 1 end] {
                if {[llength $cl] > 0} {
                    lappend con_left {*}$cl
                }
            }
            set con_right {}
        } else {
            log -error -abort "S: no connection direction specified ($origin)"
        }

        set con_left  [ig::aux::remove_comma_ws $con_left]
        set con_right [ig::aux::remove_comma_ws $con_right]
        # actual module creation
        if {[catch {
            set con_left_e  [construct::expand_instances $con_left  "true" "true"]

            if {$bidir} {
                set net [ig::db::connect -bidir $con_left_e -signal-name $name -signal-size $width]
            } else {
                set con_right_e [construct::expand_instances $con_right "true" "true"]
                set net [ig::db::connect -from {*}$con_left_e -to $con_right_e -signal-name $name -signal-size $width]
            }

            ig::db::set_attribute -object $net -attribute "dimension" -value $dimension
            foreach obj [ig::db::get_net_objects -of $net] {
                ig::db::set_attribute -object $obj -attribute "dimension" -value $dimension
            }
            ig::db::set_attribute -object $net -attribute "signed" -value $signed
            foreach obj [ig::db::get_net_objects -of $net] {
                ig::db::set_attribute -object $obj -attribute "signed" -value $signed
            }
            ig::db::set_attribute -object $net -attribute "nettype" -value $type
            foreach obj [ig::db::get_net_objects -of $net] {
                ig::db::set_attribute -object $obj -attribute "nettype" -value $type
            }

            if {$value ne ""} {
                set startmod [lindex [construct::expand_instances $con_left true] 0 1]

                # adaption... TODO: change to "selective" and remove signalcheck
                if {[string first "!" $value] >= 0} {
                    set adapt "selective"
                    set code "assign ${name}! = ${value};"
                    set checkcode {}
                } else {
                    set adapt "signalcheck"
                    set code "assign ${name}! = ${value};"
                    set checkcode "assign ${name} = ${value};"
                    set checkcode [ig::aux::code_indent_fix $checkcode]
                }

                set code [ig::aux::code_indent_fix $code]
                set cid [ig::db::add_codesection -parent-module $startmod -code $code]

                ig::db::set_attribute -object $cid -attribute "adapt" -value $adapt
                ig::db::set_attribute -object $cid -attribute "align" -value {}
                ig::db::set_attribute -object $cid -attribute "checkcode" -value $checkcode
                ig::db::set_attribute -object $cid -attribute "signalname" -value $name
                ig::db::set_attribute -object $cid -attribute "origin" -value $origin
            }
        } emsg]} {
            log -error -abort "S (signal ${name}): error while creating signal:\n${emsg} ($origin)"
        }

        ig::db::set_attribute -object $net -attribute "origin" -value $origin

        return $net
    }

    ## @brief Create a new parameter.
    #
    # @param args <b> [OPTION]... PARAMETERNAME MODULENAME...</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> PARAMETERNAME </b></td><td> name of the parameter <br></td></tr>
    #      <tr><td><b> MODULENAME </b></td><td>modules obtaining the parameter (can be a list of modules as well)<br></td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; (=|-v(alue)(=))  </i></td><td>  specify parameter value <br></td></tr>
    #    </table>
    #
    # @return Object-IDs of the newly created objects of newly created parameter.
    #
    # Source and target-lists will be expanded and can contain local signal-name specifications after a ":" symbol
    # (local signal-name suffixes can be generated when the signal-name is followed by "!")
    # and multi-instance-expressions e.g. module\<1,4..9,a,b\>.
    proc P args {
        # defaults
        set name      ""
        set value     {}
        #set value     0
        set endpoints {}
        set ilist     0
        set origin    [ig::aux::get_origin_here]

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set params [ig::aux::parse_opts [list                                                   \
                   { {^(=|-v(alue)?)(=)?} "string" value  "specify parameter value" }           \
                   { {^-cmdorigin(=|$)}   "string" origin "origin of command call for logging"} \
            ] -context "PARAMETERNAME MODULENAME..." $args]

        set name [lindex $params 0]

        set endpoints {}
        foreach ep [lrange $params 1 end] {
            if {[llength $ep] > 1} {
                lappend endpoints {*}$ep
            } else {
                lappend endpoints $ep
            }
        }

        # argument checks
        if {$name eq ""} {
            log -error -abort "P: no parameter name specified ($origin)"
        }
        if {$value eq ""} {
            log -error -abort "P (parameter ${name}): no value specified ($origin)"
        }

        set endpoints [ig::aux::remove_comma_ws $endpoints]
        # actual parameter creation
        if {[catch {
            set ep {}
            foreach _list [construct::expand_instances $endpoints "true"] {
                lassign $_list inst_id module_id remainder inverted

                set is_ilm [ig::db::get_attribute -object $module_id -attribute "ilm" -default false]
                set is_res [ig::db::get_attribute -object $module_id -attribute "resource" -default false]

                if { $is_ilm && $is_res } {
                    set module_name [ig::db::get_attribute -object $module_id -attribute "name"]
                    log -warn -id "PIlm" "Overwriting parameter '${name}' of ILM and resource '${module_name}'"
                }
                lappend ep "${inst_id}${remainder}"
            }

            set paramid [ig::db::parameter -name $name -value $value -targets $ep]
        } emsg]} {
            log -error -abort "P (parameter ${name}): error while creating parameter:\n\t${emsg} ($origin)"
        }

        # provide paramname/-value as tcl variable
        if {![uplevel 1 [list info exists $name]]} {
            uplevel 1 [list set $name $value]
        } else {
            log -warn -id "PVar" "Refuse to set TCL-variable $name to parameter value - Already exists ([uplevel 1 [list format "%s" $name]]) ($origin)"
        }

        ig::db::set_attribute -object $paramid -attribute "origin" -value $origin
        return $paramid
    }

    ## @brief Create a new codesection.
    #
    # @param args <b> [OPTION]... MODULENAME CODE</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> MODULENAME </b></td><td> name of the module contain the code</td></tr>
    #      <tr><td><b> CODE </b></td><td> the actual code that should be inlined </td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -a(dapt)                 </i></td><td>  adapt signal names                                                                        <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -noa(dapt)               </i></td><td>  do not adapt signal names                                                                 <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -a(dapt-)s(elective(ly)) </i></td><td>  selectively adapt signal names followed by "!"                                            <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -al(ign)                 </i></td><td>  align codesections at given string                                                        <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -s(ubst)                 </i></td><td>  perform Tcl-variable substition of CODE argument, do not forget to escape, esp \[ and \]  <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -nos(ubst)               </i></td><td>  do not perform Tcl-variable substition of CODE argument                                   <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -v(erbatim)              </i></td><td>  alias for -noadapt and -nosubst                                                           <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -e(val(uate))            </i></td><td>  perform Tcl substition of CODE argument, do not forget to escape                          <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -noi(ndentfix)           </i></td><td>  do not fix the indent of the codeblock                                                    <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -cmdorigin(=|$)          </i></td><td>  origin of command call for logging                                                        <br></td></tr>
    #    </table>
    #
    # @return Object-ID of the newly created codesection.
    #
    # If adapt is specified (default), signal names in the code-block will be adapted by their local names.
    proc C args {
        # defaults
        set adapt         "default"
        set align         {}
        #TODO: review, if do_var_subst = true is a good choice here...
        #      -> what about $clog, $time, $strobe, $display, etc. -> not likely to be used compared to code generation with var's but still...
        set do_var_subst  "true"
        set do_indent_fix "true"
        set verbatim      "false"
        set do_subst      "false"
        set origin        [ig::aux::get_origin_here]
        set do_ws_trim    "false"

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set arguments [ig::aux::parse_opts [list \
                { {^-a(dapt)?$}                   "const=all"       adapt          "adapt signal names"                                               } \
                { {^-no(-)?a(dapt)?$}             "const=none"      adapt          "do not adapt signal names"                                        } \
                { {^-a(dapt-)?s(elective(ly)?)?$} "const=selective" adapt          "selectively adapt signal names followed by \"!\""                 } \
                { {^-al(ign)?$}                   "string"          align          "align codesections at given string"                               } \
                { {^-s(ubst)?$}                   "const=true"      do_var_subst   "perform Tcl-variable substition of CODE argument (default)"       } \
                { {^-nos(ubst)?$}                 "const=false"     do_var_subst   "do not perform Tcl-variable substition of CODE argument"          } \
                { {^-v(erbatim)?$}                "const=true"      verbatim       "alias for -noadapt and -nosubst"                                  } \
                { {^-e(val(uate)?)?$}             "const=true"      do_subst       "perform Tcl substition of CODE argument, do not forget to escape" } \
                { {^-noi(ndentfix)?$}             "const=false"     do_indent_fix  "do not fix the indent of the codeblock"                           } \
                { {^-cmdorigin(=|$)}              "string"          origin         "origin of command call for logging"                               } \
                { {^-t(rim)?$}                    "const=true"      do_ws_trim     "trim whitespaces and newlines around codesections"                } \
            ] -context "MODULENAME CODE" $args]

        # argument checks
        set modname [lindex $arguments 0]
        if {$modname eq ""} {
            log -error -abort "C: no module name specified ($origin)"
        }

        set code [lindex $arguments 1]
        if {$code eq ""} {
            log -error -abort "C (module ${modname}): no code section specified ($origin)"
        }

        if {$verbatim} {
            set adapt "none"
        } elseif {$do_subst} {
            set code [uplevel 1 subst [list $code]]
        } elseif {$do_var_subst} {
            set code [uplevel 1 subst -nocommands [list $code]]
        }

        if {$adapt eq "default"} {
            set adapt "all"
            log -warn -id "CAdDp" "Deprecated to specify codesections without adaption mode. Use one of (-adapt|-adapt-selectively|-noadapt|-verbatim) ($origin)."
        }

        if {$do_indent_fix} {
            set code [ig::aux::code_indent_fix $code]
        }


        if {$do_ws_trim} {
            # replace redundant newlines at the start
            set code [regsub {^\n} $code ""]

            # replace redundant newlines at the end
            set code [regsub {\n *\n *$} $code "\n"]
            ig::log -debug -id CWstrim "<${code}>"
        }


        # actual code creation
        if {[catch {
            set cid [ig::db::add_codesection -parent-module [ig::db::get_modules -name $modname] -code $code]

            ig::db::set_attribute -object $cid -attribute "adapt" -value $adapt
            ig::db::set_attribute -object $cid -attribute "align" -value $align
        } emsg]} {
            log -error -abort "C (module ${modname}): error while creating codesection:\n${emsg} ($origin)"
        }

        ig::db::set_attribute -object $cid -attribute "origin" -value $origin

        return $cid
    }

    ## @brief Create a new regfile-entry.
    #
    # @param args <b> [OPTION]... REGFILE-MODULE ENTRYNAME REGISTERTABLE</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> REGFILE-MODULE </b></td><td> regfile module name</td></tr>
    #      <tr><td><b> ENTRYNAME </b></td><td> unique name for the register entry </td></tr>
    #      <tr><td><b> REGISTERTABLE </b></td><td> specification of the register table </td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(rf|regf(ile))($|=)  </i></td><td>  DEPRECATED: specify the regfile name, dispenses REGFILE-MODULE argument           <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; (@|-addr($|=))        </i></td><td>  specify the address                                                               <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -handshake($|=)       </i></td><td>  specify sig-variablenals and type for handshake {signal-out signal-in type}       <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -prot(ect(ed)?)?      </i></td><td>  register is protected for privileged-only access                                  <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -subst                </i></td><td>  perform Tcl-variable substition in REGISTERTABLE argument (default for now)       <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -nosubst              </i></td><td>  do not perform Tcl-variable substition in REGISTERTABLE argument                  <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -e(val(uate)?)?       </i></td><td>  perform Tcl-command substition of REGISTERTABLE argument, do not forget to escape <br></td></tr>
    #    </table>
    #
    # @return Object-ID of the newly created regfile-entry.
    #
    # <b>REGISTERTABLE</b> is a list of the form {<b>HEADER REG1 REG2</b> ...}.
    #
    # <b>HEADER</b> is the register-table header and specifies the order of register-info block
    # in the following register sublists. It must contain at least "name", can contain:
    # @li name = name of the generated register.
    # @li width = bitwidth of the generated register.
    # @li entrybits = bitrange (\<high\>:\<low\>) inside the generated regfile-entry.
    # @li type = type of generated register. Can be one of "R","RW".
    # @li reset = reset value of generated register.
    # @li signal = signal to drive from generated register (MODNAME:SIGNAL -> creates signal connection as well, use MODNAME:= .
    # @li signalbits = bits of signal to drive (default: whole signal).
    # @li comment = comment
    #
    # <b>REGn</b>: Sublists containing the actual register-data.
    proc R args {
        # defaults
        set entryname          ""
        set regfilename        ""
        set address            {}
        set register_align     1
        set regdef             {}
        set handshake          {}
        set protected          "false"
        set do_var_subst       "true"
        set do_subst           "false"
        set origin             [ig::aux::get_origin_here]
        set comm               ""
        set subst_level        1
        set features            {}

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set arguments [ig::aux::parse_opts [list \
                { {^-(rf|regf(ile)?)($|=)}  "string"             regfilename    "DEPRECATED: specify the regfile name, dispenses REGFILE-MODULE argument "          } \
                { {^(@|-addr($|=))}         "string"             address        "specify the address"                                                               } \
                { {^-align($|=)}            "integer"            register_align "alignment of address at a multiple of the given number of registers"               } \
                { {^-handshake($|=)}        "string"             handshake      "specify signals and type for handshake {signal-out signal-in type} "               } \
                { {^-prot(ect(ed)?)?$}      "const=true"         protected      "register is protected for privileged-only access"                                  } \
                { {^-s(ubst)?$}             "const=true"         do_var_subst   "perform Tcl-variable substition of REGISTERTABLE argument (default)"               } \
                { {^-nos(ubst)?$}           "const=false"        do_var_subst   "do not perform Tcl-variable substition in REGISTERTABLE argument"                  } \
                { {^-e(val(uate)?)?$}       "const=true"         do_subst       "perform Tcl-command substition of REGISTERTABLE argument, do not forget to escape" } \
                { {^-cmdorigin(=|$)}        "string"             origin         "origin of command call for logging"                                                } \
                { {^-comm(ent)?(=|$)}       "string"             comm           "comment for register"                                                              } \
                { {^-subst_uplevel}         "integer"            subst_level    "uplevel for substition"                                                            } \
                { {^-features?}              "string"             features       "additional features entry (columns)"                                               } \
            ] -context "REGFILE-MODULE ENTRYNAME REGISTERTABLE" $args]

        if {$regfilename ne ""} {
            set entryname [lindex $arguments 0]
            set regdef    [lindex $arguments 1]
        } else {
            # set regfilename temporary (might be just the module name...)
            set regfilename [lindex $arguments 0]
            set entryname   [lindex $arguments 1]
            set regdef      [lindex $arguments 2]
        }

        if {$do_subst} {
            set regdef [uplevel $subst_level subst [list $regdef]]
        } elseif {$do_var_subst} {
            set regdef [uplevel $subst_level subst -nocommands -nobackslashes [list $regdef]]
        }

        if {[llength $arguments] < 2} {
            log -error "R : not enough arguments ($origin)"
            return {}
        } elseif {[llength $arguments] > 3} {
            log -error "R (regfile-entry ${entryname}): too many arguments\nPassed arguments are:\n $arguments ($origin)"
            return {}
        }

        if {$entryname eq ""} {
            log -error -abort "R: no regfile-entry name specified ($origin)"
        } elseif {$regfilename eq ""} {
            log -error -abort "R (regfile-entry ${entryname}): no regfile name specified ($origin)"
        } elseif {[llength $regdef] <= 1} {
            log -error -abort "R (regfile-entry ${entryname}): no registers specified ($origin)"
        }

        if {[llength [lindex $regdef 0]] < 2} {
            # we assume a list here, but there isn't one.., so let split by "\n" and create one
            set regdef_new {}
            foreach regdef_line [split $regdef "\n"] {
                set regdef_line [string trim $regdef_line]
                if {$regdef_line ne ""} {
                    lappend regdef_new $regdef_line
                }
            }
            set regdef $regdef_new
        }
        # entry map
        set entry_default_map {name width entrybits type reset signal signalbits comment}
        lappend entry_default_map {*}$features

        set entry_map {}
        foreach i_entry [lindex $regdef 0] {
            if {${i_entry} eq "|"} {
                lappend entry_map "|"
                continue;
            }
            set idx_def [lsearch -glob $entry_default_map "${i_entry}*"]
            if {$idx_def < 0} {
                log -error -abort "R (regfile-entry ${entryname}): invalid register attribute-name: ${i_entry} ($origin)"
            }
            lappend entry_map [lindex $entry_default_map $idx_def]
        }
        set regdef [lrange $regdef 1 end]

        # actual entry creation
        if {[catch {
            # get regfile
            set regfile_id {}
            set rf_module_name {}
            if {[catch {
                set regfile_id [ig::db::get_regfiles -name $regfilename]
            }]} {
                if {![catch {
                    set temp_mod [ig::db::get_modules -name $regfilename]
                }]} {
                    set temp_rfs [ig::db::get_regfiles -of $temp_mod]
                    if {[llength $temp_rfs] > 0} {
                        set regfile_id [lindex $temp_rfs 0]
                    }
                }
            }

            if {$regfile_id eq ""} {
                log -error -abort "R (regfile-entry ${entryname}): invalid regfile name specified: ${regfilename} ($origin)"
            }

            set old_features [ig::db::get_attribute -object $regfile_id -attribute "features" -default {}]
            set new_features $old_features

            foreach f $features {
                if {! ($f in $old_features)} {
                    lappend new_features $f
                }
            }
            ig::db::set_attribute -object $regfile_id -attribute "features" -value $new_features

            set alignment [ig::db::get_attribute -object $regfile_id -attribute "addralign"]
            # set the "real" regfilename
            set regfilename [ig::db::get_attribute -object $regfile_id -attribute "name"]
            set rf_module_name [ig::db::get_attribute -object [ig::db::get_attribute -object $regfile_id -attribute "parent"] -attribute "name"]

            # create entry
            set entry_id [ig::db::add_regfile -entry $entryname -to $regfile_id]
            # set address
            if {$address eq ""} {
                set address [ig::aux::regfile_next_addr $regfile_id]
                set address [ig::aux::regfile_aligned_addr $address $alignment $register_align]
                set address $address
            }
            if {(![string is entier $address]) || ($address < 0)} {
                log -error -abort "R (regfile-entry ${entryname}): no/invalid address ($origin)"
            }
            ig::db::set_attribute -object $entry_id -attribute "address"   -value [format "0x%x" $address]
            ig::db::set_attribute -object $entry_id -attribute "protected" -value $protected
            ig::db::set_attribute -object $entry_id -attribute "origin   " -value $origin
            ig::db::set_attribute -object $entry_id -attribute "comment"   -value $comm
            # origin
            ig::db::set_attribute -object $entry_id -attribute "origin" -value $origin
            # set handshake
            if {$handshake ne ""} {
                set handshakelist {}
                set handshake_sig_in  [lindex $handshake 0]
                set handshake_sig_out [lindex $handshake 1]

                set handshake_sig_in_out {}
                foreach {handshake_sig conn} [list $handshake_sig_in --> $handshake_sig_out <--] {
                    set s_signal {}
                    if {[llength $handshake_sig] > 1} {
                        set s_signal  [lindex $handshake_sig 0]
                        set s_modules [lindex $handshake_sig 1]
                    } elseif {[string first : $handshake_sig] != -1} {
                        lassign [split $handshake_sig ":"] s_modules s_signal
                        if {![regexp "^${regfilename}" $s_signal]} {
                            set s_modules "${s_modules}:${s_signal}!"
                            set s_signal  "${regfilename}_${s_signal}"
                        }
                    } else {
                        lappend handshake_sig_in_out $handshake_sig
                    }

                    if {$s_signal ne ""} {
                        set connect_cmd "S \"$s_signal\" $rf_module_name $conn $s_modules"
                        eval $connect_cmd
                        ig::log -info -id "RCon" "$connect_cmd"
                        lappend handshake_sig_in_out $s_signal
                    }
                }
                set handshakelist [list {*}$handshake_sig_in_out [lrange $handshake 2 end]]
                #set handshakelist [list [lindex $handshake_sig_in 0] [lindex $handshake_sig_out 0] [lrange $handshake 2 end]]
                ig::db::set_attribute -object $entry_id -attribute "handshake" -value $handshakelist
            }

            # creating registers
            foreach i_reg $regdef {
                set i_name [lindex $i_reg [lsearch $entry_map "name"]]
                if {[regexp {^-+} $i_name]} {
                    continue
                }

                if {$i_name eq "" || $i_name eq "|"} {
                    if {![info exists reg_id]} {
                        log -error -abort "R (regfile-entry ${entryname}): reg defined without name ($origin)"
                    }  else {
                        set c {}
                        if {$i_name eq "|"} {
                            set c "[join [lrange $i_reg [lsearch -not $i_reg "|"] end] " "]"
                        }  else {
                            set c $i_reg
                        }
                        set old_comment [ig::db::get_attribute -object $reg_id -attribute "rf_comment" -default {}]
                        set new_comment "$old_comment\n$c"
                        ig::db::set_attribute -object $reg_id -attribute "rf_comment" -value $new_comment
                        continue
                    }
                }

                set reg_id [ig::db::add_regfile -reg $i_name -to $entry_id]
                ig::db::set_attribute -object $reg_id -attribute "origin" -value $origin
                set s_modules {}
                set s_signal  {}
                set s_width   0
                set s_type    {}
                foreach i_attr [lrange $entry_default_map 1 end] {
                    # attributes except name
                    set pos [lsearch $entry_map $i_attr]
                    if {$pos ne [expr {[llength $entry_map]-1}]} {
                        set i_val [lindex $i_reg $pos]
                    } else {
                        set i_val [join [lrange $i_reg $pos end] " "]
                    }
                    set sbitsextra {}

                    if {$i_val ne ""} {
                        if {$i_attr eq "name"} {
                            set s_fieldname $i_val
                        }
                        if {$i_attr eq "signal"} {
                            if {[regexp {^(.*)\[([^\[\]]+)\]$} $i_val m_whole m_sig m_bits]} {
                                # signalbits in [...] (e.g. csv case)
                                set i_val      $m_sig
                                set sbitsextra $m_bits
                            }

                            if {[llength $i_val] > 1} {
                                set s_modules [lrange $i_val 1 end]
                                set s_signal  [lindex $i_val 0]

                                # special '=' means  signalname = fieldname
                                if {$s_signal eq "="} {
                                    set s_signal "${regfilename}_${entryname}_${i_name}"
                                } else {
                                    set s_signal "${regfilename}_${entryname}_${s_signal}"
                                }
                                set i_val $s_signal
                            } else {
                                # implicit - auto connect if : is in signalname [list entry only]
                                if {[string first ":" $i_val] ne -1} {
                                    lassign [split $i_val ":"] s_implicit_mod s_port
                                    # special '=' means  signalname = fieldname
                                    if {$s_port eq "="} {
                                        set s_modules [list "${s_implicit_mod}:${i_name}!"]
                                    } else {
                                        set s_modules [list ${s_implicit_mod}:${s_port}]
                                    }
                                    set s_signal "${regfilename}_${entryname}_${i_name}"
                                    set i_val $s_signal
                                }
                            }
                        }
                        if {$i_attr eq "type"} {
                            set s_type $i_val
                        }
                        if {$i_attr eq "entrybits"} {
                            lassign [split $i_val ":"] s_high s_low
                            if {$s_low ne ""} {
                                if {[string is integer $s_high]} {
                                    set s_width [expr {$s_high+1-$s_low}]
                                } else {
                                    set s_width "$s_high+1-$s_low"
                                }
                            } else {
                                set s_width 1
                            }
                        }
                        if {$i_attr eq "width"} {
                            set s_width $i_val
                        }
                        ig::db::set_attribute -object $reg_id -attribute "rf_${i_attr}" -value $i_val
                        if {$sbitsextra ne {}} {
                            ig::db::set_attribute -object $reg_id -attribute "rf_signalbits" -value $sbitsextra
                        }
                    }
                }

                if {$s_signal ne ""} {
                    if {[regexp {W} $s_type]} {
                        set conn "-->"
                    } elseif {[regexp {R} $s_type]} {
                        set conn "<--"
                    }
                    set rf_port [regsub "^${regfilename}_" ${s_signal} {}]
                    set connect_cmd "S \"${s_signal}\" -w $s_width ${rf_module_name}:${rf_port}! $conn $s_modules"
                    set sid [eval $connect_cmd]
                    ig::db::set_attribute -object $sid -attribute "origin" -value $origin

                    ig::log -info -id "RCon" "$connect_cmd"
                }
            }
            ig::aux::regfile_next_addr $regfile_id [format "0x%04X" [expr {$address + $alignment}]]
        } emsg]} {
            log -error -abort "R (regfile-entry ${entryname}): error while creating regfile-entry:\n${emsg} ($origin)"
        }

        return $entry_id
    }

    ## @brief Create a new signal and connect it to a regfile
    # @param args <b> [OPTION]... SIGNALNAME CONNECTIONPORTS...</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> SIGNALNAME      </b></td><td> The signalname must be a uniq indentifier of the whole icglue script <br></td></tr>
    #      <tr><td><b> CONNECTIONPORTS </b></td><td> The connections ports are follow the syntax scheme MODULENAME[:PORTNAME].<br>
    #                                                If PORTNAME is omitted the SIGNALNAME name is taken.<br>
    #                                                If PORTNAME ends with "!" signal adaption is done by icglue ("_{i,s,o}")<br></td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -w(idth)(=)                 </i></td><td>  set signal width                                                   <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(-)\>                      </i></td><td>  first element is interpreted as input source                       <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; <(-)-                       </i></td><td>  last element is interpreted as input source                        <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; (@|-addr($|=))              </i></td><td>  specify the address                                                <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -c(omment)($|=)             </i></td><td>  specify comment for the register                                   <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -t(ype)($|=)                </i></td><td>  specify regfile type                                               <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -handshake($|=)             </i></td><td>  specify signals and type for handshake {signal-out signal-in type} <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -prot(ect(ed))              </i></td><td>  register is protected for privileged-only access                   <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; (=|-v(alue)|-r(eset(val)))  </i></td><td>  specify reset value for the register                               <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -cmdorigin(=|$)             </i></td><td>  origin of command call for logging                                 <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(reg)n(ame)(=|$)           </i></td><td>  name of register (default value)                                   <br></td></tr>
    #    </table>
    #
    # @return Object-IDs of the newly created objects of newly created signal.
    #
    # Source and target-lists will be expanded and can contain local signal-name specifications after a ":" symbol
    # (local signal-name suffixes can be generated when the signal-name is followed by "!")
    # and multi-instance-expressions e.g. module\<1,4..9,a,b\>.
    proc SR args {
        # defaults
        set name         ""
        set width        1
        set value        ""
        set dir          "-->"
        set resource_pin "false"
        set retval       {}
        set reg_type     {}
        set address      {}
        set handshake    {}
        set protected    "false"
        set resetval     {}
        set comment      "-"
        set origin       [ig::aux::get_origin_here]
        set regname      "value"

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set arguments [ig::aux::parse_opts [list \
                { {^-w(idth)?(=)?}                 "string"       width     "set signal width"                                                    } \
                { {^-(-)?\>$}                      "const=-->"    dir       "first element is interpreted as input source"                        } \
                { {^<(-)?-$}                       "const=<--"    dir       "last element is interpreted as input source"                         } \
                { {^(@|-addr($|=))}                "string"       address   "specify the address"                                                 } \
                { {^-c(omment)?($|=)}              "string"       comment   "specify comment for the register"                                    } \
                { {^-t(ype)?($|=)}                 "string"       reg_type  "specify regfile type"                                                } \
                { {^-handshake($|=)}               "string"       handshake "specify signals and type for handshake {signal-out signal-in type}"  } \
                { {^-prot(ect(ed)?)?$}             "const=true"   protected "register is protected for privileged-only access"                    } \
                { {^(=|-v(alue)?|-r(eset(val)?)?)} "string"       resetval  "specify reset value for the register"                                } \
                { {^-cmdorigin(=|$)}               "string"       origin    "origin of command call for logging"                                  } \
                { {^-(reg)?n(ame)?(=|$)}           "string"       regname    "name of register (default: value)"                                  } \
            ] -context "SIGNALNAME CONNECTIONPORTS..." $args]

        set rf_args {"-nosubst"}
        if {$address ne ""} {
            lappend rf_args "@ [list $address]"
        }

        if {$handshake ne ""} {
            lappend rf_args "-handshake" [list $handshake]
        }
        if {$protected} {
            lappend rf_args "-protected"
        }

        set signalname [lindex $arguments 0]

        set regfile_id {}

        set rf_list {}

        set additional_connect_flags {}

        foreach i_rf [ig::db::get_regfiles -all] {
            set i_md [ig::db::get_attribute -object $i_rf -attribute "parent"]
            set arg_idx 1
            foreach name [lrange $arguments 1 end] {
                lassign [split $name ":"] name
                if {($name eq [ig::db::get_attribute -object $i_md -attribute "name"])} {
                    if {$resetval eq ""} {
                        set reset "$width'h0"
                    } else {
                        set reset $resetval
                    }
                    if {$reg_type eq ""} {
                        if {   (($dir eq "-->") && ($arg_idx == 1))
                            || (($dir eq "<--") && ($arg_idx == [llength $arguments]-1))} {
                            set reg_type "RW"
                        } else {
                            set reg_type "R"
                            set reset "-"
                            if {$resetval ne ""} {
                                set additional_connect_flags "-v $resetval"
                            }
                        }
                    }
                    set rf $i_rf
                    set rf_name [ig::db::get_attribute -object $rf -attribute "name"]
                    set entryname ${signalname}
                    lappend rf_list $rf_name $entryname $reg_type $reset
                    break
                }
                incr arg_idx
            }
        }
        if {[llength $rf_list] == 0} {
            ig::log -warn -id RSCon "No regfile found -- \n[ig::aux::get_origin_here -1] ($origin)"
            return $retval
        } else {
            ig::log -debug -id RSCon "Found regfile: $rf_list"
        }

        set signalname "[lindex $rf_list 0]_${signalname}"
        if {$dir eq "-->"} {
            set connect_cmd "S \"$signalname\" $additional_connect_flags -w $width [lindex $arguments 1]        -->  [lrange $arguments 2 end]"
        } else {
            set connect_cmd "S \"$signalname\" $additional_connect_flags -w $width [lrange $arguments 1 end-1]  <--  [lindex $arguments end]"
        }

        set regfile_cmd {}
        foreach {rf_name entryname type reset} $rf_list {
            ig::aux::max_set namelen       [string length {"name"}]
            ig::aux::max_set namelen       [string length "val"]
            ig::aux::max_set widthlen      [string length {"width"}]
            ig::aux::max_set widthlen      [string length $width]
            ig::aux::max_set typelen       [string length {"type"}]
            ig::aux::max_set typelen       [string length $type]
            ig::aux::max_set resetlen      [string length {"reset"}]
            ig::aux::max_set resetlen      [string length $reset]
            ig::aux::max_set signalnamelen [string length {"signalname"}]
            ig::aux::max_set signalnamelen [string length $signalname]
            ig::aux::max_set commentlen    [string length {"comment"}]
            ig::aux::max_set commentlen    [string length $comment]

            set rf_table "%-${namelen}s | %-${widthlen}s | %-${typelen}s | %-${resetlen}s | %-${signalnamelen}s | %-${commentlen}s\n"
            lappend regfile_cmd [string cat "R -rf=${rf_name} \"${entryname}\" [join $rf_args] \{\n" \
                [format "    $rf_table" {"name"}   {"width"} {"type"} {"reset"} {"signal"}     {"comment"} ] \
                [format "    $rf_table" [list $regname]    [list $width] [list $type]  [list $reset]  [list $signalname]  [list $comment]  ] \
                "\}"]
        }
        set regfile_cmd [join $regfile_cmd]
        ig::log -id SRCmd "[info level 0]\n${connect_cmd}\n${regfile_cmd}"
        set retval [eval "$connect_cmd -cmdorigin [list $origin]"]
        eval "$regfile_cmd -cmdorigin [list $origin]"
        return $retval
    }


    ## @brief Create new regfile-entries based on table.
    #
    # @param args <b> [OPTION]... REGFILE-MODULE REGISTERTABLE</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> REGISTERTABLE </b></td><td> specification of the register table </td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(rf|regf(ile))(=)  </i></td><td>  specify the regfile name                                <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -csv$               </i></td><td>  specify entries as csv                                  <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -csvfile(=)         </i></td><td>  specify entries as csvfile                              <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -csvsep(arator)(=)  </i></td><td>  specify separator for csvfiles                          <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -nosubst            </i></td><td>  do not perform Tcl substition in REGISTERTABLE argument <br></td></tr>
    #    </table>
    #
    # <b>REGISTERTABLE</b> is a list of the form {<b>HEADER REG1 REG2</b> ...}.
    #
    # <b>HEADER</b> is the register-table header and specifies the order of register-info block
    # in the following register sublists. It must contain at least "entryname" "name", can contain:
    # @li entryname = name of the generated regfile-entry. If empty, the entryname of the previous line is used.
    # @li address = address of the generated regfile-entry.
    # @li name = name of the generated register.
    # @li width = bitwidth of the generated register.
    # @li entrybits = bitrange (\<high\>:\<low\>) inside the generated regfile-entry.
    # @li type = type of generated register. Can be one of "R","RW".
    # @li reset = reset value of generated register.
    # @li signal = signal to drive from generated register.
    # @li signalbits = bits of signal to drive (default: whole signal).
    # @li comment = comment
    #
    # <b>REGn</b>: Sublists containing the actual register-data.
    proc RT args {
        # defaults
        set regfilename ""
        set regtable    {}
        set mode        ""
        set csvfile     {}
        set csvsep      {,}
        set csvdel      \"
        set destmod     {}
        set ryamlfile   {}
        set addroffset  0
        set ryamlsigpfx ""
        set subst_opt   "-nosubst"
        set eval_opt    ""
        set origin      [ig::aux::get_origin_here]

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set arguments [ig::aux::parse_opts [list \
                { {^-(rf|regf(ile)?)($|=)} "string"          regfilename "specify the regfile name"                                                          } \
                { {^-csv$}                 "const=csv"       mode        "specify entries as csv"                                                            } \
                { {^-csvfile($|=)}         "string"          csvfile     "specify entries as csvfile"                                                        } \
                { {^-csvsep(arator)?($|=)} "string"          csvsep      "specify separator for csvfiles"                                                    } \
                { {^-csvdel(imitor)?($|=)} "string"          csvdel      "specify delimiter for csvfiles"                                                    } \
                { {^-ryaml$}               "const=ryaml"     mode        "specify entries as yaml"                                                           } \
                { {^-ryamlfile($|=)}       "string"          ryamlfile   "specify entries as yamlfile"                                                       } \
                { {^-addroffset(=|$)}      "integer"         addroffset  "specify addrset offset"                                                            } \
                { {^-ryamlpfx($|=)}        "string"          ryamlsigpfx "signal prefix to use for yaml-regfiles without signal names"                       } \
                { {^-destmod($|=)}         "string"          destmod     "destination module for implict connections"                                        } \
                { {^-s(ubst)?$}            "const=-subst"    subst_opt   "perform Tcl-variable substition of REGISTERTABLE argument (default)"               } \
                { {^-nos(ubst)?$}          "const=-nosubst"  subst_opt   "do not perform Tcl-variable substition in REGISTERTABLE argument"                  } \
                { {^-e(val(uate)?)?$}      "const=-evaluate" eval_opt    "perform Tcl-command substition of REGISTERTABLE argument, do not forget to escape" } \
                { {^-cmdorigin(=|$)}       "string"          origin      "origin of command call for logging"                                                } \
            ] -context "REGFILE-MODULE REGISTERTABLE" $args]

        if {$regfilename ne ""} {
            set regtable    [lindex $arguments 0]
        } else {
            set regfilename [lindex $arguments 0]
            set regtable    [lindex $arguments 1]
        }

        if {([llength $arguments] < 1) && ($csvfile eq "") && ($ryamlfile eq "")} {
            log -error -abort "RT : not enough arguments ($origin)"
        } elseif {[llength $arguments] > 2} {
            log -error -abort "RT (regfile ${regfilename}): too many arguments ($origin)"
        }

        if {$regfilename eq ""} {
            log -error -abort "RT (regfile ${regfilename}): no regfile name specified ($origin)"
        }

        if {($csvfile ne "") || ($ryamlfile ne "")} {
            if {$csvfile ne ""} {
                set mode "csv"
                set fname $csvfile
            } else {
                set mode "ryaml"
                set fname $ryamlfile
            }
            set f [open $fname "r"]
            set regtable [read $f]
            close $f
        }

        lappend opts "-subst_uplevel 3"
        lappend opts $subst_opt
        if {$eval_opt ne ""} {
            lappend opts $eval_opt
        }

        if {$mode eq "csv"} {
            set t $regtable
            set regtable {}
            if {[catch {package require csv}]} {
                ig::log -warn "RT (regfile ${regfilename}): Couldn't find tcllib/csv for csv parsing ($origin)"
                foreach l [split $t "\n"] {
                    set line {}
                    foreach c [split $l $csvsep] {
                        lappend line [string trim $c]
                    }
                    lappend regtable $line
                }
            } else {
                ##nagelfar syntax ::csv::split x*
                set line {}
                foreach l [split $t "\n"] {

                    append line $l
                    ##nagelfar syntax ::csv::iscomplete x*
                    if {[::csv::iscomplete "$line"]} {
                        set regtablerow [::csv::split $line $csvsep $csvdel]
                        if {[string trim [concat {*}$regtablerow]] ne ""} {
                            lappend regtable $regtablerow
                        }
                        set line {}
                    } else {
                        if  {$line ne {}} {
                            append line \n
                        }
                    }
                }
            }
            construct::rcsv_process $regfilename $regtable $addroffset $opts $destmod $origin
        } elseif {$mode eq "ryaml"} {
            construct::ryaml_process $regfilename $regtable $addroffset $opts $ryamlsigpfx $destmod $origin
        } else {
            # order: {entryname ?address? ?protect? ...}
            set r_head [lindex $regtable 0]
                set regtable [lrange $regtable 1 end]

                set idx_entry   [lsearch $r_head "entryname"]
                set idx_addr    [lsearch $r_head "address"]
                set idx_protect [lsearch $r_head "protect"]

                set e_head      {}
            foreach i_h $r_head {
                if {$i_h eq "entryname"} {continue}
                if {$i_h eq "address"}   {continue}
                if {$i_h eq "protect"}   {continue}
                lappend e_head $i_h
            }

            set e_dict      {}
            set e_last_name {}
            set e_last_addr {}
            set e_last_prot {}
            set e_table     {}

            foreach i_row $regtable {
                if {[llength $i_row] < [llength $r_head]} {
                    if {[llength $i_row] > 0} {
                        log -warn "register table row \"${i_row}\" contains too few columns ($origin)"
                    }
                    continue
                }

                set e_row  {}
                set e_name {}
                set e_addr {}
                set e_prot {}

                for {set i 0} {$i < [llength $i_row]} {incr i} {
                    if {($i == $idx_entry)} {
                        set e_name [lindex $i_row $i]
                    } elseif {($i == $idx_addr)} {
                        set e_addr [lindex $i_row $i]
                    } elseif {($i == $idx_protect)} {
                        set e_prot [lindex $i_row $i]
                    } else {
                        lappend e_row [lindex $i_row $i]
                    }
                }

                if {$e_name eq ""} {set e_name $e_last_name}
                if {$e_name eq ""} {
                    log -warn "register table row \"${i_row}\" has no entry name ($origin)"
                }
                if {$e_name eq $e_last_name} {
                    if {$e_addr eq ""} {set e_addr $e_last_addr}
                    if {$e_prot eq ""} {set e_prot $e_last_prot}
                }

                dict set e_dict $e_name addr $e_addr
                    dict set e_dict $e_name prot $e_prot
                    if {$e_name ne $e_last_name} {
                        dict set e_dict $e_name table [list $e_head]
                    }

                dict with e_dict $e_name {
                    lappend table $e_row
                }

                set e_last_name $e_name
                    set e_last_addr $e_addr
            }

            # create
            dict for {e_name e_data} $e_dict {
                set e_addr  [dict get $e_data "addr"]
                    set e_prot  [dict get $e_data "prot"]
                    set e_table [dict get $e_data "table"]

                    set opts {}
                if {$e_addr ne ""} {
                    lappend opts "@${e_addr}"
                }
                if {($e_prot ne "") && (($e_prot) || ($e_prot in {x X}))} {
                    lappend opts "-protected"
                }
                if {$subst_opt ne ""} {
                    lappend opts $subst_opt
                }
                if {$eval_opt ne ""} {
                    lappend opts $eval_opt
                }

                R -cmdorigin $origin {*}${opts} $regfilename $e_name $e_table
            }
        }
    }

    namespace export *
}
