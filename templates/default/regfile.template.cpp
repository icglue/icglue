<%-
set entry_list [regfile_to_arraylist $obj_id]
set rf_name [object_name $obj_id]
set userparams [ig::db::get_attribute -object $obj_id -attribute "accesscargs" -default {}]



set header_name "rf_${rf_name}"
set base_addr "rf_baseaddr_${rf_name}"
set gen_doxy "true"

proc read_reg {} {
    return [uplevel 1 {regexp -nocase {^[^-W]*$} $reg(type)}]
}
proc write_reg {} {
    return [uplevel 1 {regexp -nocase {W} $reg(type)}]
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
    variable maxlen_reg
    set max_len_reg init
    foreach_array reg $regs {
        max_set maxlen_reg [string length $reg(name)]
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

set maxlen_entryname 0
foreach_array entry $entry_list {
    max_set maxlen_entryname [string length $entry(name)]
}
-%>
/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */

<[pop_keep_block_content keep_block_data "keep" "custom-header" ".cpp"]>

#include <<%=${header_name}%>.hpp>

<[rf_class]>::<[rf_class]> (regfile_dev &dev, rf_addr_t base_addr) :
    <[format "%-${maxlen_entryname}s"  regfile_t]> (dev, base_addr),<% foreach_array_join entry $entry_list { %>
    <[entry_name]> (*this, <%=$entry(address)%>, <[unused_mask]>), _<[entry_name _word]> (*this, <%=$entry(address)%>, <[unused_mask]>)<% } {%>,<%}%>
{
    <[pop_keep_block_content keep_block_data "keep" "custom-constr" ".cpp"]>
}

<% ## Entry Class Constructor ##
foreach_array entry $entry_list {
    set_max_len_reg [string length "_entry_t"] -%>
// constructor <%=$entry(name)%>
<[rf_class]>::<[entry_class]>::<[entry_class]> (regfile_t &rf, rf_addr_t addr, rf_data_t unused_mask) :
    // entry constructor:
    <[format "%-${maxlen_reg}s" _entry_t]> (rf, addr, unused_mask),
    // registers constructor:<% ; foreach_array_join_with reg $entry(regs) {$reg(name) ne "-"} {%>
    <[format "%-${maxlen_reg}s (*this, %2d, %2d)" $reg(name) $reg(bit_low) $reg(bit_high)]><%} {%>,<% } %>
{}

<% ## Entry Class operator= ## -%>
// overload assignment operator (<%=$entry(name)%>)
<[rf_class]>::<[entry_class]>& <[rf_class]>::<[entry_class]>::operator=(<[entry_struct]> rhs)
{
    union {
        <[entry_struct]> s;
        rf_data_t i;
    } temp;
    temp.s = rhs;

    _entry_t_write (temp.i);
    return *this;
}

<% ## Entry Class operator for entry_struct -%>
// overload type conversion operator (<%=$entry(name)%>)
<[rf_class]>::<[entry_class]>::operator <[entry_struct]> () {
    union {
        <[entry_struct]> s;
        rf_data_t i;
    } temp;
    temp.i = _entry_t_read ();

    return temp.s;
}

<% ## Entry Class operator for entry_struct -%>
// overload address of operator (<%=$entry(name)%>)
rf_data_t *<[rf_class]>::<[entry_class]>::operator&()
{
    return (rf_data_t *)(uintptr_t)_entry_t_addr();
}

<% } -%>
<[pop_keep_block_content keep_block_data "keep" "custom-decl" ".cpp"]>

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

