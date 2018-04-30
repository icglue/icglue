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
                default {
                    switch -regexp -- $i_arg {
                        {^-u(nit)?$}                 {set lastarg -u}
                        {^-i(nst(ances|anciate)?)?$} {set lastarg -i}

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
                                log -error -abort "M (module ${name}): too much arguments"
                            }
                            set name $i_arg
                        }
                    }
                }
            }
        }

        # argument checks
        if {[lsearch {-u -i} $lastarg] >= 0} {
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

}
