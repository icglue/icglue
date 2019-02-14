<%-
    ###########################################
    ## orphaned keep-blocks
    set rem_keeps [remaining_keep_block_contents $keep_block_data]
    if {[llength $rem_keeps] > 0} {
        log -warn "There are orphaned keep blocks in the verilog source - they will be appended to the code." %>

    `ifdef 0
        /* orphaned icglue keep blocks ...
         * TODO: remove if unnecessary or reintegrate
         */<%="\n\n"%><%-
        foreach b $rem_keeps { %>
    <%= "$b\n"%><% } %>
    `endif<%="\n\n"%><%- }
    ###########################################
-%>
