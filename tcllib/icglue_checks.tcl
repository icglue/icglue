
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
    }

    ## @brief Run regfile entry address check.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_regfile_addresses {regfile_data} {
        set rfname  [dict get $regfile_data "name"]
        set entries [dict get $regfile_data "entries"]
        set addr_list [list]

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

            # add to list (currently assume 32bit aligned - extend to allow other addressing if supported ...)
            for {set i 0} {$i < 4} {incr i} {
                set iaddr [expr {int($address / 4) * 4 + $i}]
                lappend addr_list [list $iaddr $name]
            }
        }
    }

    namespace export check_object
}

# vim: set filetype=icgluetcl syntax=tcl:
