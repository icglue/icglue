<%
    # tcl header
    set port_data  [get_ports  -module $mod_name]
    set param_data [get_params -module $mod_name]

    set port_data_maxlen_dir   [get_max_entry_len $port_data get_port_dir_vlog]
    set port_data_maxlen_range [get_max_entry_len $port_data get_port_bitrange]

    set param_data_maxlen_type [get_max_entry_len $param_data get_param_type_vlog]
    set param_data_maxlen_name [get_max_entry_len $param_data get_param_name]

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
    foreach i_port $port_data {
    %><%= [get_port_name $i_port] %><% if {![is_last $port_data $i_port]} { %>,
    <% }} %>
);

<%
    foreach i_param $param_data { %><%= \
    [format "    %-${param_data_maxlen_type}s " [get_param_type_vlog $i_param]] \
%><%= \
    [format "%-${param_data_maxlen_name}s" [get_param_name $i_param]] \
%> = <%= [get_param_value $i_param] %>;
<% } %>
<%
    foreach i_port $port_data { %><%= \
    [format "    %-${port_data_maxlen_dir}s " [get_port_dir_vlog $i_port]] \
%><%= \
    [format "%${port_data_maxlen_range}s " [get_port_bitrange $i_port]] \
%><%= [get_port_name $i_port] %>;
<% } %>

endmodule
<% if {0} { %>
// vim: filetype=verilog_template
<% } %>
