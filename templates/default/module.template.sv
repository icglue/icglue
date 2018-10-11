<%
    ##  icglue - SystemVerilog module template
-%>
<%I include-systemverilog/header.module.template.svh -%>
<%-
    ###########################################
    ## <icglue-inst/code>
    if {[llength $mod_data(regfiles)] == 0} {
    -%><%I include-verilog/inst.module.template.vh %><%-
    ## </icglue-inst/code> ##
    ###########################################
    } else {
    ###########################################
    ## <regfile>
    -%><%I include-verilog/regfile.module.template.vh %><%-
    ## </regfile>
    ###########################################
    }
%>
<%I include-verilog/orphaned-keep-blocks.vh -%>

endmodule
<%- # vim: set filetype=verilog_template: %>
