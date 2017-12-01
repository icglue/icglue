<%
    # tcl header
    set port_data  [get_ports        -module $mod_name]
    set param_data [get_parameters   -module $mod_name]
    set decl_data  [get_declarations -module $mod_name]
    set inst_data  [get_instances    -module $mod_name]
    set code_data  [get_codesections -module $mod_name]

    set port_data_maxlen_dir   [get_max_entry_len $port_data get_port_dir_vlog]
    set port_data_maxlen_range [get_max_entry_len $port_data get_port_bitrange]

    set decl_data_maxlen_type  [get_max_entry_len $decl_data get_declaration_type_vlog]
    set decl_data_maxlen_range [get_max_entry_len $decl_data get_declaration_bitrange]

    set param_data_maxlen_type [get_max_entry_len $param_data get_parameter_type_vlog]
    set param_data_maxlen_name [get_max_entry_len $param_data get_parameter_name]

    proc is_last {lst entry} {
        if {[lindex $lst end] == $entry} {
            return "true"
        } else {
            return "false"
        }
    }
%>
<%= [get_pragma_content $pragma_data "keep" "head"] %>

module <%= $mod_name %> (
    <%
    # module port list
    foreach i_port $port_data {
    %><%= [get_port_name $i_port] %><% if {![is_last $port_data $i_port]} { %>,
    <% }} %>
);

<%
    # module parameters
    foreach i_param $param_data { %><%= \
    [format "    %-${param_data_maxlen_type}s " [get_parameter_type_vlog $i_param]] \
%><%= \
    [format "%-${param_data_maxlen_name}s" [get_parameter_name $i_param]] \
%> = <%= [get_parameter_value $i_param] %>;
<% } %><%= [get_pragma_content $pragma_data "keep" "parameters"] %>

<%
    # module port details
    foreach i_port $port_data { %><%= \
    [format "    %-${port_data_maxlen_dir}s " [get_port_dir_vlog $i_port]] \
%><%= \
    [format "%${port_data_maxlen_range}s " [get_port_bitrange $i_port]] \
%><%= [get_port_name $i_port] %>;
<% } %>

<%
    # module declarations
    foreach i_decl $decl_data { %><%= \
    [format "    %-${decl_data_maxlen_type}s " [get_declaration_type_vlog $i_decl]] \
%><%= \
    [format "%${decl_data_maxlen_range}s " [get_declaration_bitrange $i_decl]] \
%><%= [get_declaration_name $i_decl] %>;
<% } %><%= [get_pragma_content $pragma_data "keep" "declarations"] %>

<%
    # submodule instanciations
    foreach i_inst $inst_data {
        set i_params [get_instance_parameter_list $i_inst]
        set i_has_params [llength $i_params]
        set i_params_maxlen_name [get_max_entry_len $i_params get_instance_parameter_name]

        set i_pins [get_instance_pin_list $i_inst]
        set i_pins_maxlen_name [get_max_entry_len $i_pins get_instance_pin_name]
%>
    <%= [get_instance_module $i_inst] %><% if {$i_has_params} { %> #(<%
    foreach j_param $i_params { %>
        .<%= [format "%-${i_params_maxlen_name}s" [get_instance_parameter_name $j_param]] %> (<%= [get_instance_parameter_value $j_param] %>)<% if {![is_last $i_params $j_param]} { %>,<% }} %>
    )<% } %> <%= [get_instance_name $i_inst] %> (<%
    foreach j_pin $i_pins { %>
        .<%= [format "%-${i_pins_maxlen_name}s" [get_instance_pin_name $j_pin]] %> (<%= [get_instance_pin_net $j_pin] %>)<% if {![is_last $i_pins $j_pin]} { %>,<% }} %>
    );
<% } %>
<%= [get_pragma_content $pragma_data "keep" "instances"] %>
<%
    # code sections
    foreach i_cs $code_data {
%>
<%= [get_codesection_code $i_cs] %>
<% } %>
<%= [get_pragma_content $pragma_data "keep" "code"] %>

endmodule
<% if {0} { %>
// vim: filetype=verilog_template
<% } %>
