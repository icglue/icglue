<%
    ##  icglue - SystemVerilog module template
-%>
/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */
<%I svlog/include/header.icgt.svh -%>
<%-
    ###########################################
    ## <icglue-inst/code>
    if {[llength $mod_data(regfiles)] == 0} {
    -%><%I vlog/include/inst.icgt.vh %><%-
    ## </icglue-inst/code> ##
    ###########################################
    } else {
    ###########################################
    ## <regfile>
    -%><%I vlog/include/regfile.icgt.vh %><%-
    ## </regfile>
    ###########################################
    }
%>
<%I vlog/include/orphaned-keep-blocks.icgt.vh -%>

endmodule
