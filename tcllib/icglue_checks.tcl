
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

package provide ICGlue 2.0a1

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
            default {
                return
            }
        }
    }

    ## @brief Run sanity/consistency checks for given regfile.
    # @param regfile_id Object-ID of regfile to check.
    proc check_regfile {regfile_id} {
        set rfdata [list \
            "name"    [ig::db::get_attribute -object $regfile_id -attribute "name"] \
            "entries" [ig::templates::preprocess::regfile_to_arraylist $regfile_id] \
        ]

        check_regfile_addresses $rfdata
        check_regfile_entrybits $rfdata
    }

    ## @brief Run regfile entry address check.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_regfile_addresses {regfile_data} {
        set rfname  [dict get $regfile_data "name"]
        set entries [dict get $regfile_data "entries"]
        set addr_list [list]

        # currently assume 32bit aligned - extend to allow other addressing if supported ...
        set alignment 4

        foreach i_entry $entries {
            set name    [dict get $i_entry "name"]
            set address [dict get $i_entry "address"]

            # check if existing
            set idx [lsearch -integer -index 0 $addr_list [expr {int($address)}]]
            if {$idx >= 0} {
                lassign [lindex $addr_list $idx] o_address o_name
                ig::log -warn -id "ChkRA" "regfile entries \"${o_name}\" and \"${name}\" overlap at address [format "0x%08x" $address] (regfile ${rfname})"
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

        # assume 32 bit regs - change if other widths supported
        set wordsize 32

        foreach i_entry $entries {
            set ename [dict get $i_entry "name"]
            set regs  [dict get $i_entry "regs"]

            set bit_list [list]

            foreach i_reg $regs {
                set rname [dict get $i_reg "name"]
                set blow  [expr {int([dict get $i_reg "bit_low"])}]
                set bhigh [expr {int([dict get $i_reg "bit_high"])}]

                if {$bhigh >= $wordsize} {
                    ig::log -warn -id "ChkRB" "register \"${rname}\" in entry \"${ename}\" exceeds wordsize of ${wordsize} (MSB = ${bhigh}, regfile ${rfname})"
                }

                for {set i $blow} {$i <= $bhigh} {incr i} {
                    # check if existing
                    set idx [lsearch -integer -index 0 $bit_list $i]
                    if {$idx >= 0} {
                        lassign [lindex $bit_list $idx] o_bit o_name
                        ig::log -warn -id "ChkRB" "registers \"${rname}\" and \"${o_name}\" in entry \"${ename}\" overlap at bit ${i} (regfile ${rfname})"
                        continue
                    }

                    # add to list
                    lappend bit_list [list $i $rname]
                }
            }
        }
    }

    namespace export check_object
}

# vim: set filetype=icgluetcl syntax=tcl:
