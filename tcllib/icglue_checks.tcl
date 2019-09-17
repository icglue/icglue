
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

package provide ICGlue 3.4

## @brief Sanity/consistency checks for objects
namespace eval ig::checks {
    ## @brief Run sanity/consistency checks for given object if available.
    # @param obj_id Object-ID of object to check.
    proc check_object {obj_id} {
        set type [ig::db::get_attribute -object $obj_id -attribute "type"]

        switch -exact -- $type {
            "regfile" {
                check_regfile $obj_id
            }
            "module" {
                if {[ig::db::get_attribute -object $obj_id -attribute "resource"]} {
                    check_resource_module $obj_id
                } else {
                    check_module $obj_id
                    return
                }
            }
            default {
                return
            }
        }
    }

    ## @brief Run sanity/consistency checks for given resource module.
    # @param module_id Object-ID of module to check.
    proc check_resource_module {module_id} {
        check_resource_module_port_consistency $module_id
    }

    ## @brief Run instance port consistency check for given resource module.
    # @param module_id Object-ID of module to check.
    proc check_resource_module_port_consistency {module_id} {
        set mname [ig::db::get_attribute -object $module_id -attribute "name"]
        set inst_list [list]
        foreach i_inst [ig::db::get_instances -all] {
            if {[ig::db::get_attribute -object $i_inst -attribute "module"] eq $module_id} {
                lappend inst_list $i_inst
            }
        }
        if {[llength $inst_list] <= 1} {return}

        set ilist [list]
        set pildict [dict create]

        foreach i_inst $inst_list {
            set iname [ig::db::get_attribute -object $i_inst -attribute "name"]
            lappend ilist $iname

            foreach i_pin [ig::db::get_pins -of $i_inst] {
                set pname [ig::db::get_attribute -object $i_pin -attribute "name"]
                dict lappend pildict $pname $iname
            }
        }

        foreach pin [dict keys $pildict] {
            set pilist [dict get $pildict $pin]
            if {$pilist ne $ilist} {
                set nulist [list]
                foreach ii $ilist {
                    if {[lsearch -exact $pilist $ii] < 0} {
                        lappend nulist $ii
                    }
                }
                if {[llength $pilist] > 1} {set pis "s"} else {set pis ""}
                if {[llength $nulist] > 1} {set nus "s"} else {set nus ""}
                ig::log -warn -id "ChkIP" "Port \"${pin}\" of resource module \"${mname}\" connected in instance${pis} \"[join $pilist "\", \""]\" but missing in instance${nus} \"[join $nulist "\", \""]\"."
            }
        }
    }

    ## @brief Run sanity/consistency checks for given module.
    # @param module_id Object-ID of module to check.
    proc check_module {module_id} {
        check_module_multi_dimensional_port_lang $module_id
    }

    # warn if the language does not support multidimensional ports
    # assume that only SystemVerilog supports it
    proc check_module_multi_dimensional_port_lang {module_id} {
        set mname [ig::db::get_attribute -object $module_id -attribute "name"]
        set lang  [ig::db::get_attribute -object $module_id -attribute "language"]
        if {$lang ne "systemverilog"} {
            foreach i_port [ig::db::get_ports -of $module_id] {
                set dimension [ig::db::get_attribute -object $i_port -attribute "dimension" -default {}]
                if {[llength $dimension] ne 0} {
                    ig::log -warn -id "ChkMD" "Port \"${i_port}\" in module \"${mname}\" has dimension \"${dimension}\". This is not supported in \"${lang}\"."
                }
            }
            foreach i_decl [ig::db::get_declarations -of $module_id] {
                set dimension [ig::db::get_attribute -object $i_decl -attribute "dimension" -default {}]
                if {[llength $dimension] ne 0} {
                    ig::log -warn -id "ChkMD" "Declarations \"${i_decl}\" in module \"${mname}\" has dimension \"${dimension}\". This is not supported in \"${lang}\"."
                }
            }

        }

    }

    ## @brief Run sanity/consistency checks for given regfile.
    # @param regfile_id Object-ID of regfile to check.
    proc check_regfile {regfile_id} {
        set rfdata [list \
            "name"      [ig::db::get_attribute -object $regfile_id -attribute "name"] \
            "addrwidth" [ig::db::get_attribute -object $regfile_id -attribute "addrwidth"] \
            "addralign" [ig::db::get_attribute -object $regfile_id -attribute "addralign"] \
            "datawidth" [ig::db::get_attribute -object $regfile_id -attribute "datawidth"] \
            "entries"   [ig::templates::preprocess::regfile_to_arraylist $regfile_id] \
        ]

        check_regfile_addresses   $rfdata
        check_regfile_entrybits   $rfdata
        check_regfile_resetvalues $rfdata
        check_regfile_names       $rfdata
    }

    ## @brief Run regfile entry address check.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_regfile_addresses {regfile_data} {
        set rfname    [dict get $regfile_data "name"]
        set entries   [dict get $regfile_data "entries"]
        set addrwidth [dict get $regfile_data "addrwidth"]
        set alignment [dict get $regfile_data "addralign"]
        set addr_list [list]

        foreach i_entry $entries {
            set name    [dict get $i_entry "name"]
            set address [dict get $i_entry "address"]
            set oid     [dict get $i_entry "object"]
            set origin {}
            if {$oid ne {}} {
                set origin [ig::db::get_attribute -object $oid -attribute "origin" -default {}]
            }

            # check alignment
            if {$address % $alignment != 0} {
                ig::log -warn -id "ChkRA" "regfile entry \"${name}\" has misaligned address [format "0x%08x" $address] (regfile ${rfname}, alignment ${alignment}) (${origin})"
            }

            # check addrsize
            if {clog2($address+1) >= $addrwidth} {
                ig::log -warn -id "ChkRA" "regfile entry \"${name}\" address [format "0x%08x" $address] ([expr {clog2($address+1)}] bits) does not fit into address size ${addrwidth} bits (regfile ${rfname}) (${origin})"
            }

            # check if existing
            set idx [lsearch -exact -integer -index 0 $addr_list $address]
            if {$idx >= 0} {
                lassign [lindex $addr_list $idx] o_address o_name
                ig::log -warn -id "ChkRA" "regfile entries \"${o_name}\" and \"${name}\" overlap at address [format "0x%08x" $address] (regfile ${rfname}) (${origin})"
                continue
            }

            # add to list
            for {set i 0} {$i < $alignment} {incr i} {
                set iaddr [expr {int($address / $alignment) * $alignment + $i}]
                lappend addr_list [list $iaddr $name]
            }
        }
    }

    ## @brief Run regfile entry bit check.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_regfile_entrybits {regfile_data} {
        set rfname  [dict get $regfile_data "name"]
        set entries [dict get $regfile_data "entries"]

        set wordsize [dict get $regfile_data "datawidth"]

        foreach i_entry $entries {
            set ename [dict get $i_entry "name"]
            set regs  [dict get $i_entry "regs"]
            set oid   [dict get $i_entry "object"]
            set origin {}
            if {$oid ne {}} {
                set origin [ig::db::get_attribute -object $oid -attribute "origin" -default {}]
            }

            set bit_list [list]

            foreach i_reg $regs {
                set rname [dict get $i_reg "name"]
                set blow  [dict get $i_reg "bit_low"]
                set bhigh [dict get $i_reg "bit_high"]

                if {$bhigh >= $wordsize} {
                    ig::log -warn -id "ChkRB" "register \"${rname}\" in entry \"${ename}\" exceeds wordsize of ${wordsize} (MSB = ${bhigh}, regfile ${rfname}) (${origin})"
                }

                for {set i $blow} {$i <= $bhigh} {incr i} {
                    # check if existing
                    set idx [lsearch -exact -integer -index 0 $bit_list $i]
                    if {$idx >= 0} {
                        lassign [lindex $bit_list $idx] o_bit o_name
                        ig::log -warn -id "ChkRB" "registers \"${rname}\" and \"${o_name}\" in entry \"${ename}\" overlap at bit ${i} (regfile ${rfname}) (${origin})"
                        continue
                    }

                    # add to list
                    lappend bit_list [list $i $rname]
                }
            }
        }
    }

    ## @brief Run regfile reset-value width check.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_regfile_resetvalues {regfile_data} {
        set rfname  [dict get $regfile_data "name"]
        set entries [dict get $regfile_data "entries"]

        set wordsize [dict get $regfile_data "datawidth"]

        foreach i_entry $entries {
            set ename [dict get $i_entry "name"]
            set regs  [dict get $i_entry "regs"]
            set oid   [dict get $i_entry "object"]
            set origin {}
            if {$oid ne {}} {
                set origin [ig::db::get_attribute -object $oid -attribute "origin" -default {}]
            }

            foreach i_reg $regs {
                set rname  [dict get $i_reg "name"]
                set width  [dict get $i_reg "width"]
                set rstval [dict get $i_reg "reset"]

                if {$rstval eq "-"} {continue}

                lassign [ig::vlog::parse_value $rstval] psucc pval rstwidth

                if {!$psucc} {continue}
                if {$rstwidth < 0} {
                    set rstwidth [expr {clog2($pval+1)}]
                    if {$rstwidth < $width} {set rstwidth $width}
                }

                if {$rstwidth != $width} {
                    ig::log -warn -id "ChkRR" "register \"${rname}\" in entry \"${ename}\" has reset value \"${rstval}\" needing ${rstwidth} bits but is ${width} bits wide (regfile ${rfname}) (${origin})"
                }
            }
        }
    }

    ## @brief Run regfile naming check.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_regfile_names {regfile_data} {
        set rfname  [dict get $regfile_data "name"]
        set entries [dict get $regfile_data "entries"]

        if {[string match {_*} $rfname]} {
            ig::log -warn -id "ChkRN" "regfile \"${rfname}\" has a name which potentially conflicts with internal types/names"
        }

        foreach i_entry $entries {
            set ename [dict get $i_entry "name"]
            set regs  [dict get $i_entry "regs"]
            set oid   [dict get $i_entry "object"]
            set origin {}
            if {$oid ne {}} {
                set origin [ig::db::get_attribute -object $oid -attribute "origin" -default {}]
            }

            if {[string match {_*} $ename]} {
                ig::log -warn -id "ChkRN" "entry \"${ename}\" has a name which potentially conflicts with internal types/names (regfile ${rfname}) (${origin})"
            }

            foreach i_reg $regs {
                set rname  [dict get $i_reg "name"]

                if {[string match {_*} $rname]} {
                    ig::log -warn -id "ChkRN" "register \"${rname}\" in entry \"${ename}\" has a name which potentially conflicts with internal types/names (regfile ${rfname})"
                }
            }
        }
    }

    namespace export check_object
}

