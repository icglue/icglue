<%
    ##  icglue - SystemVerilog module template
-%>
<%I include-systemverilog/header.module.template.svh -%>
<%-
    ###########################################
    ## <icglue-inst/code>
    if {[llength $mod_data(regfiles)] == 0} {
    -%><%I include-systemverilog/inst.module.template.svh %><%-
    ## </icglue-inst/code> ##
    ###########################################
    } else {
    ###########################################
    ## <regfile>
    -%><%I include-systemverilog/regfile.module.template.svh %><%-
    ## </regfile>
    ###########################################
    }
%>
<%-
    ###########################################
    ## orphaned keep-blocks
    set rem_keeps [remaining_keep_block_contents $keep_block_data]
    if {[llength $rem_keeps] > 0} {
        log -warn "There are orphaned keep blocks in the systemverilog source - they will be appended to the code." %>

    `ifdef 0
        /* orphaned icglue keep blocks ...
         * TODO: remove if unnecessary or reintegrate
         */<%="\n\n"%><%-
        foreach b $rem_keeps { %>
    <%= "$b\n"%><% } %>
    `endif <%="\n\n"%><%- }
    ###########################################
%>

endmodule
<%+ # vim: set filetype=verilog_template: -%>
