/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */
%(
  set cell_define [ig::db::get_attribute -object $obj_id -attribute "cell" -default "false"]

  set port_data_maxlen_dir   [max_array_entry_len $mod_data(ports) vlog.direction]
  set port_data_maxlen_range [max_array_entry_len $mod_data(ports) vlog.bitrange]

  set decl_data_maxlen_type  [max_array_entry_len $mod_data(declarations) vlog.type]
  set decl_data_maxlen_range [max_array_entry_len $mod_data(declarations) vlog.bitrange]

  set param_data_maxlen_type [max_array_entry_len $mod_data(parameters) vlog.type]
  set param_data_maxlen_name [max_array_entry_len $mod_data(parameters) name]

  set has_params [llength $mod_data(parameters)]
  set has_ports  [llength $mod_data(ports)]
%)
[pop_keep_block_content keep_block_data "keep" "head" "" "
/*
 * Module: $mod_data(name)
 * Author:[expr {[info exists ::env(USER)] ? " $::env(USER)" : ""}]
 */
"]
`timescale 1ns/1ps

% if {$cell_define} {
`celldefine
% }
% set mod_paramopen ""
% set mod_emptypp ");"
% if {$systemverilog && $has_params} {
%   set mod_paramopen "#"
%   set mod_emptypp ""
% } elseif {$has_ports} {
%   set mod_emptypp ""
% }
module $mod_data(name) ${mod_paramopen}(${mod_emptypp}
% ### SV PARAMETERS ###
% if {$systemverilog && $has_params} {
%   foreach_array_preamble_epilog_join param $mod_data(parameters) {} {
%     set paramstr "[format "%-*s %-*s" $param_data_maxlen_type $param(vlog.type) $param_data_maxlen_name $param(name)] = $param(value)"
%   } {
    ${paramstr},
%   } {
    ${paramstr}
%   }
%   if {$has_ports} {
) (
%   } else {
) ();
%   }
% }
% ### PORTS ###
% foreach_array_preamble_epilog_join port $mod_data(ports) {} {
%   if {$systemverilog} {
%     set portstr "[format "%-*s %*s" $port_data_maxlen_dir $port(vlog.direction) $port_data_maxlen_range $port(vlog.bitrange)] $port(name)"
%     if {[string length $port(dimension)] > 0} {
%       append portstr " " $port(dimension)
%     }
%   } else {
%     set portstr $port(name)
%   }
% } {
    ${portstr},
% } {
    ${portstr}
);
% }
%
% if {!$systemverilog} {
%   ### PARAMETERS ###
%   foreach_array_preamble param $mod_data(parameters) {

%   } {
    [format "%-*s %-*s" $param_data_maxlen_type $param(vlog.type) $param_data_maxlen_name $param(name)] = $param(value);
%   }
    [pop_keep_block_content keep_block_data "keep" "parameters"]
%   ### PORT DECLARATION ###
%   foreach_array_preamble port $mod_data(ports) {

%   } {
    [format "%-*s %*s" $port_data_maxlen_dir $port(vlog.direction) $port_data_maxlen_range $port(vlog.bitrange)] $port(name);
%   }
% } else {
    [pop_keep_block_content keep_block_data "keep" "localparams"]
% }
%
% ### SIGNAL DECLARATION ###
% foreach_array_preamble decl $mod_data(declarations) {

% } {
%     if {[string length $decl(dimension)] > 0} {
%       set dim " $decl(dimension)"
%     } else {
%       set dim ""
%     }
    [format "%-*s %*s" $decl_data_maxlen_type $decl(vlog.type) $decl_data_maxlen_range $decl(vlog.bitrange)] $decl(name)${dim};
% }
    [pop_keep_block_content keep_block_data "keep" "declarations"]
