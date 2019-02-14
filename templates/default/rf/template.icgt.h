<%-
set entry_list [regfile_to_arraylist $obj_id]
set rf_name [object_name $obj_id]
set userparams [ig::db::get_attribute -object $obj_id -attribute "accesscargs" -default {}]
set header_name "rf_${rf_name}"

proc read_reg {} {
    return [uplevel 1 {regexp -nocase {^[^-W]*$} $reg(type)}]
}
proc write_reg {} {
    return [uplevel 1 {regexp -nocase {W} $reg(type)}]
}
-%>
/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */
#ifndef __<[string toupper ${header_name}]>_H__
#define __<[string toupper ${header_name}]>_H__

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

<[pop_keep_block_content keep_block_data "keep" "custom" ".h"]>

<%-
# iterate over entries sorted by address
foreach_array entry $entry_list {
    set arguments_read  $userparams
    set arguments_write $userparams

    set write_regs {}
    set read_regs {}

    foreach_array reg $entry(regs) {
        if {[string is integer $reg(width)]} {
            if {$reg(width) <= 1} {
                set rtype "bool"
            } elseif {$reg(width) <= 8} {
                set rtype "uint8_t"
            } elseif {$reg(width) <= 16} {
                set rtype "uint16_t"
            } else {
                set rtype "uint32_t"
            }
        } else {
            set rtype "uint32_t"
        }

        set reg_data [list name $reg(name) type $rtype]

        if {[write_reg]} {
            lappend arguments_write "${rtype} ${reg(name)}"
            lappend write_regs $reg_data
        }

        if {$reg(type) ne "-"} {
            lappend arguments_read "${rtype} *${reg(name)}"
            lappend read_regs $reg_data
        }
    }

    set userparams_extra $userparams
    lappend userparams_extra {}
    set userparams_extra [join $userparams_extra ", "]

    if {[llength $read_regs] > 0} {
        set has_read 1
    } else {
        set has_read 0
    }
    if {[llength $write_regs] > 0} {
        set has_write 1
    } else {
        set has_write 0
    }
-%>

/* <%=${entry(name)}%> */
<%+ if {$has_read} { -%>
bool <%="rf_${rf_name}_${entry(name)}"%>_read  (<[join $arguments_read ", "]>);
<%+ } -%>
<%- if {$has_write} { -%>
bool <%="rf_${rf_name}_${entry(name)}"%>_write (<[join $arguments_write ", "]>);
<%+ } -%>

<%+ if {$has_read} { -%>
bool <%="rf_${rf_name}_${entry(name)}"%>_wordread  (<%=$userparams_extra%>uint32_t *value);
<%+ } -%>
<%- if {$has_write} { -%>
bool <%="rf_${rf_name}_${entry(name)}"%>_wordwrite (<%=$userparams_extra%>uint32_t value);
<%+ } -%>

<%+
    foreach_array reg $read_regs {
-%>
bool <%="rf_${rf_name}_${entry(name)}_${reg(name)}"%>_read (<%=$userparams_extra%><%=$reg(type)%> *value);
<%+ } +%>
<%+
    foreach_array reg $write_regs {
-%>
bool <%="rf_${rf_name}_${entry(name)}_${reg(name)}"%>_write (<%=$userparams_extra%><%=$reg(type)%> value);
<%+ } -%>

<%+
}
-%>

#ifdef __cplusplus
}
#endif

#endif
