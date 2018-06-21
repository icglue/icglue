<%-
set entry_list [regfile_to_arraylist $obj_id]
set rf_name [object_name $obj_id]
set header_name "rf_${rf_name}"
-%>
#ifndef __<[string toupper ${header_name}]>_H__
#define __<[string toupper ${header_name}]>_H__

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplis
extern "C" {
#endif

<%-
# iterate over entries sorted by address
foreach_array entry $entry_list {
    set arguments_read  {}
    set arguments_write {}

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

        if {$reg(type) eq "RW"} {
            lappend arguments_write "${rtype} ${reg(name)}"
            lappend write_regs $reg_data
        }

        if {$reg(type) ne "-"} {
            lappend arguments_read "${rtype} *${reg(name)}"
            lappend read_regs $reg_data
        }
    }
-%>

/* <%=${entry(name)}%> */
bool <%="rf_${rf_name}_${entry(name)}"%>_read  (<[join $arguments_read ", "]>);
bool <%="rf_${rf_name}_${entry(name)}"%>_write (<[join $arguments_write ", "]>);

bool <%="rf_${rf_name}_${entry(name)}"%>_wordread  (uint32_t *value);
bool <%="rf_${rf_name}_${entry(name)}"%>_wordwrite (uint32_t value);

<%+
    foreach_array reg $read_regs {
-%>
bool <%="rf_${rf_name}_${entry(name)}_${reg(name)}"%>_read (<%=$reg(type)%> *value);
<%+ } +%>
<%+
    foreach_array reg $write_regs {
-%>
bool <%="rf_${rf_name}_${entry(name)}_${reg(name)}"%>_write (<%=$reg(type)%> value);
<%+ } -%>

<%+
}
-%>

#ifdef __cplusplis
}
#endif

#endif
