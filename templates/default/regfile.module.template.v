<%
    ##  icglue - template regfile

    proc clk                     {} { return "abp_clk_i"               }
    proc reset                   {} { return "abp_resetn_i"            }
    proc rf_addr                 {} { return "abp_addr_i"              }
    proc rf_sel                  {} { return "abp_sel_i"               }
    proc rf_enable               {} { return "abp_enable_i"            }
    proc rf_write                {} { return "abp_write_i"             }
    proc rf_w_data               {} { return "abp_wdata_i"             }
    proc rf_bytesel              {} { return "abp_strb_i"              }
    proc rf_prot                 {} { return "abp_prot_i"              }

    proc rf_base_addr            {} { return "RF_BASE_ADDR"            }
    proc rf_r_data               {} { return "abp_rdata_o"             }
    proc rf_ready                {} { return "abp_ready_o "            }
    proc rf_err                  {} { return "abp_slverr_o"            }

    proc rf_r_data_sig           {} { return "abp_rf_r_data"           }

    proc rf_w_sel                {} { return "rf_w_sel"                }
    proc rf_r_sel                {} { return "rf_r_sel"                }

    proc rf_ready_sig            {} { return "abp_ready"               }
    proc rf_err_sig              {} { return "abp_slverr"              }
    proc rf_write_permitted      {} { return "rf_write_permitted"      }
    proc rf_next_write_permitted {} { return "rf_next_write_permitted" }
    proc rf_read_permitted       {} { return "rf_read_permitted"       }
    proc rf_next_read_permitted  {} { return "rf_next_read_permitted"  }



    proc rf_comment_block {blockname {pre "    "}} {
        return [string cat \
                   "$pre/*************************************************************************/\n" \
                   [format "$pre/* %-69s */\n" $blockname]                                             \
                   "$pre/*************************************************************************/\n" \
            ]
    }
    proc param     {} {
        return [uplevel 1 {format "RA_%-${maxlen_name}s" [string toupper $entry(name)]}]
    }
    proc addr_vlog {} {
        return [uplevel 1 {format "32'h%08X" $entry(address)}]
    }

    proc reg_name {} {
        return [uplevel 1 {format "reg_%-${maxlen_signame}s" $reg(name)}]
    }
    proc reg_range {} {
        if {[uplevel 1 expr {$reg(width) == 1}]} {
            return [format "%7s"  {}]
        } else {
            return [uplevel 1 {format "\[%2d:%2d\]" [expr {$reg(width)-1}] 0 }]
        }
    }
    proc reg_entrybits {} {
        set bits [uplevel {split $reg(entrybits) ":"}]
        if {[llength $bits] == 2} {
            return [format "%2d:%2d" {*}$bits]
        } else {
            return [format "%5d" {*}$bits]
        }
    }
    proc reg_entrybits_in_bytesel {byte} {
        lassign [uplevel {split $reg(entrybits) ":"}] ubit lbit
        if {$lbit eq ""} {
            set lbit $ubit
        }
        if {$lbit >=8*($byte+1) || $ubit < 8*$byte} {
            return false
        } else {
            return true
        }
    }
    proc reg_entrybits_bytesel {byte} {
        lassign [uplevel {split $reg(entrybits) ":"}] ubit lbit
        if {$lbit eq ""} {
            set lbit $ubit
        }
        if {$ubit > 8*($byte+1)-1} {
            set ubit [expr {8*($byte+1)-1}]
        }
        if {$lbit < 8*$byte} {
            set lbit [expr {8*$byte}]
        }
        if {$lbit eq $ubit} {
            return [format "   %2d" $ubit]
        } else {
            return [format "%2d:%2d" $ubit $lbit]
        }
    }
    proc reg_range_bytesel {byte} {
        set reg_width [uplevel 1 expr {$reg(width)}]
        lassign [uplevel {split $reg(entrybits) ":"}] ubit lbit
        if {$lbit eq ""} {
            set lbit $ubit
        }
        set offset $lbit
        if {$ubit > 8*($byte+1)-1} {
            set ubit [expr {8*($byte+1)-1}]
        }
        if {$lbit < 8*$byte} {
            set lbit [expr {8*$byte}]
        }
        if {$lbit eq $ubit} {
            if {$reg_width eq 1} {
                return [format "%6s " {}]
            } else {
                return [format "\[   %2d\]" [expr {$ubit-$offset}]]
            }
        } else {
            return [format "\[%2d:%2d\]" [expr {$ubit-$offset}] [expr {$lbit-$offset}]]
        }

    }

    proc reg_val {} {
        return [uplevel 1 {format "val_%s" $entry(name)}]
    }
    proc signal_name {} {
        return [uplevel 1 {format "%-${maxlen_signalname}s" [adapt_signalname $reg(signal) $obj_id]}]
    }
    proc signal_entrybits {} {
        set bits [uplevel {split $reg(signalbits) ":"}]
        if {[llength $bits] == 2} {
            return [format "\[%2d:%2d\]" {*}$bits]
        } elseif {$bits eq "-"} {
            return [format "%7s" {}]
        } else {
            return [format "\[%5d\]" $bits]
        }
    }
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
                lappend sig_syncs "$reg(signal)" "$reg(name)" "[reg_range]" "[signal_entrybits]"
            }
        }
        foreach_array_with entry $entry_list {[info exists entry(handshake)]} {
            set handshake_sig_out [lindex $entry(handshake) 0]
            set handshake_sig_in  [lindex $entry(handshake) 1]
            if {[lsearch $handshake_list $handshake_sig_out] < 0} {
                lappend handshake_list $handshake_sig_out
                dict set handshake_sig_in_from_out $handshake_sig_out $handshake_sig_in
                # TODO: if {type == XXX} {...}
                lappend sig_syncs $handshake_sig_in $handshake_sig_in "       " {}
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
    %><[rf_comment_block "Regfile ADDRESS definition"]><% foreach_array entry $entry_list { -%>
    localparam <[param]> = <[rf_base_addr]> + <[addr_vlog]>;<%="\n"%><% } -%>
    <[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-addresses"]><%
    ## </localparams> ##
    ###########################################
%>

<%
    ###########################################
    ## <definition>
    %><%=[rf_comment_block "regfile signal definition"]-%>
    reg  [31: 0] <[rf_r_data_sig]>;
    reg          <[rf_ready_sig]>;
    reg          <[rf_err_sig]>;
    wire         <[rf_w_sel]>;
    wire         <[rf_r_sel]>;
    reg          <[rf_write_permitted]>;
    reg          <[rf_next_write_permitted]>;
    reg          <[rf_read_permitted]>;
    reg          <[rf_next_read_permitted]>;<%="\n"%><%
    foreach_preamble {s r w sb} $sig_syncs { %>
    // common sync signals<% } { %>
    wire <%=$w%> <%=$r%>_sync;<% } %><%="\n"%><%
    foreach_preamble handshake $handshake_list {%>
    // handshake register<%} { %>
    reg          reg_<%=$handshake%>;
    wire         rdy_<%=$handshake%>;<% } %><%="\n"%><%
    foreach_array_preamble entry $entry_list { %>
    // regfile registers / wires<% } { %>
    wire [31: 0] <[reg_val]>;<%
        foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} { %>
    reg  <[reg_range]> <[reg_name]>;<% } %><%="\n"%><% } %>
    <%=[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-declaration"] %><%
    ## </definition> ##
    ###########################################
%>

<%
    ###########################################
    ## <common-sync> 
    foreach_preamble {s r w sb} $sig_syncs {
    %><[rf_comment_block "common sync's"]><% } { -%>
    common_sync i_common_sync_<%=$s%><[string trim $w]> (
        .clk_i(<[clk]>),
        .reset_n_i(<[reset]>),
        .data_i(<[adapt_signalname $s $obj_id]><%=$sb%>),
        .data_o(<%=$r%>_sync)
    );<%="\n"%><% }  
    ## </common-sync>
    ###########################################
%>

<%
    ###########################################
    ## <handshake>
    if {$handshake_list ne ""} {
    %><%=[rf_comment_block "handshake"]-%>
    always @(posedge <[clk]> or negedge <[reset]>) begin
        if (<[reset]> == 1'b0) begin<% foreach handshake $handshake_list { %>
            reg_<%=$handshake%> <= 1'b1;<% } %>
        end else begin
            if (<[rf_r_sel]> && <[rf_enable]>) begin<% foreach handshake $handshake_list { %>
                if (<[join [dict get $handshake_cond_req $handshake] " || "]>) begin
                    reg_<%=$handshake%> <= 1'b1;
                end<% } %>
            end<% foreach handshake $handshake_list { %>
            if (rdy_<%=$handshake%> == 1'b1) begin
                if (<[dict get $handshake_sig_in_from_out $handshake]>_sync == 1'b1) begin
                    reg_<%=$handshake%> <= 1'b0;
                end
            end<% }  %>
        end
    end<% foreach handshake $handshake_list { %>
    assign rdy_<%=$handshake%> = ~reg_<%=$handshake%>;
    assign <[adapt_signalname $handshake $obj_id]> = reg_<%=$handshake%>;<%="\n"%><% }
    } %><%="\n\n"%><%
    ## </handshake> 
    ###########################################
-%>
<%
    ###########################################
    ## <register-write>
    %><[rf_comment_block "Regfile - registers (write-logic & read value assignmment)"]>
    assign <[rf_r_sel]> = ~<[rf_write]> && <[rf_sel]>;
    assign <[rf_w_sel]> =  <[rf_write]> && <[rf_sel]>;
    always @(posedge <[clk]> or negedge <[reset]>) begin
        if (<[reset]> == 1'b0) begin
            <[rf_write_permitted]> <= 1'b0;
            <[rf_read_permitted]>  <= 1'b0;
        end else begin
            if (<[rf_w_sel]> == 1'b1) begin
                <[rf_write_permitted]> <= <[rf_next_write_permitted]>;
                <[rf_read_permitted]>  <= <[rf_next_read_permitted]>;
            end
        end
    end<%="\n"%><%
    foreach_array entry $entry_list {
        set maxlen_signame [max_array_entry_len $entry(regs) name]
        set maxlen_signalname [expr [max_array_entry_len $entry(regs) signal] + 2]
    %>
    <[format "// %s @ %s" $entry(name)  $entry(address)]><% if {[info exists entry(handshake)]} { %><[format " (%s)" $entry(handshake)]><% }
    if {[foreach_array_contains reg $entry(regs) {$reg(type) eq "RW"}]} { %>
    always @(posedge <[clk]> or negedge <[reset]>) begin
        if (<[reset]> == 1'b0) begin<% foreach_array_with reg $entry(regs) {$reg(type) eq "RW"} { %>
            <[reg_name]> <= <%=$reg(reset)%>;<% } %>
        end else begin
            if (<[rf_w_sel]> == 1'b1 && <[rf_enable]> == 1'b1) begin
                if (<[rf_addr]> == <[string trim [param]]>) begin<%
                    for {set byte 0} {$byte < 4} {incr byte} { 
                        foreach_array_preamble_epilog_with reg $entry(regs) {$reg(type) eq "RW" && [reg_entrybits_in_bytesel $byte]} { %>
                    if (<[rf_bytesel]>[<%=$byte%>] == 1'b1) begin<% } { %>
                        <[reg_name]><[reg_range_bytesel $byte]> <= <[rf_w_data]>[<[reg_entrybits_bytesel $byte]>];<% } { %>
                    end<% } } %>
                end
            end
        end
    end<% foreach_array_with reg $entry(regs) {($reg(type) eq "RW") && ($reg(signal) ne "-")} { %>
    assign <[signal_name]><[signal_entrybits]> = <[string trim [reg_name]]>;<% } %><%="\n"%><%
    }
    foreach_array reg $entry(regs) {
        if {$reg(type) eq "RW"} { %>
    assign <[reg_val]>[<[reg_entrybits]>] = <[string trim [reg_name]]>;<% } elseif {$reg(type) eq "R"} { %>
    assign <[reg_val]>[<[reg_entrybits]>] = <[string trim [signal_name]]><[signal_entrybits]>;<% } elseif {$reg(type) eq "RS"} { %>
    assign <[reg_val]>[<[reg_entrybits]>] = <%=$reg(name)%>_sync;<% } elseif {$reg(type) eq "-"} { %>
    assign <[reg_val]>[<[reg_entrybits]>] = <%=$reg(width)%>'h0;<% } } %><%="\n"%><% } %><%="\n"
    %><[rf_comment_block "apb ready/error generate"]>
    always @(*) begin
        <[rf_ready_sig]> = 1'b0;
        if (<[rf_enable]> == 1'b1) begin
            <[rf_ready_sig]> = 1'b1;
        end<%
        foreach handshake $handshake_list { %>
        if (<[join [dict get $handshake_cond_req $handshake] " || "]>) begin
            <[rf_ready_sig]> = rdy_<%=$handshake%>;
        end<% } %>
        <[rf_err_sig]> = 1'b0;
        if (<[rf_w_sel]> && <[rf_enable]>) begin
            <[rf_err_sig]> = <[rf_write_permitted]>;
        end
        if (<[rf_w_sel]> && <[rf_enable]>) begin
            <[rf_err_sig]> = <[rf_read_permitted]>;
        end
        <[get_pragma_content $pragma_data "keep" "generate-apb-ready-error"]>
    end
    assign <[rf_ready]> = <[rf_ready_sig]>;
    assign <[rf_err]> = <[rf_err_sig]>;

    <[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-code"]><%
    ## <register-write>
    ###########################################
%>

<%
    ###########################################
    ## <output mux> ##
    %><%=[rf_comment_block "Regfile registers (read-logic)"] -%>
    always @(*) begin
        <[rf_next_write_permitted]> = 0;
        <[rf_next_read_permitted]> = 1;
        case (<[rf_addr]>)<% foreach_array entry $entry_list { %>
            <[string trim [param]]>: begin
                <[rf_r_data_sig]> = <[reg_val]>;<% if {[foreach_array_contains reg $entry(regs) {$reg(type) eq "RW"}]} { %>
                <[rf_next_write_permitted]> = 1;<% } %>
            end<% } %>
            <%=[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-outputmux"] %>
            default: begin
                <[rf_r_data_sig]> = 32'h0000_0000;
                <[rf_next_read_permitted]> = 0;
            end
        endcase
    end
    assign <[rf_r_data]> = <[rf_r_data_sig]>;
    <%=[get_pragma_content $pragma_data "keep" "regfile-${rf(name)}-outputcode"] %><%
    ## </output mux> ##
    ###########################################
%>
<%-
    }
    ## </regfiles> ##
    ###########################################
%>

<%- # vim: set filetype=verilog_template: -%>
