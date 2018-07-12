
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
        #
        # @return List of expanded instance expressions {instance-name module-name remainder inverted}.
        #
        # The input list can contain expressions of the form ~module\<instance1,instance2\>:signal.
        # The default result would then contain two lists: {~module_instance1 module:signal} and {~module_instance2 module:signal}.
        #
        # If ids is set, the object ids of module and instance will be returned.
        # If there is no instance of the given instance-name to be found, a module id will be looked up.
        # If merge is set as well, the result-list will be reduced to a single entry for each instance of the form [~]${id}:signal.
        proc expand_instances {inst_list {ids false} {merge false}} {
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
                                lappend result [list "${m_module}_${i_sfx}" $m_module $m_rem $m_inv]
                            }
                        }
                    }
                } else {
                    error "ig::expand_instances: could not parse $i_entry (arg \$inst_list =  $inst_list)"
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

        ## @brief Run a construction script in encapsulated namespace.
        #
        # @param filename Path to script.
        # @param sargs List of key-value pairs for variables to set before execution
        proc run_script {filename {sargs {}}} {
            set script [list \
                "namespace eval _construct_run \{" \
                "    namespace import ::ig::*" \
                "    if {\[catch {" \
            ]

            foreach i_arg $sargs {
                lassign $i_arg k v
                lappend script "        set $k $v"
            }

            set script [concat $script [list \
                "        source [list $filename]" \
                "    }\]} \{" \
                "        ig::errinf::print_st_line [list $filename]" \
                "        ig::log -error \"Error while parsing source \\\"[list $filename]\\\"\"" \
                "        exit 1" \
                "    \}" \
                "\}" \
            ]]

            eval [join $script "\n"]

            namespace delete _construct_run
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
        set resource      "false"
        set instances     {}
        set regfiles      {}
        set attributes    {}
        set rfattributes  {}

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set name [ig::aux::parse_opts [list                                                                                           \
                   { {^-u(nit)?(=|$)}                 "string"              unit          "specify unit name \[directory\]"       }   \
                   { {^-i(nst(ances|anciate)?)?(=|$)} "string"              instances     "specify Module to be instanciated"     }   \
                   { {^-tree(=)?}                     "string"              instance_tree "specify module instance tree"          }   \
                                                                                                                                      \
                   { {^-rtl$}                         "const=rtl"           mode          "specify rtl attribute for module"      }   \
                   { {^-beh(av(ioral|ioural)?)$}      "const=behavioral"    mode          "specify rtl attribute for module"      }   \
                   { {^-(tb|testbench)$}              "const=tb"            mode          "specify rtl attribute for module"      }   \
                                                                                                                                      \
                   { {^-v(erilog)?$}                  "const=verilog"       lang          "output verilog language"               }   \
                   { {^-sv|-s(ystemverilog)?$}        "const=systemverilog" lang          "output systemverilog language"         }   \
                   { {^-vhd(l)?$}                     "const=vhdl"          lang          "output vhdl language"                  }   \
                                                                                                                                      \
                   { {^-(ilm|macro)$}                 "const=ilm"           ilm           "pass ilm attribute to icglue"          }   \
                   { {^-res(ource)?$}                 "const=true"          resource      "pass ressource attribute to icglue"    }   \
                                                                                                                                      \
                   { {^-(rf|(regf(ile)?))(=|$)}       "string"              regfiles      "pass regfile attribute to icglue"      }   \
                                                                                                                                      \
                   { {^-attr(ibutes)?(=|$)}           "string"              attributes    "pass a module arribute dict to icglue" }   \
                   { {^-rfattr(ibutes)?(=|$)}         "string"              rfattributes  "pass a regfile arribute dict to icglue"}   \
            ] -context "MODULENAME" $args]

        # argument checks
        if {[llength $name] > 1} {
            log -error -abort "M: too many arguments ($name)"
        }

        set instance_tree [split $instance_tree "\n"]
        if {[llength $instance_tree] > 0} {
            set cur_parent {}
            set cur_level {}
            set parents_stack {}
            set level_stack {}
            set last_instance {}
            set module_list {}
            set maxlen_modname 0

            foreach inst $instance_tree {
                set inst [string trim $inst]
                if {$inst eq ""} {continue}

                # remove spaces of list
                set m_level {}
                set m_instance {}
                set m_flags_full {}
                set m_flags {}
                regexp -expanded {
                    # Match level dots
                    ^\s*([-\.+|\*]+)\s*
                    # Match instance_name
                    ([^(]+)\s*
                    # Match flags
                    (\((.*)\))?
                }  $inst m_whole m_level m_instance m_flags_full m_flags
                set level [string length $m_level]
                set len_modname [string length $m_instance]
                if {$len_modname > $maxlen_modname} {
                    set maxlen_modname $len_modname
                }

                if {$level != 0  && $len_modname == 0} {
                    log -error -abort "M: Can't match instance_name - syntax error in instance tree"
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
            set module_inc_list {}

            foreach {instance_name moduleparent moduleflags} $module_list {
                set module_name   [lindex [split $instance_name <] 0]
                set modids {}
                log -id "MTree" -debug [format "module: %-${maxlen_modname}s -- parent: %-${maxlen_modname}s -- Flags: %s" $instance_name $moduleparent $moduleflags]

                set film "false"
                set fres "false"
                set finc "false"
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
                    log -debug -id MTree "M (module = $module_name): creating..."
                    lappend modids [ig::db::create_module {*}$cf -name $module_name]
                } else {
                    if {!$fres && !$finc} {
                        if {[lsearch $module_inc_list $module_name] == 0} {
                            log -error -abort "M (module = $module_name): exists multiple times and is neither resource nor included."
                        }
                    }
                }
            }

            foreach {instance_name moduleparent moduleflags} $module_list {
                set funit $unit
                set film "false"
                set fres "false"
                set finc "false"
                set fmode $mode
                set flang $lang
                set fattributes   {}
                set frfattributes {}
                set fregfile      "false"
                set fregfilename  {}

                if {$moduleparent ne ""} {
                    set ppunit [ig::db::get_attribute -object [ig::db::get_modules -name $moduleparent] -attribute "parentunit" -default ""]
                    if {$ppunit ne ""} {
                        set funit $ppunit
                    }
                }

                set moduleflags [regsub -all {([^\\]),\s*} $moduleflags "\\1\n"]
                set funknown [ig::aux::parse_opts [list                                        \
                    { {^u(nit)?(=|$)}                "string"              funit         {} }  \
                    { {^(ilm|macro)$}                "const=true"          film          {} }  \
                    { {^res(ource)?$}                "const=true"          fres          {} }  \
                                                                                               \
                    { {^inc(lude)?$}                 "const=true"          finc          {} }  \
                    { {^rtl$}                        "const=rtl"           fmode         {} }  \
                    { {^beh(av(ioral|ioural)?)?$}    "const=behavioral"    fmode         {} }  \
                    { {^(tb|testbench)$}             "const=tb"            fmode         {} }  \
                                                                                               \
                    { {^v(erilog)?$}                 "const=verilog"       flang         {} }  \
                    { {^sv|-s(ystemverilog)?$}       "const=systemverilog" flang         {} }  \
                    { {^vhd(l)?$}                    "const=vhdl"          flang         {} }  \
                                                                                               \
                    { {^(rf|(regf(ile)?)?)$}         "const=true"          fregfile      {} }  \
                    { {^(rf|(regf(ile)?)?)=}         "string"              fregfilename  {} }  \
                                                                                               \
                    { {^attr(ibutes)?(=|$)}          "list"                fattributes   {} }  \
                    { {^rfattr(ibutes)?(=|$)}        "list"                frfattributes {} }  \
                    ] [split $moduleflags "\n"]]

                if {[llength $funknown] != 0} {
                    log -warn -id MTree "M (instance $instance_name): Unknown flag(s) - $funknown"
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
                        foreach attr $frfattributes {
                            #set attr [string trim $attr {"{" "}"}]
                            lassign [split [regsub -all {=>} $attr {=}] "="] attr_name attr_val
                            ig::db::set_attribute -object $rfid -attribute $attr_name -value $attr_val
                        }
                    }
                    foreach attr $fattributes {
                        set attr [string trim $attr {"{" "}"}]
                        lassign [split [regsub -all {=>} $attr {=}] "="] attr_name attr_val
                        ig::db::set_attribute -object $modid -attribute $attr_name -value $attr_val
                    }
                }

                if {$moduleparent ne ""} {
                    foreach i_inst [construct::expand_instances $instance_name] {
                        set i_name [lindex $i_inst 0]
                        set i_mod  [lindex $i_inst 1]

                        log -debug -id MTree "M (module = $instance_name): creating instance $i_name of module $moduleparent"

                        ig::db::create_instance \
                            -name $i_name \
                            -of-module [ig::db::get_modules -name $i_mod] \
                            -parent-module [ig::db::get_modules -name $moduleparent]
                    }
                }
            }

            return $modids
        }
        if {$unit eq ""} {set unit $name}
        if {$name eq ""} {
            log -error -abort "M: need a module name"
        }
        if {$resource && ([llength $instances] > 0)} {
            log -error -abort "M (module ${name}): a resource cannot have instances"
        }

        # actual module creation
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
            foreach attr $attributes {
                set attr [string trim $attr {"{" "}"}]
                lassign [split [regsub -all {=>} $attr {=}] "="] attr_name attr_val
                ig::db::set_attribute -object $modid -attribute $attr_name -value $attr_val
            }

            # instances
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
                foreach attr $rfattributes {
                    set attr [string trim $attr {"{" "}"}]
                    lassign [split [regsub -all {=>} $attr {=}] "="] attr_name attr_val
                    ig::db::set_attribute -object $rfid -attribute $attr_name -value $attr_val
                }
            }
        } emsg]} {
            log -error -abort "M (module ${name}): error while creating module:\n${emsg}"
        }

        return $modid
    }

    ## @brief Create a new signal.
    #
    # @param args <b> [OPTION]... SIGNALNAME CONNECTIONPORTS...</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> __TODO__ HELPCONTEXT </b></td><td> __TODO__ ARGUMENT DESCRIPTION <br></td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -w(idth)(=)         </i></td><td>  set signal width                             <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -b(idir(ectional))  </i></td><td>  bidirectional connection                     <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; <->                 </i></td><td>  bidirectional connection                     <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(-)>               </i></td><td>  first element is interpreted as input source <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; <(-)-               </i></td><td>  last element is interpreted as input source  <br></td></tr>
    #
    # @return Object-IDs of the newly created objects of newly created signal.
    #
    # Source and target-lists will be expanded and can contain local signal-name specifications after a ":" symbol
    # (local signal-name suffixes can be generated when the signal-name is followed by "!")
    # and multi-instance-expressions e.g. module\<1,4..9,a,b\>.
    proc S args {
        # defaults
        set name      ""
        set width     1
        set value     ""
        set bidir     "false"
        set invert    "false"

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set arguments [ig::aux::parse_opts [list                                                                \
                { {^-w(idth)?(=)?}         "string"      width  "set signal width" }                            \
                { {^(-v(alue)?(=|$)|=$)}   "string"      value  "assign value to signal" }                      \
                { {^-b(idir(ectional)?)?$} "const=true"  bidir  "bidirectional connection"}                     \
                { {^<->$}                  "const=true"  bidir  "bidirectional connection"}                     \
                { {^-(-)?>$}               "const=false" invert "first element is interpreted as input source"} \
                { {^<(-)?-$}               "const=true"  invert "last element is interpreted as input source"}  \
            ] -context "SIGNALNAME CONNECTIONPORTS..." $args]

        set name      [lindex $arguments 0]
        # argument checks
        if {$name eq ""} {
            log -error -abort "S: no signal name specified"
        }


        if {!$invert && !$bidir} {
            set con_left  [lindex $arguments 1]

            set con_right {}
            foreach cr [lrange $arguments 2 end] {
                if {[llength $cr] > 1} {
                    lappend con_right {*}$cr
                } else {
                    lappend con_right $cr
                }
            }
        } elseif {$invert} {
            set con_left  [lindex $arguments end]

            set con_right {}
            foreach cr [lrange $arguments 1 end-1] {
                if {[llength $cr] > 1} {
                    lappend con_right {*}$cr
                } else {
                    lappend con_right $cr
                }
            }

        } elseif {$bidir} {
            set con_left  [concat $con_left $con_right]
            set con_right {}
        } else {
            log -error -abort "S: no connection direction specified"
        }


        # actual module creation
        if {[catch {
            set con_left_e  [construct::expand_instances $con_left  "true" "true"]
            set con_right_e [construct::expand_instances $con_right "true" "true"]

            if {$bidir} {
                set sigid [ig::db::connect -bidir $con_left_e -signal-name $name -signal-size $width]
            } else {
                set sigid [ig::db::connect -from {*}$con_left_e -to $con_right_e -signal-name $name -signal-size $width]
            }

            if {$value ne ""} {
                set startmod [lindex [construct::expand_instances $con_left "true" "false"] 0 1]

                set value_code [ig::db::add_codesection -parent-module $startmod -code "    assign ${name} = ${value};\n"]
                ig::db::set_attribute -object $value_code -attribute "adapt" -value "true"
            }
        } emsg]} {
            log -error -abort "S (signal ${name}): error while creating signal:\n${emsg}"
        }

        return $sigid
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

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set params [ig::aux::parse_opts [list                                        \
                   { {^(=|-v(alue)?)(=)?} "string" value "specify parameter value" } \
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
            log -error -abort "P: no parameter name specified"
        }
        if {$value eq ""} {
            log -error -abort "P (parameter ${name}): no value specified"
        }

        # actual parameter creation
        if {[catch {
            set endpoints [construct::expand_instances $endpoints "true" "true"]

            set paramid [ig::db::parameter -name $name -value $value -targets $endpoints]
        } emsg]} {
            log -error -abort "P (parameter ${name}): error while creating parameter:\n\t${emsg}"
        }

        return $paramid
    }

    ## @brief Create a new codesection.
    #
    # @param args <b> [OPTION]... MODULENAME CODE</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> MODULENAME </b></td><td> name of the module contain the code</td></tr>
    #      <tr><td><b> CODE </b></td><td> the actual code that should be inlined </td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -a(dapt)                  </i></td><td>  adapt signal names        <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; (-v(erbatim)|-noa(dapt))  </i></td><td>  do not adapt signal names <br></td></tr>
    #    </table>
    #
    # @return Object-ID of the newly created codesection.
    #
    # If adapt is specified (default), signal names in the code-block will be adapted by their local names.
    proc C args {
        # defaults
        set adapt     "true"

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set arguments [ig::aux::parse_opts [list                                                   \
                { {^-a(dapt)?$}                   "const=true"  adapt "adapt signal names" }       \
                { {^(-v(erbatim)?|-noa(dapt)?)$} "const=false" adapt "do not adapt signal names" } \
            ] -context "MODULENAME CODE" $args]

        # argument checks
        set modname [lindex $arguments 0]
        if {$modname eq ""} {
            log -error -abort "C: no module name specified"
        }

        set code [lindex $arguments 1]
        if {$code eq ""} {
            log -error -abort "C (module ${modname}): no code section specified"
        }

        # actual code creation
        if {[catch {
            set cid [ig::db::add_codesection -parent-module [ig::db::get_modules -name $modname] -code $code]

            ig::db::set_attribute -object $cid -attribute "adapt" -value $adapt
        } emsg]} {
            log -error -abort "C (module ${modname}): error while creating codesection:\n${emsg}"
        }

        return $cid
    }

    proc getRmodidbyname {regfilename} {
        set regfile_id {}
        foreach i_md [ig::db::get_modules -all] {
            if {![catch {ig::db::get_regfiles -name $regfilename -of $i_md} i_id] || \
                ($regfilename eq [ig::db::get_attribute -obj $i_md -attribute "name"])} {
                break
            }
        }
        if {$i_md eq ""} {
            log -error -abort "getRmodidbyname: Unable to get regfile by name $regfilename"
        }
        return $i_md
    }

    proc Raddr {rfmodid args} {
        if {[llength $args] > 1} {
            log -error -abort "Raddr takes maximal two arguments."
        }

        if {[llength $args] == 1} {
            ig::db::set_attribute -obj $rfmodid -attribute "_save_reg_addr" -value [lindex $args 0]
        }

        if {![catch {ig::db::get_attribute -obj $rfmodid -attribute "_save_reg_addr"} addr]} {
            return $addr
        } else {
            return "0x0000"
        }
    }


    ## @brief Create a new regfile-entry.
    #
    # @param args <b> [OPTION]... ENTRYNAME REGISTERTABLE</b><br>
    #    <table style="border:0px; border-spacing:40px 0px;">
    #      <tr><td><b> ENTRYNAME </b></td><td> unique name for the register entry </td></tr>
    #      <tr><td><b> REGISTERTABLE </b></td><td> specification of the register table </td></tr>
    #      <tr><td><b> OPTION </b></td><td><br></td></tr>
    #      <tr><td><i> &ensp; &ensp; -(rf|regf(ile))(=)  </i></td><td>  specify the regfile name ( deprecated ) <br></td></tr>
    #      <tr><td><i> &ensp; &ensp; @                   </i></td><td>  specifies the address    <br></td></tr>
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
    # @li signal = signal to drive from generated register.
    # @li signalbits = bits of signal to drive (default: whole signal).
    # @li comment = comment
    #
    # <b>REGn</b>: Sublists containing the actual register-data.
    proc R args {
        # TODO: update doxygen help
        # defaults
        set entryname   ""
        set regfilename ""
        set address     {}
        set regdef      {}
        set handshake   {}

        # parse_opts { <regexp> <argumenttype/check> <varname> <description> }
        set arguments [ig::aux::parse_opts [list                                                                                      \
                { {^-(rf|regf(ile)?)($|=)} "string" regfilename "specify the regfile name" }                                          \
                { {^(@|-addr($|=))}        "string" address     "specify the address"}                                                \
                { {^-handshake($|=)}       "string" handshake   "specify signals and type for handshake {signal-out signal-in type}"} \
            ] -context "REGFILE-MODULE ENTRYNAME REGISTERTABLE" $args]

        if {$regfilename ne ""} {
            set entryname [lindex $arguments 0]
            set regdef    [lindex $arguments 1]
        } else {
            set regfilename [lindex $arguments 0]
            set entryname   [lindex $arguments 1]
            set regdef      [lindex $arguments 2]
        }


        if {[llength $arguments] < 2} {
            log -error -abort "R : not enough arguments"
        } elseif {[llength $arguments] > 3} {
            log -error -abort "R (regfile-entry ${entryname}): too many arguments"
        }

        if {$entryname eq ""} {
            log -error -abort "R: no regfile-entry name specified"
        } elseif {$regfilename eq ""} {
            log -error -abort "R (regfile-entry ${entryname}): no regfile name specified"
        } elseif {[llength $regdef] <= 1} {
            log -error -abort "R (regfile-entry ${entryname}): no registers specified"
        }

        # entry map
        set entry_default_map {name width entrybits type reset signal signalbits comment}
        set entry_map {}
        foreach i_entry [lindex $regdef 0] {
            set idx_def [lsearch -glob $entry_default_map "${i_entry}*"]
            if {$idx_def < 0} {
                log -error -abort "R (regfile-entry ${entryname}): invalid register attribute-name: ${i_entry}"
            }
            lappend entry_map [lindex $entry_default_map $idx_def]
        }
        foreach i_entry $entry_default_map {
            if {[lsearch $entry_map $i_entry] < 0} {
                lappend entry_map $i_entry
            }
        }
        set regdef [lrange $regdef 1 end]

        # actual regfile creation
        if {[catch {
            # get regfile
            set regfile_id {}
            set rf_module_name {}
            set i_md [getRmodidbyname $regfilename]

            set regfiles [ig::db::get_regfiles -of $i_md]
            if {[llength $regfiles] > 0} {
                set regfile_id [lindex $regfiles 0]
                set rf_module_name [ig::db::get_attribute -obj $i_md -attribute "name"]
            } else {
                log -error -abort "R (name $regfilename): unable to get regfile_id"
            }

            if {$regfile_id eq ""} {
                log -error -abort "R (regfile-entry ${entryname}): invalid regfile name specified: ${regfilename}"
            }

            # create entry
            set entry_id [ig::db::add_regfile -entry $entryname -to $regfile_id]
            # set address
            if {$address eq ""} {
                set address [Raddr $i_md]
            }
            if {(![string is integer $address]) || ($address < 0)} {
                log -error -abort "R (regfile-entry ${entryname}): no/invalid address"
            }
            ig::db::set_attribute -object $entry_id -attribute "address" -value $address
            # set handshake
            if {$handshake ne ""} {
                set handshakelist {}
                set handshake_sig_in  [lindex $handshake 0]
                set handshake_sig_out [lindex $handshake 1]

                foreach {handshake_sig conn} [list $handshake_sig_in --> $handshake_sig_out <--] {
                    if {[llength $handshake_sig] > 1} {
                        set s_signal  [lindex $handshake_sig 0]
                        set s_modules [lindex $handshake_sig 1]
                        S $s_signal $rf_module_name $conn $s_modules
                        ig::log -info -id "RCon" "S \"$s_signal\" $rf_module_name $conn $s_modules"
                    }
                }
                set handshakelist [list [lindex $handshake_sig_in 0] [lindex $handshake_sig_out 0] [lrange $handshake 2 end]]

                ig::db::set_attribute -object $entry_id -attribute "handshake" -value $handshakelist
            }

            # creating registers
            foreach i_reg $regdef {
                set i_name [lindex $i_reg [lsearch $entry_map "name"]]

                if {$i_name eq ""} {
                    log -error -abort "R (regfile-entry ${entryname}): reg defined without name"
                }

                set reg_id [ig::db::add_regfile -reg $i_name -to $entry_id]
                set s_modules {}
                set s_signal  {}
                set s_width   {}
                set s_type    {}
                foreach i_attr [lrange $entry_default_map 1 end] {
                    # attributes except name
                    set i_val [lindex $i_reg [lsearch $entry_map $i_attr]]
                    if {$i_val ne ""} {
                        if {$i_attr eq "name"} {
                            set s_fieldname $i_val
                        }
                        if {$i_attr eq "signal"} {
                            if {[llength $i_val] > 1} {
                                set s_modules [lrange $i_val 1 end]
                                set s_signal [lindex $i_val 0]

                                # special '=' means  signalname = fieldname
                                if {$s_signal eq "="} {
                                    set s_signal $i_name
                                }
                                set i_val "$s_signal"
                            }
                            # implicit - auto connect if : is in signalname
                            if {[string first ":" $i_val] ne -1} {
                                lassign [split $i_val ":"] s_implicit_mod s_port
                                # special '=' means  signalname = fieldname
                                if {$s_port eq "="} {
                                    set s_modules [concat [list "${s_implicit_mod}:${i_name}!"] $s_modules]
                                } else {
                                    set s_modules [concat [list ${s_implicit_mod}:${s_port}] $s_modules]
                                }
                                set s_signal $i_name
                                set i_val "$s_signal"
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
                        ig::db::set_attribute -object $reg_id -attribute "rf_${i_attr}" -value $i_val
                    }
                }

                if {$s_signal ne ""} {
                    if {[regexp {W} $s_type]} {
                        set conn "-->"
                    } elseif {[regexp {R} $s_type]} {
                        set conn "<--"
                    }
                    set connect_cmd "S -w $s_width  \"${s_signal}\" $rf_module_name:$s_signal $conn $s_modules"
                    eval $connect_cmd
                    ig::log -info -id "RCon" "$connect_cmd"
                }
            }
            Raddr $i_md [format "0x%04X" [expr {$address+4}]]
        } emsg]} {
            log -error -abort "R (regfile-entry ${entryname}): error while creating regfile-entry:\n${emsg}"
        }

        return $entry_id
    }

    namespace export *
}

# vim: set filetype=icgluetcl syntax=tcl:
