% ### SUBMODULE INSTANCIATIONS ###
%foreach_array_preamble inst $mod_data(instances) {echo "\n\n"} {
% set i_params_maxlen_name [max_array_entry_len $inst(parameters) name]
% set i_pins_maxlen_name   [max_array_entry_len $inst(pins) name]
% set buswidth [ig::db::get_attribute -object $inst(object) -attribute "buswidth" -default {}]
% set busdecl {}
% if {$buswidth ne ""} {
%     set busdecl " [ig::vlog::bitrange $buswidth]"
% }
% if {$inst(hasparams)} {
%  echo "    $inst(module.name) #(\n"
%  foreach_array_join param $inst(parameters) {
%   echo "        .[format "%-${i_params_maxlen_name}s (%s)" $param(name) $param(value)]"
%  } { echo ",\n" }
%  echo "\n    ) i_${inst(name)}$busdecl ("
% } else {
%  echo "    $inst(module.name) i_${inst(name)}$busdecl ("
% }
% foreach_array_preamble_epilog_join pin $inst(pins) {echo "\n"} {
%  echo "        .[format "%-${i_pins_maxlen_name}s (%s%s)" $pin(name) [expr {$pin(invert) ? "~" : ""}] $pin(connection)]"
% } {echo ",\n"} {echo "\n    "}
%echo ");"


%}

    [pop_keep_block_content keep_block_data "keep" "instances"]
% ### CODE ###
%foreach_array_preamble cs $mod_data(code) {echo "\n"} {
% echo $cs(code)
%}
    [pop_keep_block_content keep_block_data "keep" "code"]
