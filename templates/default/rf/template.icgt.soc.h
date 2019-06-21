<%-
set entry_list [regfile_to_arraylist $obj_id]
set rf_name [object_name $obj_id]
set padding_to [ig::db::get_attribute -object $obj_id -attribute "pad_to" -default {0}]

set header_name "rf_${rf_name}"

proc entry_name {{suffix ""}} {
        upvar entry(name) name maxlen_entryname len
        set suffix_len [string length "$suffix"]
        set l [expr {$len + $suffix_len}]
        return [format "%-*s" $l "${name}${suffix}"]
    }

proc rf_class {} {
    variable rf_name
    return "rf_${rf_name}_t"
}

proc entry_struct {} {
    upvar rf_name rf_name entry(name) name
    return "${rf_name}_${name}_t"
}

proc entry_struct_padded {} {
    upvar rf_name rf_name entry(name) name maxlen_entryname len
    set other_len [string length "${rf_name}__t"]
    set l [expr {$len + $other_len}]
    return [format "%-*s" $l "${rf_name}_${name}_t"]
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

proc struct_reg_entry {} {
    upvar reg(name) name reg(width) width reg(comment) comment max_len_reg max_len_reg unused_reg unused_reg
    if {$name ne "-"} {
        return "rf_data_t [format "%-${max_len_reg}s : %2d" $name $width]; // $comment"
    } else {
        return "rf_data_t [format "%-${max_len_reg}s : %2d" $unused_reg $width];"
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
    uint32_t _padding_<%= $unused_idx %>[<%= $fill_size %>]; /* unused */<%
        }%>
    union {<[entry_struct_padded]> <[entry_name ";"]>  uint32_t _<%=$entry(name)%>_word;};<[format {%*s} [expr {$maxlen_entryname - [string length $entry(name)]}] ""]> // <%= $entry(name) %><%
        set next_address [expr {$entry(address) + 4}]
    }
    if {$padding_to > 0} {
        set fill_size [expr {($padding_to - $next_address) / 4}]
        incr unused_idx
        %>
    uint32_t _padding_<%= $unused_idx %>[<%= $fill_size %>]; /* unused */<%
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
