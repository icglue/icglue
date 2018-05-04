
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
        while {[set i [string first <% $txt]] != -1} {
            incr i -1
            append code "append _res [list [string range $txt 0 $i]]\n"
            set txt [string range $txt [expr {$i + 3}] end]
            if {[string index $txt 0] eq "="} {
                append code "append _res "
                set txt [string range $txt 1 end]
            }
            if {[set i [string first %> $txt]] == -1} {
                error "No matching %>"
            }
            incr i -1
            append code "[string range $txt 0 $i] \n"
            set txt [string range $txt [expr {$i + 3}] end]
        }
        if {$txt ne ""} { append code "append _res [list $txt]\n" }
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

        # dummy result - will be overwritten by eval
        set _res {}
        eval ${_tt_code}

        file mkdir [file dirname ${_outf_name}]
        set _outf [open ${_outf_name} "w"]
        puts -nonewline ${_outf} ${_res}
        close ${_outf}
    }
}
