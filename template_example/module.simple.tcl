#!/usr/bin/tclsh

package require ICGlue 0.0.1

# copied from: http://wiki.tcl.tk/18175
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

proc gen_module {mod_id} {
    set _tt_name [get_template_file $mod_id]

    set _outf_name [get_module_file $mod_id]

    set pragma_data [list]
    if {[file exists $_outf_name]} {
        set _outf [open ${_outf_name} "r"]
        set _old [read ${_outf}]
        close ${_outf}
        set pragma_data [parse_pragmas ${_old}]
    }
    set pragma_data [add_pragma_default_header $pragma_data $mod_id]

    set _tt_f [open ${_tt_name} "r"]
    set _tt [read ${_tt_f}]
    close ${_tt_f}

    set _tt_code [parse_template ${_tt}]

    # dummy result - will be overwritten by eval
    set _res {}
    eval ${_tt_code}

    set _outf [open ${_outf_name} "w"]
    puts -nonewline ${_outf} ${_res}
    close ${_outf}
}

proc get_pragma_content {pragma_data pragma_entry pragma_subentry} {
    set result {}
    append result "/* pragma icglue ${pragma_entry} begin ${pragma_subentry} */"
    foreach i_entry [lsearch -inline -all -index 1 [lsearch -inline -all -index 0 $pragma_data $pragma_entry] $pragma_subentry] {
        append result [lindex $i_entry 2]
    }
    append result "/* pragma icglue ${pragma_entry} end */"
}

proc add_pragma_default_header {pragma_data mod_id} {
    if {[lsearch -inline -all -index 1 [lsearch -inline -all -index 0 $pragma_data "keep"] "head"] < 0} {
        lappend pragma_data [list "keep" "head" [gen_default_header -module $mod_id]]
    }
    return $pragma_data
}

proc get_module_file {mod_id} {
    set module_name [ig::db::get_attribute -object $mod_id -attribute "name"]
    return "./${module_name}.v"
}

proc get_template_file {module} {
    return "./module.template.v"
}

proc gen_default_header args {
    set result {
/*
 * Module: a simple module
 * Author: Andreas Dixius
 * E-Mail: Andreas.Dixius@tu-dresden.de
 */
}

    return $result
}

# source construction script
#source module.construct.tcl
source module.sng.tcl
parse_sng_file test.sng

# generate modules
foreach i_module [ig::db::get_modules -all] {
    if {![ig::db::get_attribute -object $i_module -attribute "resource"]} {
        ig::log -info "generating module $i_module"
        gen_module $i_module
    }
}
