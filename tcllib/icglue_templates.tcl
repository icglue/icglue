
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

namespace eval ig::templates {
    namespace eval collection {
        variable template_dir       {}
        variable template_path_gen  {}
        variable output_path_gen    {}
        variable default_header_gen {}
    }

    namespace eval init {
        proc template_dir  {template dir} {
            lappend ig::templates::collection::template_dir [list \
                $template $dir \
            ]
        }

        proc template_file {template body} {
            lappend ig::templates::collection::template_path_gen [list \
                $template $body \
            ]
        }

        proc output_file {template body} {
            lappend ig::templates::collection::output_path_gen [list \
                $template $body \
            ]
        }

        proc default_header {template body} {
            lappend ig::templates::collection::default_header_gen [list \
                $template $body \
            ]
        }
    }

    namespace eval current {
        variable template_dir ""

        proc get_template_file_raw {object template_dir} {
            ig::log -error -abort "no template loaded"
        }

        proc get_template_file {object} {
            variable template_dir
            return [get_template_file_raw $object $template_dir]
        }

        proc get_output_file {object} {
            ig::log -error -abort "no template loaded"
        }

        proc get_default_header {object} {
            ig::log -error -abort "no template loaded"
        }
    }

    namespace eval preprocess {
        # template helpers
        proc regfile_to_arraylist {regfile_id} {
            # collect all regfile entries, sort by address
            set entries [ig::db::get_regfile_entries -all -of $regfile_id]
            set entry_list {}
            foreach i_entry $entries {
                set reg_list {}
                set regs [ig::db::get_regfile_regs -all -of $i_entry]

                #entry_default_map {name width entrybits type reset signal signalbits}
                foreach i_reg $regs {
                    set name  [ig::db::get_attribute -object $i_reg -attribute "name"]
                    set width [ig::db::get_attribute -object $i_reg -attribute "rf_width" -default -1]
                    set entrybits [ig::db::get_attribute -object $i_reg -attribute "rf_entrybits" -default ""]
                    set type [ig::db::get_attribute -object $i_reg -attribute "rf_type" -default "RW"]
                    set reset [ig::db::get_attribute -object $i_reg -attribute "rf_reset" -default "-"]
                    set signal [ig::db::get_attribute -object $i_reg -attribute "rf_signal" -default "-"]
                    set signalbits [ig::db::get_attribute -object $i_reg -attribute "rf_signalbits" -default ""]

                    if {$width < 0} {
                        if {$entrybits eq ""} {
                            set width 32
                            set entrybits "31:0"
                        } else {
                            set blist [split $entrybits ":"]
                            set width [expr {[lindex $blist 1] - [lindex $blist 0] + 1}]
                        }
                    } elseif {$entrybits eq ""} {
                        set entrybits "[expr {$width - 1}]:0"
                    }

                    set blist [split $entrybits ":"]
                    set bit_high [lindex $blist 0]
                    set bit_low  [lindex $blist 1]

                    lappend reg_list [list \
                        $name $bit_high $bit_low $width $entrybits $type $reset $signal $signalbits $i_reg \
                    ]
                }
                set reg_list_raw [lsort -integer -index 2 $reg_list]
                set reg_list {}
                set idx_start 0

                foreach i_reg $reg_list_raw {
                    set i_bit_low [lindex $i_reg 2]
                    set i_bit_high [lindex $i_reg 1]
                    if {$i_bit_low - $idx_start > 1} {
                        set tmp_high [expr {$i_bit_low - 1}]
                        set tmp_low  [expr {$idx_start + 1}]
                        lappend reg_list [list \
                            name       "-" \
                            bit_high   $tmp_high \
                            bit_low    $tmp_low \
                            width      [expr {$tmp_high - $tmp_low + 1}] \
                            entrybits  "${tmp_high}:${tmp_low}" \
                            type       "-" \
                            reset      "-" \
                            signal     "-" \
                            signalbits "" \
                        ]
                    }
                    lappend reg_list [list \
                        name       [lindex $i_reg 0] \
                        bit_high   [lindex $i_reg 1] \
                        bit_low    [lindex $i_reg 2] \
                        width      [lindex $i_reg 3] \
                        entrybits  [lindex $i_reg 4] \
                        type       [lindex $i_reg 5] \
                        reset      [lindex $i_reg 6] \
                        signal     [lindex $i_reg 7] \
                        signalbits [lindex $i_reg 8] \
                        object     [lindex $i_reg 9] \
                    ]

                    set idx_start $i_bit_high
                }
                if {$idx_start < 31} {
                    set tmp_high 31
                    set tmp_low  [expr {$idx_start + 1}]
                    lappend reg_list [list \
                        name       "-" \
                        bit_high   $tmp_high \
                        bit_low    $tmp_low \
                        width      [expr {$tmp_high - $tmp_low + 1}] \
                        entrybits  "${tmp_high}:${tmp_low}" \
                        type       "-" \
                        reset      "-" \
                        signal     "-" \
                        signalbits "" \
                    ]
                }

                lappend entry_list [list \
                    address [ig::db::get_attribute -object $i_entry -attribute "address"] \
                    name    [ig::db::get_attribute -object $i_entry -attribute "name"] \
                    object  $i_entry \
                    regs    $reg_list \
                ]
            }
            set entry_list [lsort -integer -index 1 $entry_list]

            return $entry_list
        }

        proc instance_to_arraylist {instance_id} {
            set result {}

            set mod [ig::db::get_modules -of $instance_id]
            set ilm [ig::db::get_attribute -object $mod -attribute "ilm" -default "false"]

            lappend result name        [ig::db::get_attribute -object $instance_id -attribute "name"]
            lappend result object      $instance_id
            lappend result module      $mod
            lappend result ilm         $ilm
            lappend result module.name [ig::db::get_attribute -object $mod -attribute "name"]

            # pins
            set pin_data {}
            foreach i_pin [ig::db::get_pins -of $instance_id] {
                lappend pin_data [list \
                    name           [ig::db::get_attribute -object $i_pin -attribute "name"] \
                    object         $i_pin \
                    connection     [ig::db::get_attribute -object $i_pin -attribute "connection"] \
                ]
            }
            lappend result pins $pin_data

            # parameters
            set param_data {}
            foreach i_param [ig::db::get_adjustments -of $instance_id] {
                lappend param_data [list \
                    name           [ig::db::get_attribute -object $i_param -attribute "name"] \
                    object         $i_param \
                    value          [ig::db::get_attribute -object $i_param -attribute "value"] \
                ]
            }
            lappend result parameters $param_data

            lappend result hasparams [expr {(!$ilm) && ([llength $param_data] > 0)}]

            return $result
        }

        proc module_to_arraylist {module_id} {
            set result {}

            lappend result name   [ig::db::get_attribute -object $module_id -attribute "name"]
            lappend result object $module_id

            # ports
            set port_data {}
            foreach i_port [ig::db::get_ports -of $module_id] {
                lappend port_data [list \
                    name           [ig::db::get_attribute -object $i_port -attribute "name"] \
                    object         $i_port \
                    size           [ig::db::get_attribute -object $i_port -attribute "size"] \
                    vlog.bitrange  [ig::vlog::obj_bitrange $i_port] \
                    direction      [ig::db::get_attribute -object $i_port -attribute "direction"] \
                    vlog.direction [ig::vlog::port_dir $i_port] \
                ]
            }
            lappend result ports $port_data

            # parameters
            set param_data {}
            foreach i_param [ig::db::get_parameters -of $module_id] {
                lappend param_data [list \
                    name           [ig::db::get_attribute -object $i_param -attribute "name"] \
                    object         $i_param \
                    local          [ig::db::get_attribute -object $i_param -attribute "local"] \
                    vlog.type      [ig::vlog::param_type $i_param] \
                    value          [ig::db::get_attribute -object $i_param -attribute "value"] \
                ]
            }
            lappend result parameters $param_data

            # delarations
            set decl_data {}
            foreach i_decl [ig::db::get_declarations -of $module_id] {
                lappend decl_data [list \
                    name           [ig::db::get_attribute -object $i_decl -attribute "name"] \
                    object         $i_decl \
                    size           [ig::db::get_attribute -object $i_decl -attribute "size"] \
                    vlog.bitrange  [ig::vlog::obj_bitrange $i_decl] \
                    defaulttype    [ig::db::get_attribute -object $i_decl -attribute "default_type"] \
                    vlog.type      [ig::vlog::declaration_type $i_decl] \
                ]
            }
            lappend result declarations $decl_data

            # codesections
            set code_data {}
            foreach i_code [ig::db::get_codesections -of $module_id] {
                lappend code_data [list \
                    name           [ig::db::get_attribute -object $i_code -attribute "name"] \
                    object         $i_code \
                    code_raw       [ig::db::get_attribute -object $i_code -attribute "code"] \
                    code           [ig::aux::adapt_codesection $i_code] \
                ]
            }
            lappend result code $code_data

            # instances
            set inst_data {}
            foreach i_inst [ig::db::get_instances -of $module_id] {
                lappend inst_data [instance_to_arraylist $i_inst]
            }
            lappend result instances $inst_data

            # regfiles
            set regfile_data {}
            foreach i_regfile [ig::db::get_regfiles -of $module_id] {
                lappend regfile_data [list \
                    name    [ig::db::get_attribute -object $i_regfile -attribute "name"] \
                    object  $i_regfile \
                    entries [regfile_to_arraylist $i_regfile] \
                ]
            }

            return $result
        }
    }

    proc add_template_dir {dir} {
        set _tmpl_dirs [glob -directory $dir *]
        foreach _i_dir ${_tmpl_dirs} {
            set _initf_name "${_i_dir}/init.tcl"
            if {![file exists ${_initf_name}]} {
                continue
            }

            if {[catch {
                set _init_scr [open ${_initf_name} "r"]
                set _init [read ${_init_scr}]
                close ${_init_scr}
            }]} {
                continue
            }

            set template [file tail [file normalize [file dirname ${_initf_name}]]]
            eval ${_init}
            init::template_dir $template [file normalize "${dir}/${template}"]
        }
    }

    proc load_template {template} {
        # load vars/procs for current template
        set dir_idx  [lsearch -index 0 $collection::template_dir       $template]
        set tmpl_idx [lsearch -index 0 $collection::template_path_gen  $template]
        set out_idx  [lsearch -index 0 $collection::output_path_gen    $template]
        set hdr_idx  [lsearch -index 0 $collection::default_header_gen $template]

        if {($dir_idx < 0) || ($tmpl_idx < 0) || ($out_idx < 0) || ($hdr_idx < 0)} {
            ig::log -error -abort "template $template not (fully) defined"
        }

        set current::template_dir [lindex $collection::template_dir $dir_idx 1]
        proc current::get_template_file_raw {object template_dir} [lindex $collection::template_path_gen $tmpl_idx 1]
        proc current::get_output_file {object} [lindex $collection::output_path_gen $out_idx 1]
        proc current::get_default_header {object} [lindex $collection::default_header_gen $hdr_idx 1]
    }

    # parse_template method:
    # copied from: http://wiki.tcl.tk/18175
    # slightly modified to fit in here
    proc parse_template {txt} {
        set code "set _res {}\n"

        # search <% delimiter
        while {[set i [string first <% $txt]] != -1} {
            # check for right chomp
            set right_i [expr {$i - 1}]
            incr i 2
            if {[string match {[-+]} [string index $txt $i]]} {
                if {([string index $txt $i] eq "-") && ([string index $txt $right_i] eq "\n")} {
                    incr right_i -1
                }
                incr i
            }

            # append verbatim/normal template content (tcl-list)
            append code "append _res [list [string range $txt 0 $right_i]]\n"
            set txt [string range $txt $i end]

            if {[string index $txt 0] eq "="} {
                # <%= will be be append, but evaluated as tcl-argument
                append code "append _res "
                set txt [string range $txt 1 end]
            } else {
                # append as tcl code
            }

            # search %> delimiter
            if {[set i [string first %> $txt]] == -1} {
                error "No matching %>"
            }

            # check for left chomp
            set left_i [expr {$i + 2}]
            incr i -1
            if {[string match {[-+]} [string index $txt $i]]} {
                if {([string index $txt $i] eq "-") && ([string index $txt $left_i] eq "\n")} {
                    incr left_i
                }
                incr i -1
            }

            append code "[string range $txt 0 $i] \n"
            set txt [string range $txt $left_i end]
        }

        # append remainder of verbatim/normal template content
        if {$txt ne ""} {
            append code "append _res [list $txt]\n"
        }
        return $code
    }

    proc parse_pragmas {txt} {
        set result [list]
        while {[set i [string first "/* pragma icglue keep begin " $txt]] >= 0} {
            incr i 28
            if {[set j [string first " */" $txt $i]] < 0} {
                error "No end of pragma comment"
            }
            set type [string range $txt $i [expr {$j - 1}]]
            set txt [string range $txt [expr {$j + 3}] end]

            if {[set i [string first "/* pragma icglue keep end */" $txt]] < 0} {
                error "No end pragma after begin pragma"
            }
            set value [string range $txt 0 [expr {$i-1}]]
            set txt [string range $txt [expr {$i + 28}] end]

            lappend result [list "keep" $type $value]
        }
        return $result
    }

    proc add_pragma_default_header {pragma_data obj_id} {
        if {[lsearch -inline -all -index 1 [lsearch -inline -all -index 0 $pragma_data "keep"] "head"] < 0} {
            lappend pragma_data [list "keep" "head" [current::get_default_header $obj_id]]
        }
        return $pragma_data
    }

    proc get_pragma_content {pragma_data pragma_entry pragma_subentry} {
        set result {}
        append result "/* pragma icglue ${pragma_entry} begin ${pragma_subentry} */"
        foreach i_entry [lsearch -inline -all -index 1 [lsearch -inline -all -index 0 $pragma_data $pragma_entry] $pragma_subentry] {
            append result [lindex $i_entry 2]
        }
        append result "/* pragma icglue ${pragma_entry} end */"
    }


    proc write_object {obj_id} {
        set _tt_name [current::get_template_file $obj_id]

        set _outf_name [current::get_output_file $obj_id]

        set pragma_data [list]
        if {[file exists $_outf_name]} {
            set _outf [open ${_outf_name} "r"]
            set _old [read ${_outf}]
            close ${_outf}
            set pragma_data [parse_pragmas ${_old}]
        }
        set pragma_data [add_pragma_default_header $pragma_data $obj_id]

        set _tt_f [open ${_tt_name} "r"]
        set _tt [read ${_tt_f}]
        close ${_tt_f}

        set _tt_code [parse_template ${_tt}]

        # evaluate result in temporary namespace
        eval [join [list \
            "namespace eval _template_run \{" \
            "variable pragma_data [list $pragma_data]" \
            {variable _res {}} \
            "variable obj_id [list $obj_id]" \
            "eval [list ${_tt_code}]" \
            "\}" \
            ] "\n"]

        set _res ${_template_run::_res}
        namespace delete _template_run

        file mkdir [file dirname ${_outf_name}]
        set _outf [open ${_outf_name} "w"]
        puts -nonewline ${_outf} ${_res}
        close ${_outf}
    }
}
