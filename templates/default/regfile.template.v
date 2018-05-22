<%
    ##  icglue - template regfile

    array set mod_data [module_to_arraylist $obj_id]
    set entry_list     [regfile_to_arraylist [lindex [ig::db::get_regfiles -of $obj_id] 0]]

    set port_data_maxlen_dir   [max_array_entry_len $mod_data(ports) vlog.direction]
    set port_data_maxlen_range [max_array_entry_len $mod_data(ports) vlog.bitrange]

    set decl_data_maxlen_type  [max_array_entry_len $mod_data(declarations) vlog.type]
    set decl_data_maxlen_range [max_array_entry_len $mod_data(declarations) vlog.bitrange]

    set param_data_maxlen_type [max_array_entry_len $mod_data(parameters) vlog.type]
    set param_data_maxlen_name [max_array_entry_len $mod_data(parameters) name]

    set maxlen_name            [max_array_entry_len $entry_list name]
    set maxlen_regname         0

    proc reset     {} { return "reset_n_ref_i" }
    proc clk       {} { return "clk_ref_i"     }
    proc rf_addr   {} { return "rf_addr_i";    }
    proc rf_w_data {} { return "rf_w_data_i"   }
    proc rf_r_data {} { return "rf_r_data_i"   }
    proc rf_w_en   {} { return "rf_en_i"       }
    proc r_data    {} { return "rf_r_data"     }

    proc param {} {
        return [uplevel 1 {format "RA_%-${maxlen_name}s" [string toupper $entry(name)]}]
    }
    proc addr_vlog {} {
        return [uplevel 1 {format "32'h%08X" $entry(address)}]
    }

    proc reg_name {} {
        return [uplevel 1 {format "reg_%-${maxlen_regname}s" $reg(name)}]
    }
    proc reg_range {} {
        return [uplevel 1 {format "%2d:%2d" [expr {$reg(width)-1}] 0 }]
    }
    proc reg_val {} {
        return [uplevel 1 {format "val_%s" $entry(name)}]
    }
    proc reg_entrybits {} {
        return [uplevel 1 {format "%2d:%2d" {*}[split $reg(entrybits) ":"]}]
    }

    proc signal_name {} {
        return [uplevel 1 {format "%-${maxlen_signalname}s" [adapt_signalname $reg(signal) $obj_id]}]
    }
    proc signal_entrybits {} {
        return [uplevel 1 {format "%2d:%2d" {*}[split $reg(signalbits) ":"]}]
    }
-%>

<%-= [get_pragma_content $pragma_data "keep" "head"] -%>

module <%=$mod_data(name)%> (
<%
    ###########################################
    ## <module port list>
    foreach_array_join port $mod_data(ports) { -%>
        <%=$port(name)%><% } { -%><%=",\n"%><% }
    ## </module port list>
    ###########################################
%>
    );

<%
    ###########################################
    ## <parameters>
    foreach_array param $mod_data(parameters) { -%>
    <%=[format "%-${param_data_maxlen_type}s %-${param_data_maxlen_name}s = %s;\n" $param(vlog.type) $param(name) $param(value)]%><% } -%>
    <%=[get_pragma_content $pragma_data "keep" "parameters"]%><%
    ## </parameters>
    ###########################################
%>

<%
    ###########################################
    ## <port declaration>
    foreach_array port $mod_data(ports) { -%>
    <%=[format "%-${port_data_maxlen_dir}s %${port_data_maxlen_range}s %s;\n" $port(vlog.direction) $port(vlog.bitrange) $port(name)]%><% }
    ## </port declaration>
    ###########################################
%>

<%
    ###########################################
    ## <signal declaration>
    foreach_array decl $mod_data(declarations) { -%>
    <%=[format "%-${decl_data_maxlen_type}s %${decl_data_maxlen_range}s %s;\n" $decl(vlog.type) $decl(vlog.bitrange)  $decl(name)]%><% } -%>
    <%=[get_pragma_content $pragma_data "keep" "declarations"]%><%
    ## </signal declaration>
    ###########################################
%>

<%
    ###########################################
    ## <submodule instanciations>
    foreach_array inst $mod_data(instances) {
        set i_params_maxlen_name [max_array_entry_len $inst(parameters) name]
        set i_pins_maxlen_name   [max_array_entry_len $inst(pins) name]  %>
    <%=$inst(module.name)%><% if {$inst(hasparams)} { %><%=" #(\n"%><% foreach_array_join param $inst(parameters) { -%>
        .<%=[format "%-${i_params_maxlen_name}s (%s)" $param(name) $param(value)]%><% } { %><%=",\n"%><% } %>
    )<% } %><%=" $inst(name) (\n"%><% foreach_array_join pin $inst(pins) { -%>
        .<%=[format "%-${i_pins_maxlen_name}s (%s)" $pin(name) $pin(connection)]%><% } { %><%=",\n"%><% } %>
    );<% } %>

    <%=[get_pragma_content $pragma_data "keep" "instances"]%><%
    ## </submodule instanciations>
    ###########################################
%>

<%
    ###########################################
    ## <code>
    foreach_array cs $mod_data(code) { -%>
    <%= [string trim $cs(code)]%><% } %>
    <%=[get_pragma_content $pragma_data "keep" "code"]%><%
    ## </code>
    ###########################################
-%>

<%
    ###########################################
    ## <localparams> -%>
    <%="// Regfile ADDRESS definition:\n"%><% foreach_array entry $entry_list { -%>
    localparam <%=[param]%> = <%=[addr_vlog]%><%=";\n"%><% } -%>
    <%=[get_pragma_content $pragma_data "keep" "regfile-addresses"]%><%
    ## </localparams> ##
    ###########################################
%>

<%
    ###########################################
    ## <definition> -%>
    <%="// regfile signal definition:"%>
    reg  [31: 0] <%=[r_data]%>;<% foreach_array entry $entry_list { %>
    wire [31: 0] <%=[reg_val]%>;<% foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} { %>
    reg  [<%=[reg_range]%>] <%=[reg_name]%>;<% } %><%="\n"%><% } %>
    <%=[get_pragma_content $pragma_data "keep" "regfile-declaration"] %><%
    ## </definition> ##
    ###########################################
-%>

<%
    ###########################################
    ## <register-write>
    foreach_array entry $entry_list {
        set maxlen_regname [max_array_entry_len $entry(regs) name]
        set maxlen_signalname [expr [max_array_entry_len $entry(regs) signal] + 2]
    %>
    //////////////////////////////////////////////////////////////////////////////
    <%=[format "// %s @ %s" $entry(name)  $entry(address)]%>
    always @(posedge <%=[clk]%> or negedge <%=[reset]%>) begin
        if (<%=[reset]%> == 1'b0) begin<% foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} { %>
            <%=[reg_name]%> <= <%=$reg(reset)%>;<% } %>
        end else begin
            if (<%=[rf_w_en]%> == 1'b1) begin
                if (<%=[rf_addr]%> == <%=[string trim [param]]%>) begin<% foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} { %>
                    <%=[reg_name]%> <= <%=[rf_w_data]%>[<%=[reg_entrybits]%>];<% } %>
                end
            end
        end
    end<% foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} { %>
    assign <%=[signal_name]%>[<%=[signal_entrybits]%>] = <%=[string trim [reg_name]]%>;<% } %><%="\n"%><%
    foreach_array reg $entry(regs) {
        if {$reg(type) eq "RW"} { %>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=[string trim [reg_name]]%>;<% } elseif {$reg(type) eq "R"} { %>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=[string trim [signal_name]]%>[<%=[signal_entrybits]%>];<% } elseif {$reg(type) eq "-"} { %>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=$reg(width)%>'h0;<% } } %><%="\n"%><% } %>
    <%=[get_pragma_content $pragma_data "keep" "regfile-code"] %><%
    ## <register-write>
    ###########################################
-%>

<%
    ###########################################
    ## <output mux>
    %>
    always @(*) begin
        case (<%=[rf_addr]%>)<% foreach_array entry $entry_list { %>
            <%=[param]%>: <%=[r_data]%> = <%=[reg_val]%>;<% } %>
            <%=[get_pragma_content $pragma_data "keep" "regfile-outputmux"] %>
            <%=[format "%-${maxlen_name}s   " {default}]%>: <%=[r_data]%> = 32'h0000_0000;
        endcase
    end
    assign <%=[rf_r_data]%> = <%=[r_data]%>;
    <%=[get_pragma_content $pragma_data "keep" "regfile-outputcode"] %><%
    ## </output mux> ##
    ###########################################
%>

endmodule

<%- # vim: set filetype=verilog_template: -%>
