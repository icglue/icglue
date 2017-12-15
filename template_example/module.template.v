<%
    # tcl header
    set port_data  [get_ports        -of $mod_id]
    set param_data [get_parameters   -of $mod_id]
    set decl_data  [get_declarations -of $mod_id]
    set inst_data  [get_instances    -of $mod_id]
    set code_data  [get_codesections -of $mod_id]

    set port_data_maxlen_dir   [get_max_entry_len $port_data get_port_dir_vlog]
    set port_data_maxlen_range [get_max_entry_len $port_data get_object_bitrange]

    set decl_data_maxlen_type  [get_max_entry_len $decl_data get_declaration_type_vlog]
    set decl_data_maxlen_range [get_max_entry_len $decl_data get_object_bitrange]

    set param_data_maxlen_type [get_max_entry_len $param_data get_parameter_type_vlog]
    set param_data_maxlen_name [get_max_entry_len $param_data get_object_name]
%>
<%= [get_pragma_content $pragma_data "keep" "head"] %>

module <%= [get_attribute -object $mod_id -attribute "name"] %> (<%
    # module port list
    foreach i_port $port_data {
    %>
    <%= [get_attribute -object $i_port -attribute "name"] %><% if {![is_last $port_data $i_port]} { %>,<% }} %>
);

<%
    # module parameters
    foreach i_param $param_data { %><%= \
    [format "    %-${param_data_maxlen_type}s " [get_parameter_type_vlog $i_param]] \
%><%= \
    [format "%-${param_data_maxlen_name}s" [get_attribute -object $i_param -attribute "name"]] \
%> = <%= [get_attribute -object $i_param -attribute "value"] %>;
<% } %><%= [get_pragma_content $pragma_data "keep" "parameters"] %>

<%
    # module port details
    foreach i_port $port_data { %><%= \
    [format "    %-${port_data_maxlen_dir}s " [get_port_dir_vlog $i_port]] \
%><%= \
    [format "%${port_data_maxlen_range}s " [get_object_bitrange $i_port]] \
%><%= [get_attribute -object $i_port -attribute "name"] %>;
<% } %>

<%
    # module declarations
    foreach i_decl $decl_data { %><%= \
    [format "    %-${decl_data_maxlen_type}s " [get_declaration_type_vlog $i_decl]] \
%><%= \
    [format "%${decl_data_maxlen_range}s " [get_object_bitrange $i_decl]] \
%><%= [get_attribute -object $i_decl -attribute "name"] %>;
<% } %><%= [get_pragma_content $pragma_data "keep" "declarations"] %>

<%
    # submodule instanciations
    foreach i_inst $inst_data {
        set i_params [get_adjustments -of $i_inst -all]
        set i_has_params [llength $i_params]
        set i_params_maxlen_name [get_max_entry_len $i_params get_object_name]

        set i_pins [get_pins -of $i_inst -all]
        set i_pins_maxlen_name [get_max_entry_len $i_pins get_object_name]
%>
    <%= [get_attribute -object [get_modules -of $i_inst] -attribute "name"] %><% if {$i_has_params} { %> #(<%
    foreach j_param $i_params { %>
        .<%= [format "%-${i_params_maxlen_name}s" [get_attribute -object $j_param -attribute "name"]] %> (<%= [get_attribute -object $j_param -attribute "value"] %>)<% if {![is_last $i_params $j_param]} { %>,<% }} %>
    )<% } %> <%= [get_attribute -object $i_inst -attribute "name"] %> (<%
    foreach j_pin $i_pins { %>
        .<%= [format "%-${i_pins_maxlen_name}s" [get_attribute -object $j_pin -attribute "name"]] %> (<%= [get_attribute -object $j_pin -attribute "connection"] %>)<% if {![is_last $i_pins $j_pin]} { %>,<% }} %>
    );
<% } %>
<%= [get_pragma_content $pragma_data "keep" "instances"] %>
<%
    # code sections
    foreach i_cs $code_data {
%>
<%= [output_codesection $i_cs] %>
<% } %>
<%= [get_pragma_content $pragma_data "keep" "code"] %>

endmodule
<% if {0} { %>
// vim: filetype=verilog_template
<% } %>
