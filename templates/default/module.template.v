<%
    # tcl header
    set port_data  [ig::db::get_ports        -of $mod_id]
    set param_data [ig::db::get_parameters   -of $mod_id]
    set decl_data  [ig::db::get_declarations -of $mod_id]
    set inst_data  [ig::db::get_instances    -of $mod_id]
    set code_data  [ig::db::get_codesections -of $mod_id]

    set port_data_maxlen_dir   [ig::aux::max_entry_len $port_data ig::vlog::port_dir]
    set port_data_maxlen_range [ig::aux::max_entry_len $port_data ig::vlog::obj_bitrange]

    set decl_data_maxlen_type  [ig::aux::max_entry_len $decl_data ig::vlog::declaration_type]
    set decl_data_maxlen_range [ig::aux::max_entry_len $decl_data ig::vlog::obj_bitrange]

    set param_data_maxlen_type [ig::aux::max_entry_len $param_data ig::vlog::param_type]
    set param_data_maxlen_name [ig::aux::max_entry_len $param_data ig::aux::object_name]
%>
<%= [ig::templates::get_pragma_content $pragma_data "keep" "head"] %>

module <%= [ig::db::get_attribute -object $mod_id -attribute "name"] %> (<%
    # module port list
    foreach i_port $port_data {
    %>
    <%= [ig::db::get_attribute -object $i_port -attribute "name"] %><% if {![ig::aux::is_last $port_data $i_port]} { %>,<% }} %>
);

<%
    # module parameters
    foreach i_param $param_data { %><%= \
    [format "    %-${param_data_maxlen_type}s " [ig::vlog::param_type $i_param]] \
%><%= \
    [format "%-${param_data_maxlen_name}s" [ig::db::get_attribute -object $i_param -attribute "name"]] \
%> = <%= [ig::db::get_attribute -object $i_param -attribute "value"] %>;
<% } %><%= [ig::templates::get_pragma_content $pragma_data "keep" "parameters"] %>

<%
    # module port details
    foreach i_port $port_data { %><%= \
    [format "    %-${port_data_maxlen_dir}s " [ig::vlog::port_dir $i_port]] \
%><%= \
    [format "%${port_data_maxlen_range}s " [ig::vlog::obj_bitrange $i_port]] \
%><%= [ig::db::get_attribute -object $i_port -attribute "name"] %>;
<% } %>

<%
    # module declarations
    foreach i_decl $decl_data { %><%= \
    [format "    %-${decl_data_maxlen_type}s " [ig::vlog::declaration_type $i_decl]] \
%><%= \
    [format "%${decl_data_maxlen_range}s " [ig::vlog::obj_bitrange $i_decl]] \
%><%= [ig::db::get_attribute -object $i_decl -attribute "name"] %>;
<% } %><%= [ig::templates::get_pragma_content $pragma_data "keep" "declarations"] %>

<%
    # submodule instanciations
    foreach i_inst $inst_data {
        set i_params [ig::db::get_adjustments -of $i_inst -all]
        set i_has_params [expr {[llength $i_params] && ![ig::db::get_attribute -object [ig::db::get_modules -of $i_inst] -attribute "ilm" -default "false"]}]
        set i_params_maxlen_name [ig::aux::max_entry_len $i_params ig::aux::object_name]

        set i_pins [ig::db::get_pins -of $i_inst -all]
        set i_pins_maxlen_name [ig::aux::max_entry_len $i_pins ig::aux::object_name]
%>
    <%= [ig::db::get_attribute -object [ig::db::get_modules -of $i_inst] -attribute "name"] %><% if {$i_has_params} { %> #(<%
    foreach j_param $i_params { %>
        .<%= [format "%-${i_params_maxlen_name}s" [ig::db::get_attribute -object $j_param -attribute "name"]] %> (<%= [ig::db::get_attribute -object $j_param -attribute "value"] %>)<% if {![ig::aux::is_last $i_params $j_param]} { %>,<% }} %>
    )<% } %> <%= [ig::db::get_attribute -object $i_inst -attribute "name"] %> (<%
    foreach j_pin $i_pins { %>
        .<%= [format "%-${i_pins_maxlen_name}s" [ig::db::get_attribute -object $j_pin -attribute "name"]] %> (<%= [ig::db::get_attribute -object $j_pin -attribute "connection"] %>)<% if {![ig::aux::is_last $i_pins $j_pin]} { %>,<% }} %>
    );
<% } %>
<%= [ig::templates::get_pragma_content $pragma_data "keep" "instances"] %>
<%
    # code sections
    foreach i_cs $code_data {
%>
<%= [ig::aux::adapt_codesection $i_cs] %>
<% } %>
<%= [ig::templates::get_pragma_content $pragma_data "keep" "code"] %>

endmodule
<% if {0} { %>
// vim: filetype=verilog_template
<% } %>
