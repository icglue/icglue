#!/usr/bin/tclsh

# copied from: http://wiki.tcl.tk/18175
proc parse {txt} {
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

proc gen_module {author_data mod_data} {
    set _tt_name "module.template.v"

    set _outf_name "module.v"

    set _tt_f [open ${_tt_name} "r"]
    set _tt [read ${_tt_f}]
    close ${_tt_f}

    set _tt_code [parse ${_tt}]

    set mod_name [lindex $mod_data 0]
    set mod_description [lindex $mod_data 1]
    set author_name [lindex $author_data 0]
    set author_email [lindex $author_data 1]

    # dummy result - will be overwritten by eval
    set _res {}
    eval ${_tt_code}

    set _outf [open ${_outf_name} "w"]
    puts -nonewline ${_outf} ${_res}
    close ${_outf}
}

set mod_data [list \
    "testmodule" \
    "a simple module" \
]
set author_data [list \
    "Andreas Dixius" \
    "Andreas.Dixius@tu-dresden.de" \
]
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

proc get_port_bitrange {port} {
    set size [get_port_size $port]
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
proc get_port_dir_vlog {port} {
    set dir [get_port_dir $port]
    if {$dir == "i"} {return "input"}
    if {$dir == "o"} {return "output"}
    if {$dir == "b"} {return "inout"}
    return ""
}

proc get_param_name {param} {
    return [lindex $param 0]
}
proc get_param_type {param} {
    return [lindex $param 1]
}
proc get_param_value {param} {
    return [lindex $param 2]
}

proc get_param_type_vlog {param} {
    set type [get_param_type $param]
    if {$type == "l"} {return "localparam"}
    if {$type == "g"} {return "parameter"}
    return ""
}

proc get_ports args {
    variable port_data

    return $port_data
}
proc get_params args {
    variable param_data

    return $param_data
}

gen_module $author_data $mod_data
