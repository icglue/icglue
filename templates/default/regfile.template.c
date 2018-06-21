<%-
set entry_list [regfile_to_arraylist $obj_id]
set rf_name [object_name $obj_id]
set userparams [ig::db::get_attribute -object $obj_id -attribute "rfparams" -default {}]
set userparamsft {}
foreach i_param $userparams {
    append userparamsft "[lindex $i_param 1], "
}

set header_name "rf_${rf_name}"
-%>

#include "rf_base.h"
#include "rf_<%=${rf_name}%>.h"

<%-
# iterate over entries sorted by address
foreach_array entry $entry_list {
    set arguments_read  $userparams
    set arguments_write $userparams

    set write_regs {}
    set read_regs {}

    set address [format "0x%08x" $entry(address)]

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
            set mask [format "0x%x" [expr {(1 << $reg(width)) - 1}]]
        } else {
            set rtype "uint32_t"
            set mask "((1 << $reg(width)) - 1)"
        }

        set reg_data [list name $reg(name) width $reg(width) lsb $reg(bit_low) mask $mask type $rtype]

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
bool <%="rf_${rf_name}_${entry(name)}"%>_read (<[join $arguments_read ", "]>)
{
    uint32_t value = 0;
    bool result = rf_<%=${rf_name}%>_read (<%=$userparamsft%><%=$address%>, &value);

<%+
    set maxlen_name [expr {[max_array_entry_len $read_regs name] + 1}]
    set maxlen_lsb  [max_array_entry_len $read_regs lsb]

    foreach_array reg $read_regs {
-%>
    if (<[format "%-${maxlen_name}s" "${reg(name)}"]>!= NULL) <[format "%-${maxlen_name}s" "*${reg(name)}"]> = ((value >> <[format "%${maxlen_lsb}s" $reg(lsb)]>) & <%=$reg(mask)%>);
<%+ } -%>

    return result;
}

bool <%="rf_${rf_name}_${entry(name)}"%>_write (<[join $arguments_write ", "]>)
{
    uint32_t value = 0;

<%+
    set maxlen_name [max_array_entry_len $read_regs name]
    set maxlen_mask [max_array_entry_len $read_regs mask]

    foreach_array reg $read_regs {
-%>
    value |= (((uint32_t) <[format "%-${maxlen_name}s" $reg(name)]> & <[format "%${maxlen_mask}s" $reg(mask)]>) << <%=$reg(lsb)%>);
<%+ } -%>

    bool result = rf_<%=${rf_name}%>_write (<%=$userparamsft%><%=$address%>, value);
    return result;
}

bool <%="rf_${rf_name}_${entry(name)}"%>_wordread  (uint32_t *value)
{
    return rf_<%=${rf_name}%>_read (<%=$userparamsft%><%=$address%>, value);
}

bool <%="rf_${rf_name}_${entry(name)}"%>_wordwrite (uint32_t value)
{
    return rf_<%=${rf_name}%>_write (<%=$userparamsft%><%=$address%>, value);
}

<%-
    foreach_array reg $read_regs {
+%>
bool <%="rf_${rf_name}_${entry(name)}_${reg(name)}"%>_read (<%=$reg(type)%> *value)
{
    uint32_t value = 0;
    bool result = rf_<%=${rf_name}%>_read (<%=$userparamsft%><%=$address%>, &value);

    if (<%=$reg(name)%>!= NULL) <%=$reg(name)%> = ((value >> <%=$reg(lsb)%>) & <%=$reg(mask)%>);

    return result;
}
<%+ } +%>
<%-
    foreach_array reg $write_regs {
+%>
bool <%="rf_${rf_name}_${entry(name)}_${reg(name)}"%>_write (<%=$reg(type)%> value)
{
    uint32_t value = 0;
    bool result = rf_<%=${rf_name}%>_read (<%=$userparamsft%><%=$address%>, &value);

    value &= ((~<%=$reg(mask)%>) << <%=$reg(lsb)%>);

    value |= (((uint32_t) <%=$reg(name)%> & <%=$reg(mask)%>) << <%=$reg(lsb)%>);

    result &= rf_<%=${rf_name}%>_write (<%=$userparamsft%><%=$address%>, value);
    return result;
}
<%+ } -%>

<%-
}
-%>
