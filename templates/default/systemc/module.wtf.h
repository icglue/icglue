%(
    ##  icglue - systemC module template

    array set mod_data [module_to_arraylist $obj_id]

    proc sc_type {} {
        upvar port(size) size port(direction) dir
        set type "< sc_logic >  "
        if {$size > 1} {
            set type "< sc_lv<[format "%3d" ${size}]> >"
        }

        switch $dir {
            input  {return "sc_in  $type"}
            output {return "sc_out $type"}
            inout  {return "sc_inout $type"}
        }
        log -warn "Can't translate type $type to systemC."
    }
%)
/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */

#ifndef __[string toupper ${mod_data(name)}]_H__
#define __[string toupper ${mod_data(name)}]_H__

[pop_keep_block_content keep_block_data "keep" "include" ".h" "
#include <systemc.h>
"]

%(
    set sc_module {}
    lappend sc_module "class $mod_data(name) : public sc_module {"
    lappend sc_module "    public:"
    lappend sc_module "        SC_HAS_PROCESS (${mod_data(name)});"
    lappend sc_module "        ${mod_data(name)} (::sc_core::sc_module_name name);"
    set sc_module [join $sc_module "\n"]
%)

[pop_keep_block_content keep_block_data "keep" "sc_module(${mod_data(name)})" ".h" "
$sc_module
"]

        // interface declaration
% foreach_array port $mod_data(ports) {
        [sc_type] ${port(name)};
% }

        // additional declaration
    [pop_keep_block_content keep_block_data "keep" "class-decl" ".h" "
    private:
        //TODO: add your custom declarations here
        //e.g.
        //void testcase_control ();
        //void testcase ();

        //void onEvent ();
        //sc_event_queue eq;
        //void onClock();
    "]
};

[pop_keep_block_content keep_block_data "keep" "header-decl" ".h"]

%(
    ## orphaned keep-blocks
    set rem_keeps [remaining_keep_block_contents $keep_block_data]
    if {[llength $rem_keeps] > 0} {
        log -warn "There are orphaned keep blocks in the verilog source - they will be appended to the code."
%)
#if 0
    /* orphaned icglue keep blocks ...
     * TODO: remove if unnecessary or reintegrate
     */
% foreach b $rem_keeps {
    $b
%}
#endif
%}
#endif
