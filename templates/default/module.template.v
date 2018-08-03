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

endmodule
<%- # vim: set filetype=verilog_template: -%>
