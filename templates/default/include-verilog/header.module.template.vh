<%
    ##  icglue - module template

    array set mod_data [module_to_arraylist $obj_id]

    set port_data_maxlen_dir   [max_array_entry_len $mod_data(ports) vlog.direction]
    set port_data_maxlen_range [max_array_entry_len $mod_data(ports) vlog.bitrange]

    set decl_data_maxlen_type  [max_array_entry_len $mod_data(declarations) vlog.type]
    set decl_data_maxlen_range [max_array_entry_len $mod_data(declarations) vlog.bitrange]

    set param_data_maxlen_type [max_array_entry_len $mod_data(parameters) vlog.type]
    set param_data_maxlen_name [max_array_entry_len $mod_data(parameters) name]


-%>

<%-= [get_keep_block_content $keep_block_data "keep" "head" ".v" "
/*
 * Module: $mod_data(name)
 * Author:
 * E-Mail:
 */
"] -%>

module <%=$mod_data(name)%> (
<%-
    ###########################################
    ## <module port list>
    foreach_array_preamble_epilog_join port $mod_data(ports) {%><%="\n"%><% } { -%>
        <%=$port(name)%><% } { -%>,<%="\n"%><% } { %>
    <% } %>);<%
    ## </module port list>
    ###########################################
%>
<%
    ###########################################
    ## <parameters>
    foreach_array_preamble param $mod_data(parameters) { %><%="\n"%><% } { -%>
    <[format "%-${param_data_maxlen_type}s %-${param_data_maxlen_name}s = %s;\n" $param(vlog.type) $param(name) $param(value)]><% } -%>
    <[get_keep_block_content $keep_block_data "keep" "parameters"]><%
    ## </parameters>
    ###########################################
%>
<%
    ###########################################
    ## <port declaration>
    foreach_array_preamble port $mod_data(ports) { -%><%="\n"%><% } { -%>
    <[format "%-${port_data_maxlen_dir}s %${port_data_maxlen_range}s %s;\n" $port(vlog.direction) $port(vlog.bitrange) $port(name)]><% }
    ## </port declaration>
    ###########################################
%>
<%-
    ###########################################
    ## <signal declaration>
    foreach_array_preamble decl $mod_data(declarations) { %><%="\n\n"%><% } { -%>
    <[format "%-${decl_data_maxlen_type}s %${decl_data_maxlen_range}s %s;\n" $decl(vlog.type) $decl(vlog.bitrange)  $decl(name)]><% } -%>
    <[get_keep_block_content $keep_block_data "keep" "declarations"]><%
    ## </signal declaration>
    ###########################################
-%>

<%- # vim: set filetype=verilog_template: -%>
