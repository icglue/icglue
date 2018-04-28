package provide ICGlue 0.0.1

namespace eval ig {
    namespace eval construct {
        # expand instance-list to list of entries:
        #  {<inst-name> <module-name> }
        proc expand_instances {inst_list} {
            set result [list]
            #TODO...

            foreach i_entry $inst_list {
                lappend result [list $i_entry $i_entry]
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
                        -u(nit)?                 {set lastarg -u}
                        -i(nst(ances|anciate)?)? {set lastarg -i}

                        -v(erilog)?              {set lang "verilog"}
                        (-sv|-s(ystemverilog)?)  {set lang "systemverilog"}
                        -vhd(l)?                 {set lang "vhdl"}

                        -rtl                     {set mode "rtl"}
                        -beh(av(ioral|ioural)?)? {set mode "behavioral"}
                        -(tb|testbench)          {set mode "tb"}

                        -(ilm|macro)             {set ilm      "true"}
                        -res(ource)?             {set resource "true"}

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

}
