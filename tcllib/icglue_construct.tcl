
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

package provide ICGlue 0.0.1

namespace eval ig {
    namespace eval construct {
        # expand instance-list to list of entries:
        #  {<inst-name> <module-name> <remainder>}
        proc expand_instances {inst_list {ids false} {merge false}} {
            set result [list]

            foreach i_entry $inst_list {
                if {[regexp -expanded {
                    ^
                    ([^<>]+)
                    (<(.*)>)?
                    (->[^\s]+)?
                    $
                } $i_entry m_entry m_module m_instwrap m_insts m_rem]} {
                    if {$m_instwrap eq ""} {
                        lappend result [list $m_module $m_module $m_rem]
                    } else {
                        foreach i_sfx [split $m_insts ","] {
                            if {[regexp {(.*)\.\.(.*)} $i_sfx m_sfx m_start m_stop]} {
                                for {set i $m_start} {$i <= $m_stop} {incr i} {
                                    lappend result [list "${m_module}_${i}" $m_module $m_rem]
                                }
                            } else {
                                lappend result [list "${m_module}_${i_sfx}" $m_module $m_rem]
                            }
                        }
                    }
                } else {
                    error "could not parse $i_entry"
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
                        lappend result_ids "${inst_id}[lindex $i_r 2]"
                    } else {
                        lappend result_ids [list \
                            $inst_id \
                            [ig::db::get_modules   -name [lindex $i_r 1]] \
                            [lindex $i_r 2]
                        ]
                    }
                }

                set result $result_ids
            }

            return $result
        }
    }


    proc M args {
        # defaults
        set name      ""
        set unit      ""
        set mode      "rtl"
        set lang      "verilog"
        set ilm       "false"
        set resource  "false"
        set instances {}
        set regfiles  {}

        # args
        set lastarg {}

        foreach i_arg $args {
            switch -- $lastarg {
                -u {
                    set unit $i_arg
                    set lastarg {}
                }
                -i {
                    set instances $i_arg
                    set lastarg {}
                }
                -rf {
                    set regfiles $i_arg
                    set lastarg {}
                }
                default {
                    switch -regexp -- $i_arg {
                        {^-u(nit)?$}                 {set lastarg -u}
                        {^-i(nst(ances|anciate)?)?$} {set lastarg -i}
                        {^-(rf|(regf(ile)?))$}       {set lastarg -rf}

                        {^-v(erilog)?$}              {set lang "verilog"}
                        {^(-sv|-s(ystemverilog)?)$}  {set lang "systemverilog"}
                        {^-vhd(l)?$}                 {set lang "vhdl"}

                        {^-rtl$}                     {set mode "rtl"}
                        {^-beh(av(ioral|ioural)?)?$} {set mode "behavioral"}
                        {^-(tb|testbench)$}          {set mode "tb"}

                        {^-(ilm|macro)$}             {set ilm      "true"}
                        {^-res(ource)?$}             {set resource "true"}

                        default {
                            if {$name ne ""} {
                                log -error -abort "M (module ${name}): too many arguments"
                            }
                            set name $i_arg
                        }
                    }
                }
            }
        }

        # argument checks
        if {[lsearch {-u -i -rf} $lastarg] >= 0} {
            log -error -abort "M (module ${name}): need an argument after ${lastarg}"
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
            if {$resource} {
                set modid [ig::db::create_module -resource -name $name]
            } elseif {$ilm} {
                set modid [ig::db::create_module -ilm -name $name]
            } else {
                set modid [ig::db::create_module -name $name]
            }
            ig::db::set_attribute -object $modid -attribute "language"   -value $lang
            ig::db::set_attribute -object $modid -attribute "mode"       -value $mode
            ig::db::set_attribute -object $modid -attribute "parentunit" -value $unit

            # instances
            foreach i_inst [construct::expand_instances $instances] {
                set i_name [lindex $i_inst 0]
                set i_mod  [lindex $i_inst 1]

                log -debug "M (module = $name): creating instance $i_name of module $i_mod"

                ig::db::create_instance \
                    -name $i_name \
                    -of-module [ig::db::get_modules -name $i_mod] \
                    -parent-module $modid \
            }

            # regfiles
            foreach i_rf $regfiles {
                ig::db::add_regfile -regfile $i_rf -to $modid
            }
        } emsg]} {
            log -error -abort "M (module ${name}): error while creating module:\n${emsg}"
        }

        return $modid
    }

    proc S args {
        # defaults
        set name      ""
        set width     1
        set bidir     "false"
        set invert    "false"
        set con_left  {}
        set con_right {}
        set con_list  0

        # args
        set lastarg {}

        foreach i_arg $args {
            switch -- $lastarg {
                -w {
                    set width $i_arg
                    set lastarg {}
                }
                default {
                    switch -regexp -- $i_arg {
                        {^-w(idth)?$}                {set lastarg -w}
                        {^-b(idir(ectional)?)?$}     {incr con_list; set bidir "true"}

                        {^->$}                       {incr con_list}
                        {^<-$}                       {incr con_list; set invert "true"}
                        {^<->$}                      {incr con_list; set bidir  "true"}

                        default {
                            if {$con_list == 0} {
                                incr con_list
                                set name $i_arg
                            } else {
                                foreach i_elem $i_arg {
                                    if {$con_list == 1} {
                                        lappend con_left $i_elem
                                    } elseif {$con_list == 2} {
                                        lappend con_right $i_elem
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        # argument checks
        if {[lsearch {-w} $lastarg] >= 0} {
            log -error -abort "S (signal ${name}): need an argument after ${lastarg}"
        }

        if {$con_list > 2} {
            log -error -abort "S (signal ${name}): too many direction arguments"
        }

        if {$name eq ""} {
            log -error -abort "S: no signal name specified"
        }

        # adaption
        if {$invert} {
            set temp      $con_left
            set con_left  $con_right
            set con_right $temp
        }
        if {$bidir} {
            set con_left  [concat $con_left $con_right]
            set con_right {}
        }

        # actual module creation
        if {[catch {
            set con_left  [construct::expand_instances $con_left  "true" "true"]
            set con_right [construct::expand_instances $con_right "true" "true"]

            if {$bidir} {
                set sigid [ig::db::connect -bidir $con_left -signal-name $name -signal-size $width]
            } else {
                set sigid [ig::db::connect -from {*}$con_left -to $con_right -signal-name $name -signal-size $width]
            }
        } emsg]} {
            log -error -abort "S (signal ${name}): error while creating signal:\n${emsg}"
        }

        return $sigid
    }

    proc P args {
        # defaults
        set name      ""
        set value     {}
        set endpoints {}
        set ilist     0

        # args
        set lastarg {}

        foreach i_arg $args {
            switch -- $lastarg {
                -v {
                    set value $i_arg
                    set lastarg {}
                }
                default {
                    switch -regexp -- $i_arg {
                        {^-v(alue)?$}                {set lastarg -v}

                        default {
                            if {$ilist == 0} {
                                incr ilist
                                set name $i_arg
                            } else {
                                foreach i_elem $i_arg {
                                    lappend endpoints $i_elem
                                }
                            }
                        }
                    }
                }
            }
        }

        # argument checks
        if {[lsearch {-v} $lastarg] >= 0} {
            log -error -abort "P (parameter ${name}): need an argument after ${lastarg}"
        }

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
            log -error -abort "P (parameter ${name}): error while creating parameter:\n${emsg}"
        }

        return $paramid
    }

    proc C args {
        # defaults
        set modname   ""
        set adapt     "true"
        set code      {}

        # args
        set lastarg {}

        foreach i_arg $args {
            switch -- $lastarg {
                -m {
                    set modname $i_arg
                    set lastarg {}
                }
                default {
                    switch -regexp -- $i_arg {
                        {^-m(od(ule)?)?$}           {set lastarg -m}
                        {^-a(dapt)?$}               {set adapt "true"}
                        {^(-v(erbatim)?|-noadapt)$} {set adapt "false"}

                        default {
                            lappend code $i_arg
                        }
                    }
                }
            }
        }

        # argument checks
        if {[lsearch {-m} $lastarg] >= 0} {
            log -error -abort "C: need an argument after ${lastarg}"
        }

        if {$modname eq ""} {
            log -error -abort "C: no module name specified"
        }

        set code [join $code "\n"]
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

    proc R args {
        # defaults
        set entryname   ""
        set regfilename ""
        set address     -1
        set regdef      {}

        # args
        set lastarg {}

        foreach i_arg $args {
            switch -- $lastarg {
                -rf {
                    set regfilename $i_arg
                    set lastarg {}
                }
                default {
                    switch -regexp -matchvar mlist -- $i_arg {
                        {^-(rf|regf(ile)?)$}        {set lastarg -rf}
                        {^@(.*)$}                   {set address [lindex $mlist 1]}

                        default {
                            if {$entryname eq ""} {
                                set entryname $i_arg
                            } elseif {[llength $regdef] == 0} {
                                set regdef $i_arg
                            } else {
                                log -error -abort "R (regfile-entry ${entryname}): too many arguments"
                            }
                        }
                    }
                }
            }
        }

        # argument checks
        if {[lsearch {-rf} $lastarg] >= 0} {
            log -error -abort "R: need an argument after ${lastarg}"
        }

        if {$entryname eq ""} {
            log -error -abort "R: no regfile-entry name specified"
        } elseif {$regfilename eq ""} {
            log -error -abort "R (regfile-entry ${entryname}): no regfile name specified"
        } elseif {(![string is integer $address]) || ($address < 0)} {
            log -error -abort "R (regfile-entry ${entryname}): no/invalid address"
        } elseif {[llength $regdef] <= 1} {
            log -error -abort "R (regfile-entry ${entryname}): no registers specified"
        }

        # entry map
        set entry_default_map {name width entrybits type reset signal signalbits}
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
            set regfile_id ""
            foreach i_md [ig::db::get_modules -all] {
                if {![catch {ig::db::get_regfiles -name $regfilename -of $i_md} i_id]} {
                    set regfile_id $i_id
                }
            }
            if {$regfile_id eq ""} {
                log -error -abort "R (regfile-entry ${entryname}): invalid regfile name specified: ${regfilename}"
            }

            # create entry
            set entry_id [ig::db::add_regfile -entry $entryname -to $regfile_id]
            ig::db::set_attribute -object $entry_id -attribute "address" -value $address

            # creating registers
            foreach i_reg $regdef {
                set i_name [lindex $i_reg [lsearch $entry_map "name"]]

                if {$i_name eq ""} {
                    log -error -abort "R (regfile-entry ${entryname}): reg defined without name"
                }

                set reg_id [ig::db::add_regfile -reg $i_name -to $entry_id]
                foreach i_attr [lrange $entry_default_map 1 end] {
                    # attributes except name
                    set i_val [lindex $i_reg [lsearch $entry_map $i_attr]]
                    if {$i_val ne ""} {
                        ig::db::set_attribute -object $reg_id -attribute "rf_${i_attr}" -value $i_val
                    }
                }
            }
        } emsg]} {
            log -error -abort "R (regfile-entry ${entryname}): error while creating regfile-entry:\n${emsg}"
        }

        return $entry_id
    }

}
