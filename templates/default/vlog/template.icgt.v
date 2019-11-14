<%
    ##  icglue - module template
    set cell_define [ig::db::get_attribute -object $obj_id -attribute "cell" -default "false"]
-%>
/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */
<%I vlog/include/header.icgt.vh -%>
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
<%= [expr {$cell_define ? "`endcelldefine\n" : "" }] -%>

<[pop_keep_block_content keep_block_data "keep" "foot" ".v" ""]>
