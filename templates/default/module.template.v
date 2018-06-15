<%
    ##  icglue - template regfile

    array set mod_data [module_to_arraylist $obj_id]

    set port_data_maxlen_dir   [max_array_entry_len $mod_data(ports) vlog.direction]
    set port_data_maxlen_range [max_array_entry_len $mod_data(ports) vlog.bitrange]

    set decl_data_maxlen_type  [max_array_entry_len $mod_data(declarations) vlog.type]
    set decl_data_maxlen_range [max_array_entry_len $mod_data(declarations) vlog.bitrange]

    set param_data_maxlen_type [max_array_entry_len $mod_data(parameters) vlog.type]
    set param_data_maxlen_name [max_array_entry_len $mod_data(parameters) name]

    proc reset               {} { return "abp_resetn_i"        }
    proc clk                 {} { return "abp_clk_i"           }
    proc rf_addr             {} { return "abp_addr_i"          }
    proc rf_prot             {} { return "abp_prot_i"          }
    proc rf_sel              {} { return "abp_sel_i"           }
    proc rf_enable           {} { return "abp_enable_i"        }
    proc rf_write            {} { return "abp_write_i"         }

    proc rf_w_data           {} { return "abp_wdata_i"         }
    proc rf_bytesel          {} { return "abp_strb_i"          }

    proc rf_ready            {} { return "abp_ready_o"         }
    proc rf_r_data           {} { return "abp_rdata_o"         }
    proc rf_r_data_sig       {} { return "abp_rf_r_data"       }
    proc rf_pslverr          {} { return "abp_slverr"          }

    proc rf_r_valid_sig      {} { return "rf_r_valid"          }
    proc rf_r_valid          {} { return "rf_r_valid_o"        }

    proc rf_w_sel            {} { return "rf_w_sel"            }
    proc rf_r_sel            {} { return "rf_r_sel"            }
    # TODO: change name -> write allowed
    proc rf_ready2write      {} { return "rf_ready2write"      }
    proc rf_next_ready2write {} { return "rf_next_ready2write" }

    proc rf_comment_block {blockname {pre "    "}} {
        return [string cat \
                "$pre/*************************************************************************/\n" \
                [format "$pre/* %-69s */\n" $blockname]                                             \
                "$pre/*************************************************************************/\n" \
            ]
    }
    proc param {} {
        return [uplevel 1 {format "RA_%-${maxlen_name}s" [string toupper $entry(name)]}]
    }
    proc addr_vlog {} {
        return [uplevel 1 {format "32'h%08X" $entry(address)}]
    }

    proc reg_name {} {
        return [uplevel 1 {format "reg_%-${maxlen_signame}s" $reg(name)}]
    }
    proc reg_range {} {
        return [uplevel 1 {format "%2d:%2d" [expr {$reg(width)-1}] 0 }]
    }
    proc reg_val {} {
        return [uplevel 1 {format "val_%s" $entry(name)}]
    }
    proc reg_entrybits {} {
        set bits [uplevel {split $reg(entrybits) ":"}]
        if {[llength $bits] == 2} {
            return [format "%2d:%2d" {*}$bits]
        } else {
            return [format "%5d" {*}$bits]
        }
    }
    proc signal_name {} {
        return [uplevel 1 {format "%-${maxlen_signalname}s" [adapt_signalname $reg(signal) $obj_id]}]
    }
    proc signal_entrybits {} {
        set bits [uplevel {split $reg(signalbits) ":"}]
        if {[llength $bits] == 2} {
            return [format "%2d:%2d" {*}$bits]
        } else {
            return [format "%5d" $bits]
        }
    }

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
    <%=[format "%-${param_data_maxlen_type}s %-${param_data_maxlen_name}s = %s;\n" $param(vlog.type) $param(name) $param(value)]%><% } -%>
    <%=[get_pragma_content $pragma_data "keep" "parameters"]%><%
    ## </parameters>
    ###########################################
%>
<%
    ###########################################
    ## <port declaration>
    foreach_array_preamble port $mod_data(ports) { -%><%="\n"%><% } { -%>
    <%=[format "%-${port_data_maxlen_dir}s %${port_data_maxlen_range}s %s;\n" $port(vlog.direction) $port(vlog.bitrange) $port(name)]%><% }
    ## </port declaration>
    ###########################################
%>
<%-
    ###########################################
    ## <signal declaration>
    foreach_array_preamble decl $mod_data(declarations) { %><%="\n\n"%><% } { -%>
    <%=[format "%-${decl_data_maxlen_type}s %${decl_data_maxlen_range}s %s;\n" $decl(vlog.type) $decl(vlog.bitrange)  $decl(name)]%><% } -%>
    <%=[get_pragma_content $pragma_data "keep" "declarations"]%><%
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
        .<%=[format "%-${i_params_maxlen_name}s (%s)" $param(name) $param(value)]%><% } { %>,<%="\n"%><% } %>
    )<% } %> i_<%=$inst(name)%> (<%="\n"%><% foreach_array_join pin $inst(pins) { -%>
        .<%=[format "%-${i_pins_maxlen_name}s (%s%s)" $pin(name) [expr {$pin(invert) ? "~" : ""}] $pin(connection)]%><% } { %>,<%="\n"%><% } %>
    );<% } %>

    <%=[get_pragma_content $pragma_data "keep" "instances"]%><%
    ## </submodule instanciations>
    ###########################################
%>
<%-
    ###########################################
    ## <code>
    foreach_array_preamble cs $mod_data(code) { %><%="\n\n"%><% } {
    %><%="$cs(code)"%><% } %>
    <%=[get_pragma_content $pragma_data "keep" "code"]%><%
    ## </code>
    ###########################################
-%>

<%
    ###########################################
    ## <regfiles> ##
    foreach_array rf $mod_data(regfiles) {
        set entry_list $rf(entries)

        set maxlen_name            [max_array_entry_len $entry_list name]
        set maxlen_signame         0

        set sig_syncs {}
        set handshake_list {}
        set handshake_cond_req {}
        set handshake_sig_in_from_out {}

        foreach_array entry $entry_list {
            foreach_array_with reg $entry(regs) {$reg(type) eq "RS"} {
                lappend sig_syncs $reg(name);
            }
        }
        foreach_array_with entry $entry_list {[info exists entry(handshake)]} {
            set handshake_sig_out [lindex $entry(handshake) 0]
            set handshake_sig_in  [lindex $entry(handshake) 1]
            if {[lsearch $handshake_list $handshake_sig_out] < 0} {
                lappend handshake_list $handshake_sig_out
                dict set handshake_sig_in_from_out $handshake_sig_out $handshake_sig_in
                # TODO: if {type == XXX} {...}
                lappend sig_syncs $handshake_sig_in
            } else {
                if {[dict get $handshake_sig_in_from_out $handshake_sig_out] ne $handshake_sig_in} {
                    log -warn -id RFTP "Handshake signal $handshake_sig_out is used with different feedback signals -- " \
                        "first occurence: [dict get $handshake_sig_in_from_out $handshake_sig_out] / redeclared $handshake_sig_in (ignored)"
                }
            }
            dict lappend handshake_cond_req $handshake_sig_out "([rf_addr] == [string trim [param]])"
        }

%>
<%
    ###########################################
    ## <localparams>
    %><%=[rf_comment_block "Regfile ADDRESS definition"]%><% foreach_array entry $entry_list { -%>
    localparam <%=[param]%> = <%=[addr_vlog]%>;<%="\n"%><% } -%>
    <%=[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-addresses"]%><%
    ## </localparams> ##
    ###########################################
%>

<%
    ###########################################
    ## <definition>
    %><%=[rf_comment_block "regfile signal definition"]-%>
    reg  [31: 0] <%=[rf_r_data_sig]%>;
    wire         <%=[rf_w_sel]%>;
    reg          <%=[rf_ready2write]%>;
    reg          <%=[rf_next_ready2write]%>;<%="\n"%><%
    foreach_preamble s $sig_syncs { %>
    // common sync signals<% } { %>
    wire         <%=$s%>_sync;<% } %><%="\n"%><%
    foreach_preamble handshake $handshake_list {%>
    // handshake register<%} { %>
    reg          reg_<%=$handshake%>;
    reg          rdy_<%=$handshake%>;<% } %><%="\n"%><%
    foreach_array_preamble entry $entry_list { %>
    // regfile registers / wires<% } { %>
    wire [31: 0] <%=[reg_val]%>;<%
        foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} { %>
    reg  [<%=[reg_range]%>] <%=[reg_name]%>;<% } %><%="\n"%><% } %>
    <%=[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-declaration"] %><%
    ## </definition> ##
    ###########################################
%>

<%
    ###########################################
    ## <common-sync> 
    foreach_preamble s $sig_syncs { #TODO: BUS INSTANCE + RS assign  reverse sort registers
    %><%=[rf_comment_block "common sync's"]%><% } { -%>
    common_sync i_common_sync_<%=$s%> (
        .clk_i(<%=[clk]%>),
        .reset_n_i(<%=[reset]%>),
        .data_i(<%=[adapt_signalname $s $obj_id]%>),
        .data_o(<%=$s%>_sync)
    );<%="\n"%><% }  
    ## </common-sync>
    ###########################################
%>
<%
    ###########################################
    ## <handshake>
    if {$handshake_list ne ""} {
    %><%=[rf_comment_block "handshake"]-%>
    always @(posedge <%=[clk]%> or negedge <%=[reset]%>) begin
        if (<%=[reset]%> == 1'b0) begin<% foreach handshake $handshake_list { %>
            reg_<%=$handshake%> <= 1'b0;
            rdy_<%=$handshake%> <= 1'b1;<% } %>
        end else begin
            if (<%=[rf_r_sel]%> &&) begin<% foreach handshake $handshake_list { %>
                if (<%=[join [dict get $handshake_cond_req $handshake] " || "]%>) begin
                    reg_<%=$handshake%> <= 1'b1;
                    rdy_<%=$handshake%> <= 1'b0;
                end<% } %>
            end<% foreach handshake $handshake_list { %>
            if (rdy_<%=$handshake%> == 1'b1) begin
                if (<%=[dict get $handshake_sig_in_from_out $handshake]%>_sync == 1'b1) begin
                    reg_<%=$handshake%> <= 1'b0;
                    rdy_<%=$handshake%> <= 1'b1;
                end
            end<% }  %>
        end
    end<% foreach handshake $handshake_list { %>
    assign <%=[adapt_signalname $handshake $obj_id]%> = reg_<%=$handshake%>;<%="\n"%><% }
    } %>
    always @(*) begin
        <%=[rf_r_valid_sig]%> = 1'b1;<% foreach handshake $handshake_list { %>
        if (<%=[join [dict get $handshake_cond_req $handshake] " || "]%>) begin
            <%=[rf_r_valid_sig]%> = rdy_<%=$handshake%>;
        end<% } %>
        <%=[get_pragma_content $pragma_data "keep" "regfile-read_valid"] %>
    end
    assign <%=[rf_r_valid]%> = <%=[rf_r_valid_sig]%>;<%="\n\n"%><%
    ## </handshake> 
    ###########################################
-%>
<%
    ###########################################
    ## <register-write>
    %><%=[rf_comment_block "Regfile - registers (write-logic & read value assignmment)"]%>
    assign <%=[rf_r_sel]%> = ~<%=[rf_write]%> && <%=[rf_sel]%>;
    assign <%=[rf_w_sel]%> =  <%=[rf_write]%> && <%=[rf_sel]%>;
    always @(posedge <%=[clk]%> or negedge <%=[reset]%>) begin
        if (<%=[reset]%> == 1'b0) begin
            <%=[rf_ready2write]%> <= 1'b0;
        end else begin
            if ((<%=[rf_w_sel]%> == 1'b1) begin
                <%=[rf_ready2write]%> <= <%=[rf_next_ready2write]%>;
            end
        end
    end<%="\n"%><%
    foreach_array entry $entry_list {
        set maxlen_signame [max_array_entry_len $entry(regs) name]
        set maxlen_signalname [expr [max_array_entry_len $entry(regs) signal] + 2]
    %>
    <%=[format "// %s @ %s" $entry(name)  $entry(address)]%><% if {[info exists entry(handshake)]} { %><%=[format " (%s)" $entry(handshake)]%><% }
    if {[foreach_array_contains reg $entry(regs) {$reg(type) eq "RW"}]} { %>
    always @(posedge <%=[clk]%> or negedge <%=[reset]%>) begin
        if (<%=[reset]%> == 1'b0) begin<% foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} { %>
            <%=[reg_name]%> <= <%=$reg(reset)%>;<% } %>
        end else begin
            if ((<%=[rf_w_sel]%> == 1'b1 && <%=[rf_enable]%> == 1'b1) begin
                if (<%=[rf_addr]%> == <%=[string trim [param]]%>) begin<% foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} { %>
                    <%=[reg_name]%> <= <%=[rf_w_data]%>[<%=[reg_entrybits]%>];<% } %>
                end
            end
        end
    end<% foreach_array_with reg $entry(regs) {($reg(type) eq "RW") && ($reg(signal) ne "-")} { %>
    assign <%=[signal_name]%>[<%=[signal_entrybits]%>] = <%=[string trim [reg_name]]%>;<% } %><%="\n"%><%
    }
    foreach_array reg $entry(regs) {
        if {$reg(type) eq "RW"} { %>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=[string trim [reg_name]]%>;<% } elseif {$reg(type) eq "R"} { %>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=[string trim [signal_name]]%>[<%=[signal_entrybits]%>];<% } elseif {$reg(type) eq "RS"} { %>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=$reg(signal)_sync%>[<%=[signal_entrybits]%>];<% } elseif {$reg(type) eq "-"} { %>
    assign <%=[reg_val]%>[<%=[reg_entrybits]%>] = <%=$reg(width)%>'h0;<% } } %><%="\n"%><% } %>
    <%=[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-code"] %><%
    ## <register-write>
    ###########################################
%>

<%
    ###########################################
    ## <output mux> ##
    %><%=[rf_comment_block "Regfile registers (read-logic)"] -%>
    always @(*) begin
        <%=[rf_next_ready2write]%> = 0;
        case (<%=[rf_addr]%>)<% foreach_array entry $entry_list { %>
            <%=[string trim [param]]%>: begin
                <%=[rf_r_data_sig]%> = <%=[reg_val]%>;<% if {[foreach_array_contains reg $entry(regs) {$reg(type) eq "RW"}]} { %>
                <%=[rf_next_ready2write]%> = 1;<% } %>
            end<% } %>
            <%=[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-outputmux"] %>
            <%=[format "%-${maxlen_name}s   " {default}]%>: begin
                <%=[rf_r_data_sig]%> = 32'h0000_0000;
        endcase
    end
    assign <%=[rf_r_data]%> = <%=[rf_r_data_sig]%>;
    <%=[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-outputcode"] %><%
    ## </output mux> ##
    ###########################################
%>
<%-
    }
    ## </regfiles> ##
    ###########################################
%>

endmodule

<%- # vim: set filetype=verilog_template: -%>
