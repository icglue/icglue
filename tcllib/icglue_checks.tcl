
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

        foreach regfile_id [ig::db::get_regfiles -of $module_id] {
            check_module_regfile_ports $module_id $regfile_id
        }
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
            "module"    [ig::db::get_attribute -object $regfile_id -attribute "parent"] \
            "object"    $regfile_id \
        ]

        check_regfile_addresses   $rfdata
        check_regfile_entrybits   $rfdata
        check_regfile_signalbits  $rfdata
        check_regfile_resetvalues $rfdata
        check_regfile_names       $rfdata
        check_regfile_regtypes    $rfdata
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
            if {clog2($address+1) > $addrwidth} {
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

    ## @brief Run regfile signal bit check.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_regfile_signalbits {regfile_data} {
        set rfname  [dict get $regfile_data "name"]
        set entries [dict get $regfile_data "entries"]

        foreach i_entry $entries {
            set ename [dict get $i_entry "name"]
            set regs  [dict get $i_entry "regs"]
            set oid   [dict get $i_entry "object"]
            set origin {}
            if {$oid ne {}} {
                set origin [ig::db::get_attribute -object $oid -attribute "origin" -default {}]
            }

            foreach i_reg $regs {
                set rname [dict get $i_reg "name"]
                set sig   [dict get $i_reg "signal"]
                if {$sig eq "-"} {continue}

                if {[catch {ig::db::get_nets -name $sig} sigobj]} {
                    ig::log -warn -id "ChkRS" "register \"${rname}\" in entry \"${ename}\" connects to unknown signal ($sig, regfile ${rfname}) (${origin})"
                    continue
                }

                set sbits [dict get $i_reg "signalbits"]
                if {$sbits eq "-"} {continue}

                set rname [dict get $i_reg "name"]
                set blow  [dict get $i_reg "bit_low"]
                set bhigh [dict get $i_reg "bit_high"]
                set slow  [lindex [split $sbits ":"] end]
                set shigh [lindex [split $sbits ":"] 0]

                if {($bhigh - $blow) != ($shigh - $slow)} {
                    ig::log -warn -id "ChkRS" "register \"${rname}\" in entry \"${ename}\" connects to non-matching bits of signal (${bhigh}:${blow} <-> $sbits, regfile ${rfname}) (${origin})"
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

    # reserved keywords as dictionary
    # "keyword" -> {{list of languages} "renaming suggestion"}
    variable _reserved_names_dict {}

    ## @brief Generate or return cached reserved names dictionary
    # @return dictionary of reserved keywords to list of languages and (optionally) suggestions
    #
    # Entries are of form {{lang1 lang2 ...} {alternative1 alternative2 ...}}.
    # Suggestions may be empty.
    proc get_reserved_names {} {
        variable _reserved_names_dict

        if {[dict size ${_reserved_names_dict}] != 0} {
            return ${_reserved_names_dict}
        }

        # init
        set reserved_names {
            "c/c++" {
                alignas alignof and and_eq asm auto
                bitand bitor bool break
                case catch char char16_t char32_t class compl const constexpr const_cast continue
                decltype default delete do double dynamic_cast
                else enum explicit export extern
                false float for friend
                goto
                if inline int
                long
                mutable
                namespace new noexcept not not_eq nullptr
                operator or or_eq
                private protected public
                register reinterpret_cast return
                short signed sizeof static static_assert static_cast struct switch
                template this thread_local throw true try typedef typeid typename
                union unsigned using
                virtual void volatile
                wchar_t while
                xor xor_eq
            }
            "python" {
                and as assert async await
                break
                class continue
                def del
                elif else except
                False finally for from
                global
                if import in is
                lambda
                None nonlocal not
                or
                pass
                raise return
                True try
                while with
                yield
            }
        }

        set suggestions {
            if   {interface}
            int  {internal irq}
            pass {passed}
        }

        foreach l [dict keys $reserved_names] {
            foreach k [dict get $reserved_names $l] {
                set s {}
                if {[dict exists $suggestions $k]} {
                    set s [dict get $suggestions $k]
                }

                if {[dict exists ${_reserved_names_dict} $k]} {
                    lassign [dict get ${_reserved_names_dict} $k] langs os
                    lappend langs $l
                } else {
                    set langs [list $l]
                }

                dict set _reserved_names_dict $k [list $langs $s]
            }
        }

        return ${_reserved_names_dict}
    }

    ## @brief Run individual naming conflicts check.
    # @param check_name name to check
    # @param ref_name name for reference in warn message
    # @param origin origin string for warn message
    proc check_regfile_name_string {check_name ref_name {origin {}}} {
        set reserved_names [get_reserved_names]

        if {$origin ne {}} {set origin " ${origin}"}

        # internal names
        if {[string match {_*} $check_name]} {
            ig::log -warn -id "ChkRN" "${ref_name} has a name which potentially conflicts with internal types/names${origin}"
        }
        # reserved keywords
        if {[dict exists $reserved_names $check_name]} {
            lassign [dict get $reserved_names $check_name] langs suggestion

            if {[llength $suggestion] > 0} {
                set suggestion ", maybe use [join [lmap s $suggestion {set _ "\"$s\""}] " or "] instead"
            }
            ig::log -warn -id "ChkRN" "${ref_name} has a name which conflicts with keywords in [join $langs ", "]${suggestion}${origin}"
        }
    }

    ## @brief Run regfile naming conflicts check.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_regfile_names {regfile_data} {
        set rfname  [dict get $regfile_data "name"]
        set entries [dict get $regfile_data "entries"]

        check_regfile_name_string $rfname "regfile \"${rfname}\""

        foreach i_entry $entries {
            set ename [dict get $i_entry "name"]
            set regs  [dict get $i_entry "regs"]
            set oid   [dict get $i_entry "object"]
            set origin {}
            if {$oid ne {}} {
                set origin [ig::db::get_attribute -object $oid -attribute "origin" -default {}]
            }

            check_regfile_name_string $ename "entry \"${ename}\"" "(regfile ${rfname}) (${origin})"

            foreach i_reg $regs {
                set rname  [dict get $i_reg "name"]
                if {$rname eq {-}} continue

                check_regfile_name_string $rname "register \"${rname}\" in entry \"${ename}\"" "(regfile ${rfname}) (${origin})"
            }
        }
    }

    ## @brief Run check for allowed register types.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_regfile_regtypes {regfile_data} {
        set rfname   [dict get $regfile_data "name"]
        set regtypes [ig::db::get_attribute -object [dict get $regfile_data "object"] -attribute "regtypes" -default {}]
        set entries  [dict get $regfile_data "entries"]

        if {$regtypes eq {}} {
            ig::log -warn -id "ChkRT" "Regfile $rfname has no allowed register types (regtypes) defined in template init"
            return
        }

        foreach i_entry $entries {
            set ename [dict get $i_entry "name"]
            set regs  [dict get $i_entry "regs"]
            set oid   [dict get $i_entry "object"]
            set origin {}
            if {$oid ne {}} {
                set origin [ig::db::get_attribute -object $oid -attribute "origin" -default {}]
            }

            foreach i_reg $regs {
                set rname [dict get $i_reg "name"]
                set rtype [dict get $i_reg "type"]
                if {$rname eq {-}} continue

                if {$rtype ni $regtypes} {
                    ig::log -warn -id "ChkRT" "Register \"${rname}\" in entry \"${ename}\" has incompatible type \"${rtype}\" (regfile ${rfname}) (${origin})"
                }
            }
        }
    }

    ## @brief Run check for regfile port interface.
    # @param regfile_data preprocessed data of regfile to check.
    proc check_module_regfile_ports {module_id regfile_id} {
        set mname     [ig::db::get_attribute -object $module_id -attribute "name"]
        set rfname    [ig::db::get_attribute -object $regfile_id -attribute "name"]
        set rfports   [ig::db::get_attribute -object $regfile_id -attribute "ports" -default {}]

        if {$rfports eq {}} {
            ig::log -warn -id "ChkRP" "Regfile $rfname has no port interface defined (ports) defined in template init"
            return
        }

        set mportdata {}
        foreach p [ig::db::get_ports -of $module_id] {
            set n [ig::db::get_attribute -object $p -attribute "name"]
            set s [ig::db::get_attribute -object $p -attribute "size"]
            dict set mportdata $n $s
        }

        foreach {tp tdata} $rfports {
            lassign $tdata tn ts

            if {[dict exists $mportdata $tn]} {
                set mps [dict get $mportdata $tn]
                if {[string is integer $ts] && [string is integer $mps] && ($ts != $mps)} {
                    ig::log -warn -id "ChkRP" "Regfile $rfname expects port $tn of size $ts, port in module $mname has size $mps"
                }
            } else {
                ig::log -warn -id "ChkRP" "Regfile $rfname expects port $tn as $tp in module $mname"
            }
        }
    }

    namespace export check_object
}

