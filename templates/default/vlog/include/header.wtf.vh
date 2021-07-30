%(
    array set mod_data [module_to_arraylist $obj_id]

    set port_data_maxlen_dir   [max_array_entry_len $mod_data(ports) vlog.direction]
    set port_data_maxlen_range [max_array_entry_len $mod_data(ports) vlog.bitrange]

    set decl_data_maxlen_type  [max_array_entry_len $mod_data(declarations) vlog.type]
    set decl_data_maxlen_range [max_array_entry_len $mod_data(declarations) vlog.bitrange]

    set param_data_maxlen_type [max_array_entry_len $mod_data(parameters) vlog.type]
    set param_data_maxlen_name [max_array_entry_len $mod_data(parameters) name]
    set keepblocks [ig::db::get_attribute -object $obj_id -attribute "keepblocks" -default "false"]
%)
[pop_keep_block_content keep_block_data "keep" "head" "" "
/*
 * Module: $mod_data(name)
 * Author:
 */
"]
`timescale 1ns/1ps
%echo "module $mod_data(name) ("
%### PORTS ###
%foreach_array_preamble_epilog_join port $mod_data(ports) {echo "\n"} {
% echo "        $port(name)" } { echo ",\n" } {echo "\n    "}
%echo ");\n"
%
%### PARAMETERS ###
%foreach_array_preamble param $mod_data(parameters) {echo "\n"} {
    [format "%-${param_data_maxlen_type}s %-${param_data_maxlen_name}s = %s;" $param(vlog.type) $param(name) $param(value)]
%}
    [pop_keep_block_content keep_block_data "keep" "parameters"]
%### PORT DECLARATION ###
%foreach_array_preamble port $mod_data(ports) {echo "\n"} {
    [format "%-${port_data_maxlen_dir}s %${port_data_maxlen_range}s %s;" $port(vlog.direction) $port(vlog.bitrange) $port(name)]
%}
%
%### SIGNAL DECLARATION ###
%foreach_array_preamble decl $mod_data(declarations) { echo "\n\n" } {
    [format "%-${decl_data_maxlen_type}s %${decl_data_maxlen_range}s %s;" $decl(vlog.type) $decl(vlog.bitrange)  $decl(name)]
%}
%echo "    [pop_keep_block_content keep_block_data "keep" "declarations"]"
