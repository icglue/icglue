#!/usr/bin/tclsh

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

proc gen_module {mod_name} {
    set _tt_name [get_template_file $mod_name]

    set _outf_name [get_module_file $mod_name]

    set pragma_data [list]
    if {[file exists $_outf_name]} {
        set _outf [open ${_outf_name} "r"]
        set _old [read ${_outf}]
        close ${_outf}
        set pragma_data [parse_pragmas ${_old}]
    }
    set pragma_data [add_pragma_default_header $pragma_data $mod_name]

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

set port_data [list \
    [list "clk_i"          i  1]  \
    [list "reset_n_i"      i  1]  \
    [list "data_i"         i  32] \
    [list "data_valid_i"   i  1]  \
    [list "result_o"       o  "RES_SIZE"] \
    [list "result_valid_o" o  1]  \
]
set param_data [list \
    [list "RES_SIZE"  g 8]                   \
    [list "RES_SEL_W" l "\$clog2(RES_SIZE)"] \
]
set decl_data [list \
    [list "temp_s"  w 8]        \
    [list "reg_a"   r RES_SIZE] \
    [list "temp2_s" w 1]        \
]
set inst_data [list \
    [list \
        "i_common_sync_res" \
        "common_sync" \
        [list \
            [list "SIZE" "RES_SIZE"] \
            [list "STAGES" "3"] \
        ] [list \
            [list "clk_i" "clk_i"] \
            [list "reset_n_i" "reset_n_i"] \
            [list "data_i" "reg_a"] \
            [list "data_o" "result_o"] \
        ] \
    ] \
    [list \
        "i_common_sync_valid" \
        "common_sync" \
        [list \
        ] [list \
            [list "clk_i" "clk_i"] \
            [list "reset_n_i" "reset_n_i"] \
            [list "data_i" "data_valid_i"] \
            [list "data_o" "temp2_s"] \
        ] \
    ] \
]
set code_data [list \
{
    always @(posedge clk_i or negedge reset_n_i) begin
        if (reset_n_i == 1'b0) begin
            reg_a <= 0;
        end else begin
            if (temp2_s == 1'b1) begin
                reg_a <= data_i[RES_SIZE-1:0];
            end
        end
    end
}
]

proc get_max_entry_len {data_list transform_proc} {
    set len 0
    foreach i_entry $data_list {
        set i_len [string length [$transform_proc $i_entry]]
        set len [expr {max ($len, $i_len)}]
    }
    return $len
}

proc get_port_size {port} {
    return [lindex $port 2]
}
proc get_port_name {port} {
    return [lindex $port 0]
}
proc get_port_dir {port} {
    return [lindex $port 1]
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

proc get_port_bitrange {port} {
    set size [get_port_size $port]
    return [size_to_bitrange $size]
}
proc get_port_dir_vlog {port} {
    set dir [get_port_dir $port]
    if {$dir == "i"} {return "input"}
    if {$dir == "o"} {return "output"}
    if {$dir == "b"} {return "inout"}
    return ""
}

proc get_parameter_name {param} {
    return [lindex $param 0]
}
proc get_parameter_type {param} {
    return [lindex $param 1]
}
proc get_parameter_value {param} {
    return [lindex $param 2]
}

proc get_parameter_type_vlog {param} {
    set type [get_parameter_type $param]
    if {$type == "l"} {return "localparam"}
    if {$type == "g"} {return "parameter"}
    return ""
}

proc get_declaration_name {decl} {
    return [lindex $decl 0]
}
proc get_declaration_type {decl} {
    return [lindex $decl 1]
}
proc get_declaration_size {decl} {
    return [lindex $decl 2]
}

proc get_declaration_bitrange {decl} {
    set size [get_declaration_size $decl]
    return [size_to_bitrange $size]
}
proc get_declaration_type_vlog {decl} {
    set type [get_declaration_type $decl]
    if {$type == "w"} {return "wire"}
    if {$type == "r"} {return "reg"}
    return ""
}

proc get_instance_name {inst} {
    return [lindex $inst 0]
}
proc get_instance_module {inst} {
    return [lindex $inst 1]
}
proc get_instance_parameter_list {inst} {
    return [lindex $inst 2]
}
proc get_instance_pin_list {inst} {
    return [lindex $inst 3]
}
proc get_instance_pin_name {pin} {
    return [lindex $pin 0]
}
proc get_instance_pin_net {pin} {
    return [lindex $pin 1]
}
proc get_instance_parameter_name {param} {
    return [lindex $param 0]
}
proc get_instance_parameter_value {param} {
    return [lindex $param 1]
}

proc get_codesection_code {section} {
    return $section
}

proc get_ports args {
    variable port_data
    return $port_data
}
proc get_parameters args {
    variable param_data
    return $param_data
}
proc get_declarations args {
    variable decl_data
    return $decl_data
}
proc get_instances args {
    variable inst_data
    return $inst_data
}
proc get_codesections args {
    variable code_data
    return $code_data
}

proc get_pragma_content {pragma_data pragma_entry pragma_subentry} {
    set result {}
    append result "/* pragma icglue ${pragma_entry} begin ${pragma_subentry} */"
    foreach i_entry [lsearch -inline -all -index 1 [lsearch -inline -all -index 0 $pragma_data $pragma_entry] $pragma_subentry] {
        append result [lindex $i_entry 2]
    }
    append result "/* pragma icglue ${pragma_entry} end */"
}

proc add_pragma_default_header {pragma_data mod_name} {
    if {[lsearch -inline -all -index 1 [lsearch -inline -all -index 0 $pragma_data "keep"] "head"] < 0} {
        lappend pragma_data [list "keep" "head" [gen_default_header -module $mod_name]]
    }
    return $pragma_data
}

proc get_module_file {module} {
    return "./${module}.v"
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

gen_module "test_module"
