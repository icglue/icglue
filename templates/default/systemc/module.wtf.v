%(
    ##  icglue - verilog module template
%)
/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */
%(
    array set mod_data [module_to_arraylist $obj_id]

    set port_data_maxlen_dir   [max_array_entry_len $mod_data(ports) vlog.direction]
    set port_data_maxlen_range [max_array_entry_len $mod_data(ports) vlog.bitrange]

    set decl_data_maxlen_type  [max_array_entry_len $mod_data(declarations) vlog.type]
    set decl_data_maxlen_range [max_array_entry_len $mod_data(declarations) vlog.bitrange]

    set param_data_maxlen_type [max_array_entry_len $mod_data(parameters) vlog.type]
    set param_data_maxlen_name [max_array_entry_len $mod_data(parameters) name]


%)
[pop_keep_block_content keep_block_data "keep" "head" ".v" "
/*
 * Module: $mod_data(name)
 * Author:
 * E-Mail:
 */
"]

%(
    ###########################################
    ## ports
    ###########################################
    set portlist {}
    foreach_array port $mod_data(ports) {
        lappend portlist $port(name)
    }

    set portdecl [join $portlist ",\n        "]
    if {$portdecl ne ""} {
        set portdecl "\n        ${portdecl}\n    "
    }
%)
module $mod_data(name) ($portdecl)
    `ifdef INCA
         (* integer foreign = "SystemC"; *); // foreign attribute string value must be "SystemC"
    `else
        [pop_keep_block_content keep_block_data "keep" "my_attributes" ".v"]
        ;
    `endif

%(
    if {[llength $mod_data(parameters)] != 0} {
        log -warn "SystemC template does not support parameters!"
    }
%)

% foreach_array port $mod_data(ports) {
    [format "%-${port_data_maxlen_dir}s %${port_data_maxlen_range}s %s;" $port(vlog.direction) $port(vlog.bitrange) $port(name)]
% }

% foreach_array decl $mod_data(declarations) {
    [format "%-${decl_data_maxlen_type}s %${decl_data_maxlen_range}s %s;" $decl(vlog.type) $decl(vlog.bitrange)  $decl(name)]
%}

    // Cadence wrapper for SystemC module $mod_data(name)

endmodule
