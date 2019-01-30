<%-
set entry_list [regfile_to_arraylist $obj_id]
set rf_name [object_name $obj_id]
set userparams [ig::db::get_attribute -object $obj_id -attribute "accesscargs" -default {}]

set header_name "rf_${rf_name}"
set base_addr "rf_baseaddr_${rf_name}"

proc read_reg {} {
    return [uplevel 1 {regexp -nocase {^[^-W]*$} $reg(type)}]
}
proc write_reg {{level 1}} {
    upvar $level reg(type) type
    return [regexp -nocase {W} $type]
}
proc entry_name {{suffix ""}} {
        upvar entry(name) name maxlen_entryname len
        set suffix_len [string length "$suffix"]
        set l [expr {$len + $suffix_len}]
        return [format "%-${l}s" "${name}${suffix}"]
    }

proc rf_class {} {
    variable rf_name
    return "rf_${rf_name}_t"
}

proc entry_class {} {
    upvar entry(name) name
    return "${name}_t"
}

proc entry_struct {} {
    upvar rf_name rf_name entry(name) name
    return "${rf_name}_${name}_t"
}

proc set_max_len_reg {{init 0}} {
    upvar entry(regs) regs
    variable max_len_reg
    variable has_unused
    set max_len_reg $init
    set has_unused 0
    foreach_array reg $regs {
        max_set max_len_reg [string length $reg(name)]
        if {$reg(name) eq "-"} {
            set has_unused 1
        }
    }
}

proc unused_mask {} {
    upvar entry(regs) regs
    variable maxlen_reg
    set mask 0
    foreach_array_with reg $regs {$reg(name) eq "-"} {
        set mask [expr {$mask | (1<<(${reg(bit_high)}+1)) - (1<<(${reg(bit_low)}))}]
    }
    return [format "0x%08X" $mask]
}

proc struct_reg_entry {} {
    upvar reg(name) name reg(width) width reg(comment) comment max_len_reg max_len_reg unused_reg unused_reg
    if {$name ne "-"} {
        return "rf_data_t [format "%-${max_len_reg}s : %2d" $name $width]; // $comment"
    } else {
        return "rf_data_t [format "%-${max_len_reg}s : %2d" $unused_reg $width];"
    }
}

proc reg_class {} {
    if {[write_reg 2]} {
        return "_reg_rw_t"
    } else {
        return "_reg_ro_t"
    }
}
foreach_array entry $entry_list {
    max_set maxlen_entryname [string length $entry(name)]
}
-%>
/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */

#ifndef __<[string toupper "${header_name}"]>_H__
#define __<[string toupper "${header_name}"]>_H__

#include <stdint.h>

<[pop_keep_block_content keep_block_data "keep" "custom-header" ".h"]>

<% foreach_array entry $entry_list {
    set unused_reg "/* unused */"
    set_max_len_reg
    if {$has_unused} {
       max_set max_len_reg [string length $unused_reg]
    }
    %>
// REGFILE-><%=$entry(name)%>.REGISTER_NAME
typedef struct {<% foreach_array reg $entry(regs) {%>
    <[struct_reg_entry]><% } %>
} __attribute__((__packed__)) <[entry_struct]>;
<% } %>

<%
    set next_address 0
    set unused_idx 0
%>
typedef struct {<% foreach_array entry $entry_list {
        if {$entry(address) > $next_address} {
            set fill_size [expr {($entry(address) - $next_address) / 4}]
            incr unused_idx
    %>
    uint32_t _padding_<%= $unused_idx %>[<%= $fill_size %>];<%
        }%>
    union {
        <[entry_struct]> <%=$entry(name)%>;
        uint32_t _<%=$entry(name)%>_word;
    };<%
        set next_address [expr {$entry(address) + 4}]
    }
    %>
} __attribute__((__packed__)) <[rf_class]>;

<[pop_keep_block_content keep_block_data "keep" "custom-decl" ".h"]>

<%-
    ###########################################
    ## orphaned keep-blocks
    set rem_keeps [remaining_keep_block_contents $keep_block_data]
    if {[llength $rem_keeps] > 0} {
        log -warn "There are orphaned keep blocks in the verilog source - they will be appended to the code." %>

    #ifdef 0
        /* orphaned icglue keep blocks ...
         * TODO: remove if unnecessary or reintegrate
         */<%="\n\n"%><%-
        foreach b $rem_keeps { %>
    <%= "$b\n"%><% } %>
    #endif <%="\n\n"%><%- }
    ###########################################
-%>

#endif
