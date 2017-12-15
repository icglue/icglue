#!/usr/bin/tclsh

load ../lib/icglue.so

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

# helpers
proc get_max_entry_len {data_list transform_proc} {
    set len 0
    foreach i_entry $data_list {
        set i_len [string length [$transform_proc $i_entry]]
        set len [expr {max ($len, $i_len)}]
    }
    return $len
}

proc size_to_bitrange {size} {
    if {[string is integer $size]} {
        if {$size == 1} {
            return ""
        } else {
            return "\[[expr {$size-1}]:0\]"
        }
    } else {
        return "\[$size-1:0\]"
    }
}

proc get_object_bitrange {obj} {
    set size [get_attribute -object $obj -attribute "size"]
    return [size_to_bitrange $size]
}

proc get_port_dir_vlog {port} {
    set dir [get_attribute -object $port -attribute "direction"]
    if {$dir == "input"} {return "input"}
    if {$dir == "output"} {return "output"}
    if {$dir == "bidirectional"} {return "inout"}
    return ""
}

proc get_object_name {obj} {
    return [get_attribute -object $obj -attribute "name"]
}

proc get_parameter_type_vlog {param} {
    if {[get_attribute -object $param -attribute "local"]} {
        return "localparam"
    } else {
        return "parameter"
    }
}

proc get_declaration_type_vlog {decl} {
    if {[get_attribute -object $decl -attribute "default_type"]} {
        return "wire"
    } else {
        return "reg"
    }
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
    set module_name [get_attribute -object $mod_id -attribute "name"]
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

proc is_last {lst entry} {
    if {[lindex $lst end] == $entry} {
        return "true"
    } else {
        return "false"
    }
}

proc output_codesection {codesection} {
    set do_adapt [get_attribute -object $codesection -attribute "adapt" -default "false"]
    set code [get_attribute -object $codesection -attribute "code"]
    if {!$do_adapt} {
        return $code
    }

    set parent_mod [get_attribute -object $codesection -attribute "parent"]
    set signal_replace [list]
    foreach i_port [get_ports -of $parent_mod -all] {
        set i_rep [list \
            [get_attribute -object $i_port -attribute "signal"] \
            [get_attribute -object $i_port -attribute "name"] \
        ]
        lappend signal_replace $i_rep
    }
    foreach i_decl [get_declarations -of $parent_mod -all] {
        set i_rep [list \
            [get_attribute -object $i_decl -attribute "signal"] \
            [get_attribute -object $i_decl -attribute "name"] \
        ]
        lappend signal_replace $i_rep
    }

    foreach i_rep $signal_replace {
        set i_orig  "\\m[lindex $i_rep 0]\\M"
        set i_subst [lindex $i_rep 1]

        regsub -all $i_orig $code $i_subst code
    }

    return $code
}

# source construction script
source module.construct.tcl

# generate modules
foreach i_module [get_modules -all] {
    if {![get_attribute -object $i_module -attribute "resource"]} {
        puts "generating module $i_module"
        gen_module $i_module
    }
}
