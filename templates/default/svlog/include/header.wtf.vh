%(
    array set mod_data [module_to_arraylist $obj_id]

    set port_data_maxlen_dir   [max_array_entry_len $mod_data(ports) vlog.direction]
    set port_data_maxlen_range [max_array_entry_len $mod_data(ports) vlog.bitrange]

    set decl_data_maxlen_type  [max_array_entry_len $mod_data(declarations) vlog.type]
    set decl_data_maxlen_range [max_array_entry_len $mod_data(declarations) vlog.bitrange]

    set param_data_maxlen_type [max_array_entry_len $mod_data(parameters) vlog.type]
    set param_data_maxlen_name [max_array_entry_len $mod_data(parameters) name]

    set has_params [llength $mod_data(parameters)]
    set keepblocks [ig::db::get_attribute -object $obj_id -attribute "keepblocks" -default "false"]

    set portnames {}
%)
[pop_keep_block_content keep_block_data "keep" "head" "" "
/*
 * Module: $mod_data(name)
 * Author: $::env(USER)
 */
"]
[expr {$cell_define ? "\n`celldefine" : ""}]
%set mod_openening "("
%if {$has_params} {
% set mod_openening "#("
%}

`timescale 1ns/1ps
module $mod_data(name) $mod_openening
%(
### PARAMETERS ###
 foreach_array_preamble_epilog_join param $mod_data(parameters) {} {
echo "    [format "%-${param_data_maxlen_type}s %-${param_data_maxlen_name}s = %s" $param(vlog.type) $param(name) $param(value)]"
} { echo ",\n" } {echo "\n"}
 if {$has_params} {
%)
) (
% }
%(### PORT DECLARATION ###
foreach_array_preamble_epilog_join port $mod_data(ports) {} {
    echo "    [format "%-${port_data_maxlen_dir}s %${port_data_maxlen_range}s %s" $port(vlog.direction) $port(vlog.bitrange) $port(name)]"
    lappend portnames $port(name)
    if {$port(vlog.direction) eq "input" && [regexp {_o$} $port(name)]} {
        ig::log -warn -id VPRT "Suspicius name $port(name) for an input port (nameing convention would be output port)."
    }
    if {$port(vlog.direction) eq "output" && [regexp {_i$} $port(name)]} {
        ig::log -warn -id VPRT "Suspicius name $port(name) for an output port (nameing convention would be input port)."
    }
    if {[regexp {_i_i$} $port(name)] || [regexp {_o_o$} $port(name)]} {
        ig::log -warn -id VPRT "Suspicius portname $port(name)."
    }
} {echo ",\n"} {echo "\n"}
echo ");"
necho "\n    [cond_pop_keep_block_content keep_block_data "keep" "localparams"]"
%)
%
%### SIGNAL DECLARATION ###
%foreach_array_preamble decl $mod_data(declarations) { echo "\n\n" } {
    [format "%-${decl_data_maxlen_type}s %${decl_data_maxlen_range}s %s;" $decl(vlog.type) $decl(vlog.bitrange)  $decl(name)]
%}
%necho "    [cond_pop_keep_block_content keep_block_data "keep" "declarations"]"
