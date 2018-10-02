<%
    ##  icglue - module template
-%>
<%I include-verilog/header.module.template.vh -%>
<%-
    ###########################################
    ## <icglue-inst/code>
    if {[llength $mod_data(regfiles)] == 0} { -%>
<%I include-verilog/inst.module.template.vh %><%-
    ## </icglue-inst/code> ##
    ###########################################
    } else {
    ###########################################
    ## <regfile> -%>
<%I include-verilog/regfile.module.template.vh %><%-
    ## </regfile>
    ###########################################
    }
%>
<%-
    ###########################################
    ## orphaned keep-blocks
    set rem_keeps [remaining_keep_block_contents $keep_block_data]
    if {[llength $rem_keeps] > 0} {
        log -warn "There are orphaned keep blocks in the verilog source - they will be appended to the code."
%>

    `ifdef 0
        /* orphaned icglue keep blocks ...
         * TODO: remove if unnecessary or reintegrate
         */

<%-
        foreach b $rem_keeps { %>
    <%= $b %>
<%      } %>
    `endif
<%-
    }
    ###########################################
%>

endmodule
<%+ # vim: set filetype=verilog_template: -%>
