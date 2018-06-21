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

<%-= [get_pragma_content $pragma_data "keep" "head"] -%>

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
    <[get_pragma_content $pragma_data "keep" "parameters"]><%
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
    <[get_pragma_content $pragma_data "keep" "declarations"]><%
    ## </signal declaration>
    ###########################################
%>
<%-
    ###########################################
    ## <submodule instanciations>
    foreach_array_preamble inst $mod_data(instances) { %><%="\n"%><% } {
        set i_params_maxlen_name [max_array_entry_len $inst(parameters) name]
        set i_pins_maxlen_name   [max_array_entry_len $inst(pins) name]  %>
    <%=$inst(module.name)%><% if {$inst(hasparams)} { %> #(<%="\n"%><% foreach_array_join param $inst(parameters) { -%>
        .<[format "%-${i_params_maxlen_name}s (%s)" $param(name) $param(value)]><% } { %>,<%="\n"%><% } %>
    )<% } %> i_<%=$inst(name)%> (<%="\n"%><% foreach_array_join pin $inst(pins) { -%>
        .<[format "%-${i_pins_maxlen_name}s (%s%s)" $pin(name) [expr {$pin(invert) ? "~" : ""}] $pin(connection)]><% } { %>,<%="\n"%><% } %>
    );<% } %>

    <[get_pragma_content $pragma_data "keep" "instances"]><%
    ## </submodule instanciations>
    ###########################################
%>
<%-
    ###########################################
    ## <code>
    foreach_array_preamble cs $mod_data(code) { %><%="\n\n"%><% } {
    %><%="$cs(code)"%><% } %>
    <[get_pragma_content $pragma_data "keep" "code"]><%
    ## </code>
    ###########################################
-%>

<%- # vim: set filetype=verilog_template: -%>
