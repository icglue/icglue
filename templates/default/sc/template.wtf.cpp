%(
    ##  icglue - systemC module template

    array set mod_data [module_to_arraylist $obj_id]

%)
/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */

[pop_keep_block_content keep_block_data "keep" "include" {} "
#include <${mod_data(name)}.h>
"]

%(
    set initializers {}
    foreach_array port $mod_data(ports) {
        lappend initializers "${port(name)}(\"${port(name)}\")"
    }

    set initializers [join $initializers ",\n    "]
    set init_keep_block_name "sc_module(${mod_data(name)})_intialize"
    if {$initializers ne ""} {
        set idx [lsearch -index 1 $keep_block_data "$init_keep_block_name"]
        if {($idx >= 0)} {
            set keep_block_content [lindex $keep_block_data $idx 2]
            set no_ws_keep_block_content [string map {" " "" "\n" "" "\t" ""} $keep_block_content]
            if {$no_ws_keep_block_content ne ""} {
                append initializers ","
            }
        }
    }
    append initializers "\n[pop_keep_block_content keep_block_data "keep" "$init_keep_block_name"]"
%)
${mod_data(name)}::${mod_data(name)} (::sc_core::sc_module_name name) :
    $initializers
[pop_keep_block_content keep_block_data "keep" "sc_module(${mod_data(name)})_construct" {} "
{
    // TODO: add your constructor code here
    // NOTE: if the sc_module(${mod_data(name)})_initialize is *not* empty a comma to the last element will be added
    //SC_THREAD (testcase_control);

    //SC_THREAD (onEvent);
    //sensitive << eq;

    //SC_METHOD (onClock);
    //dont_initialize ();
    //sensitive_pos << clk_i;

    // NOTE: SC_THREAD can call the wait-functions, whereas SC_METHOD can't!!!
}
"]

[pop_keep_block_content keep_block_data "keep" "definition" {} "
// TODO: add your custom definitions here
// e.g.
//void ${mod_data(name)}::testcase_control ()
//{
//    // initialize outputs
//    write_o = SC_LOGIC_1
//
//    while (nrst_i != SC_LOGIC_1) {
//        wait (nrst_i.posedge_event ());
//    }
//
//    testcase ();
//    sc_stop ();
//    wait ();
//}
"]

#if   defined(XMSC)
    XMSC_MODULE_EXPORT(${mod_data(name)})
#elif defined(NCSC)
    NCSC_MODULE_EXPORT(${mod_data(name)})
#else
      SC_MODULE_EXPORT(${mod_data(name)})
#endif

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

