<%-
set entry_list [regfile_to_arraylist $obj_id]
set rf_name [object_name $obj_id]
set userparams [ig::db::get_attribute -object $obj_id -attribute "accesscargs" -default {}]
set userparamsft {}
foreach i_param $userparams {
    append userparamsft "[lindex $i_param 1], "
}

set header_name "rf_${rf_name}"

proc read_reg {} {
    return [uplevel 1 {regexp -nocase {^[^-W]*$} $reg(type)}]
}
proc write_reg {} {
    return [uplevel 1 {regexp -nocase {W} $reg(type)}]
}

-%>


<[get_keep_block_content $keep_block_data "keep" "include" ".c" "
#ifndef RF_DIRECT_INC
#include \"rf_base.h\"
#include \"rf_${rf_name}.h\"
#endif
"]>

<[get_keep_block_content $keep_block_data "keep" "custom" ".c"]>

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
<%- if {$has_read} { +%>
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
<%+ } -%>
<%- if {$has_write} { +%>
bool <%="rf_${rf_name}_${entry(name)}"%>_write (<[join $arguments_write ", "]>)
{
    uint32_t value = 0;

<%+
    set maxlen_name [max_array_entry_len $read_regs name]
    set maxlen_mask [max_array_entry_len $read_regs mask]

    foreach_array reg $write_regs {
-%>
    value |= (((uint32_t) <[format "%-${maxlen_name}s" $reg(name)]> & <[format "%${maxlen_mask}s" $reg(mask)]>) << <%=$reg(lsb)%>);
<%+ } -%>

    bool result = rf_<%=${rf_name}%>_write (<%=$userparamsft%><%=$address%>, value);
    return result;
}
<%+ } -%>
<%- if {$has_read} { +%>
bool <%="rf_${rf_name}_${entry(name)}"%>_wordread (<%=$userparams_extra%>uint32_t *value)
{
    return rf_<%=${rf_name}%>_read (<%=$userparamsft%><%=$address%>, value);
}
<%+ } -%>
<%- if {$has_write} { +%>
bool <%="rf_${rf_name}_${entry(name)}"%>_wordwrite (<%=$userparams_extra%>uint32_t value)
{
    return rf_<%=${rf_name}%>_write (<%=$userparamsft%><%=$address%>, value);
}
<%+ } -%>

<%-
    foreach_array reg $read_regs {
+%>
bool <%="rf_${rf_name}_${entry(name)}_${reg(name)}"%>_read (<%=$userparams_extra%><%=$reg(type)%> *value)
{
    uint32_t rf_value = 0;
    bool result = rf_<%=${rf_name}%>_read (<%=$userparamsft%><%=$address%>, &rf_value);

    if (value != NULL) *value = ((rf_value >> <%=$reg(lsb)%>) & <%=$reg(mask)%>);

    return result;
}
<%+ } +%>
<%-
    foreach_array reg $write_regs {
+%>
bool <%="rf_${rf_name}_${entry(name)}_${reg(name)}"%>_write (<%=$userparams_extra%><%=$reg(type)%> value)
{
    uint32_t rf_value = 0;
    bool result = rf_<%=${rf_name}%>_read (<%=$userparamsft%><%=$address%>, &rf_value);

    rf_value &= ~(<%=$reg(mask)%> << <%=$reg(lsb)%>);

    rf_value |= (((uint32_t) value & <%=$reg(mask)%>) << <%=$reg(lsb)%>);

    result &= rf_<%=${rf_name}%>_write (<%=$userparamsft%><%=$address%>, rf_value);
    return result;
}
<%+ } -%>

<%-
}
-%>
