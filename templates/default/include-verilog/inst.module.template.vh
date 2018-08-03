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
