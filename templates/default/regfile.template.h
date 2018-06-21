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

        if {$reg(type) eq "RW"} {
            lappend arguments_write "${rtype} ${reg(name)}"
        }

        if {$reg(type) ne "-"} {
            lappend arguments_read "${rtype} *${reg(name)}"
        }
    }
-%>

bool <%="rf_${rf_name}_${entry(name)}"%>_read (<[join $arguments_read ", "]>);
bool <%="rf_${rf_name}_${entry(name)}"%>_write (<[join $arguments_write ", "]>);

<%-
}
-%>

#ifdef __cplusplis
}
#endif

#endif
