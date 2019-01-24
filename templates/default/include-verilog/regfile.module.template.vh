<%
    ##  icglue - template regfile

    proc warn_rftp {msg} {
        upvar mod_data(name) rfname
        log -warn -id RFTP "$rfname: $msg"
    }
    proc clk                     {} { return {apb_clk_i}               }
    proc reset                   {} { return {apb_resetn_i}            }
    proc rf_addr                 {} { return {apb_addr_i}              }
    proc rf_sel                  {} { return {apb_sel_i}               }
    proc rf_enable               {} { return {apb_enable_i}            }
    proc rf_write                {} { return {apb_write_i}             }
    proc rf_w_data               {} { return {apb_wdata_i}             }
    proc rf_bytesel              {} { return {apb_strb_i}              }
    proc rf_prot                 {} { return {apb_prot_i[1]}           }
    proc rf_prot_enable          {} { return {apb_prot_en_i}           }

    proc rf_r_data               {} { return {apb_rdata_o}             }
    proc rf_ready                {} { return {apb_ready_o}             }
    proc rf_err                  {} { return {apb_slverr_o}            }

    # check if template ports existing in the current module
    set template_ports {
        clk reset
        rf_addr rf_sel rf_enable rf_write rf_w_data rf_bytesel
        rf_prot rf_prot_enable
        rf_r_data rf_ready rf_err
    }

    set tp_names {}
    foreach p $template_ports {
        set port_name [$p]
        set port_name [regsub {\[\d+\]} $port_name {}]
        lappend tp_names $port_name
    }

    foreach_array port $mod_data(ports) {
        set idx [lsearch $tp_names "$port(name)"]
        if {$idx >= 0} {
            set tp_names [lreplace $tp_names $idx $idx]
        }
    }
    foreach mis $tp_names {
        warn_rftp "Missing port $mis"
    }

    proc rf_r_data_sig           {} { return {apb_rf_r_data}           }

    proc rf_w_sel                {} { return {rf_w_sel}                }
    proc rf_r_sel                {} { return {rf_r_sel}                }

    proc rf_ready_sig            {} { return {apb_ready}               }
    proc rf_err_sig              {} { return {apb_slverr}              }
    proc rf_write_permitted      {} { return {rf_write_permitted}      }
    proc rf_next_write_permitted {} { return {rf_next_write_permitted} }
    proc rf_read_permitted       {} { return {rf_read_permitted}       }
    proc rf_next_read_permitted  {} { return {rf_next_read_permitted}  }

    proc rf_prot_ok              {} { return {rf_apb_prot_ok}          }

    set fpga_impl [ig::db::get_attribute -object $obj_id -attribute "fpga" -default "false"]

    proc rf_comment_block {blockname {pre "    "}} {
        return [string cat \
                   "$pre/*************************************************************************/\n" \
                   [format "$pre/* %-69s */\n" $blockname]                                             \
                   "$pre/*************************************************************************/\n" \
            ]
    }
    proc param     {} {
        upvar entry(name) name maxlen_name maxlen_name
        return [format "RA_%-${maxlen_name}s" [string toupper $name]]
    }
    proc addr_vlog {} {
        upvar entry(address) address
        return [format "32'h%08X" $address]
    }

    proc reg_name {} {
        upvar entry(name) name maxlen_signame maxlen_signame reg(name) regname
        set maxlen_reg_name [expr {[string length $name] + 1 + $maxlen_signame}]
        return [format "reg_%-${maxlen_reg_name}s" "${name}_${regname}"]
    }
    proc reg_range {} {
        upvar reg(width) width
        if {$width == 1} {
            return [format "%7s"  {}]
        } else {
            return [format "\[%2d: 0\]" [expr {${width}-1}]]
        }
    }
    proc reg_entrybits {} {
        upvar reg(bit_high) ubit reg(bit_low) lbit
        if {$ubit != $lbit} {
            return [format "%2d:%2d" $ubit $lbit]
        } else {
            return [format "%5d" $ubit]
        }
    }
    proc reg_entrybits_in_bytesel {byte} {
        upvar reg(bit_high) ubit reg(bit_low) lbit
        if {$lbit >=8*($byte+1) || $ubit < 8*$byte} {
            return false
        } else {
            return true
        }
    }
    proc reg_entrybits_bytesel {byte} {
        upvar reg(bit_high) ubit reg(bit_low) lbit
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
        upvar reg(bit_high) ubit reg(bit_low) lbit reg(width) reg_width
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
        upvar entry(name) name
        return [format "val_%s" $name]
    }
    proc signal_name {} {
        upvar reg(signal) signal maxlen_signalname maxlen_signalname obj_id id
        return [format "%-${maxlen_signalname}s" [adapt_signalname $signal $id]]
    }
    proc signal_entrybits {} {
        upvar reg(signalbits) signalbits reg(signal) signal obj_id id
        set bits [split $signalbits ":"]
        if {[llength $bits] == 2} {
            return [format "\[%2d:%2d\]" {*}$bits]
        } elseif {$bits eq "-"} {
            return [format "%7s" {}]
        } else {
            if {$bits == 0} {
                set sigid [get_signal_id_by_name $signal $id]
                if {[ig::db::get_attribute -object $sigid -attribute size] == 1} {
                    return [format "%7s" {}]
                }
            }
            return [format "\[%5d\]" $bits]
        }
    }
    proc custom_reg {} {
        upvar reg(type) type
        return [regexp -nocase {C} $type]
    }
    proc fullcustom_reg {} {
        upvar reg(type) type
        return [regexp -nocase {FC} $type]
    }
    proc sctrigger_reg {} {
        upvar reg(type) type
        return [regexp -nocase {T} $type]
    }
    proc read_reg_sync {} {
        upvar reg(type) type
        return [regexp -nocase {RS} $type]
    }
    proc read_reg {} {
        upvar reg(type) type
        return [regexp -nocase {^[^-W]*$} $type]
    }
    proc write_reg {} {
        upvar reg(type) type
        return [regexp -nocase {W} $type]
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
        set handshake_sig_in_from_out_sync {}

        foreach_array entry $entry_list {
            foreach_array_with reg $entry(regs) {[read_reg_sync]} {
                lappend sig_syncs "$reg(signal)" "_${entry(name)}_${reg(name)}" "[reg_range]" "[signal_entrybits]"
            }
        }
        foreach_array_with entry $entry_list {[info exists entry(handshake)]} {
            lassign $entry(handshake) handshake_sig_out handshake_sig_in handshake_type
            foreach {handshake_sig_varname handshake_sig} [list handshake_sig_in $handshake_sig_in handshake_sig_out $handshake_sig_out] {
                if {[string first ":" $handshake_sig] > -1} {
                    set $handshake_sig_varname [lindex [split $handshake_sig ":"] 1]
                }
            }
            if {[lsearch $handshake_list $handshake_sig_out] < 0} {
                lappend handshake_list $handshake_sig_out
                dict set handshake_sig_in_from_out $handshake_sig_out $handshake_sig_in
                if {$handshake_type eq "S"} {
                    lappend sig_syncs $handshake_sig_in $handshake_sig_in "       " {}
                    dict set handshake_sig_in_from_out_sync $handshake_sig_out ${handshake_sig_in}_sync
                } else {
                    dict set handshake_sig_in_from_out_sync $handshake_sig_out ${handshake_sig_in}
                }
            } else {
                if {[dict get $handshake_sig_in_from_out $handshake_sig_out] ne $handshake_sig_in} {
                    warn_rftp "Handshake signal $handshake_sig_out is used with different feedback signals -- " \
                        "first occurence: [dict get $handshake_sig_in_from_out $handshake_sig_out] / redeclared $handshake_sig_in (ignored)"
                }
            }
            if {$entry(protected)} {
                dict lappend handshake_cond_req $handshake_sig_out "(([rf_addr] == [string trim [param]]) && [rf_prot_ok])"
            } else {
                dict lappend handshake_cond_req $handshake_sig_out "([rf_addr] == [string trim [param]])"
            }
        }

%>
<%
    ###########################################
    ## <localparams>
    %><[rf_comment_block "Regfile ADDRESS definition"]><% foreach_array entry $entry_list { -%>
    localparam <[param]> = <[addr_vlog]>;<%="\n"%><% } -%>
    <[pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-addresses"]><%
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
    wire         <[rf_prot_ok]>;
    reg          <[rf_write_permitted]>;
    reg          <[rf_next_write_permitted]>;
    reg          <[rf_read_permitted]>;
    reg          <[rf_next_read_permitted]>;

    assign <[rf_prot_ok]> = <[rf_prot]> | ~<[rf_prot_enable]>;<%="\n"%><%
    foreach_preamble {s r w sb} $sig_syncs { %>
    // common sync signals<% } { %>
    wire <%=$w%> <%=$r%>_sync;<% } %><%="\n"%><%
    foreach_preamble handshake $handshake_list {%>
    // handshake register<%} { %>
    reg          reg_<%=$handshake%>;<% } %><%="\n"%><%
    foreach_array_preamble entry $entry_list { %>
    // regfile registers / wires<% } { %>
    wire [31: 0] <[reg_val]>;<%
        foreach_array_with reg $entry(regs) {[write_reg] && ![fullcustom_reg]} { %>
    reg  <[reg_range]> <[string trim [reg_name]]>;<% } %><%="\n"%><% } %>
    <%=[pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-declaration"] %><%
    ## </definition> ##
    ###########################################
%>
<%
    ###########################################
    ## <icglue-inst/code> -%>
<%I include-verilog/inst.module.template.vh %><%-
    ## </icglue-inst/code> ##
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
        .data_i(<[adapt_signalname $s $obj_id]><[string trim $sb]>),
        .data_o(<%=$r%>_sync)
    );<%="\n"%><% }
    ## </common-sync>
    ###########################################
%>

<%
    ###########################################
    ## <handshake>
    if {$handshake_list ne ""} {
    %><%=[rf_comment_block "handshake"]%><%="\n"%><%-
    if {$fpga_impl} {-%>
    initial begin
        <% foreach handshake $handshake_list { -%>
            reg_<%=$handshake%> = 1'b0;<% } %>
    end<%="\n"%><% } -%>
    always @(posedge <[clk]><% if {!$fpga_impl} { %> or negedge <[reset]><% } %>) begin
        if (<[reset]> == 1'b0) begin<% foreach handshake $handshake_list { %>
            reg_<%=$handshake%> <= 1'b0;<% } %>
        end else begin
            if (<[rf_sel]> && <[rf_enable]>) begin<% foreach handshake $handshake_list { %>
                if ((<[join [dict get $handshake_cond_req $handshake] " || "]>) && (<[dict get $handshake_sig_in_from_out_sync $handshake]> == 1'b0)) begin
                    reg_<%=$handshake%> <= 1'b1;
                end<% } %>
            end<% foreach handshake $handshake_list { %>
            if ((reg_<%=$handshake%> == 1'b1) && (<[dict get $handshake_sig_in_from_out_sync $handshake]> == 1'b1)) begin
                reg_<%=$handshake%> <= 1'b0;
            end<% }  %>
        end
    end<% foreach handshake $handshake_list { %>
    assign <[adapt_signalname $handshake $obj_id]> = reg_<%=$handshake%>;<%="\n"%><% }
    } %><%="\n\n"%><%
    ## </handshake>
    ###########################################
-%>
<%
    ###########################################
    ## <register-write>
    %><[rf_comment_block "Regfile - registers (write-logic & read value assignmment)"]>
    assign <[rf_r_sel]> = ~<[rf_write]> & <[rf_sel]>;
    assign <[rf_w_sel]> =  <[rf_write]> & <[rf_sel]>;<%="\n"%><%-
    if {$fpga_impl} {-%>
    initial begin
        <[rf_write_permitted]> = 1'b0;
        <[rf_read_permitted]>  = 1'b0;
    end<%="\n"%><% } -%>
    always @(posedge <[clk]><% if {!$fpga_impl} { %> or negedge <[reset]><% } %>) begin
        if (<[reset]> == 1'b0) begin
            <[rf_write_permitted]> <= 1'b0;
            <[rf_read_permitted]>  <= 1'b0;
        end else begin
            if (<[rf_r_sel]> == 1'b1) begin
                <[rf_read_permitted]>  <= <[rf_next_read_permitted]>;
            end
            if (<[rf_w_sel]> == 1'b1) begin
                <[rf_write_permitted]> <= <[rf_next_write_permitted]>;
            end
        end
    end<%="\n"%><%
    foreach_array entry $entry_list {
        set maxlen_signame [max_array_entry_len $entry(regs) name]
        set maxlen_signalname [expr [max_array_entry_len $entry(regs) signal] + 2]
    %>
    <[format "// %s @ %s" $entry(name)  $entry(address)]><% if {[info exists entry(handshake)]} { %><[format " (%s)" [regsub -all {\m\S+:} $entry(handshake) {}]]><% }
    echo "\n"
    if {[foreach_array_contains reg $entry(regs) {[write_reg] && ![fullcustom_reg]}]} {
       if {$fpga_impl} {-%>
    initial begin<%-
        foreach_array_with reg $entry(regs) {[write_reg] && ![fullcustom_reg]} { %>
        <[reg_name]> = <%=$reg(reset)%>;<% }
            if {[foreach_array_contains reg $entry(regs) {[fullcustom_reg]}]} {
                set fc_reset_list {}
                foreach_array_with reg $entry(regs) {[write_reg] && [fullcustom_reg]} {
                    lappend fc_reset_list [format "%12s// TODO: [reg_name] <= $reg(reset);" {}]
                }
            %>
            <[pop_keep_block_content keep_block_data "keep" "fullcustom_reset_${entry(name)}_fpga" ".v" "\n[join $fc_reset_list "\n"]
            "]><% } elseif {[foreach_array_contains reg $entry(regs) {[custom_reg]}]} { %>
            <[pop_keep_block_content keep_block_data "keep" "custom_reset_${entry(name)}_fpga" ".v" ""]><%
            } %>
    end<%="\n"%><% } -%>
    always @(posedge <[clk]><% if {!$fpga_impl} { %> or negedge <[reset]><% } %>) begin
        if (<[reset]> == 1'b0) begin<% foreach_array_with reg $entry(regs) {[write_reg] && ![fullcustom_reg]} { %>
            <[reg_name]> <= <%=$reg(reset)%>;<% }
            if {[foreach_array_contains reg $entry(regs) {[fullcustom_reg]}]} {
                set fc_reset_list {}
                foreach_array_with reg $entry(regs) {[write_reg] && [fullcustom_reg]} {
                    lappend fc_reset_list [format "%12s// TODO: [reg_name] <= $reg(reset);" {}]
                }
            %>
            <[pop_keep_block_content keep_block_data "keep" "fullcustom_reset_${entry(name)}" ".v" "\n[join $fc_reset_list "\n"]
            "]><% } elseif {[foreach_array_contains reg $entry(regs) {[custom_reg]}]} { %>
            <[pop_keep_block_content keep_block_data "keep" "custom_reset_${entry(name)}" ".v" ""]><%
            } %>
        end else begin<%
            foreach_array_with reg $entry(regs) {[write_reg] && [sctrigger_reg] && ![custom_reg]} { %>
            <[reg_name]> <= <%=$reg(reset)%>;<% }
            %>
            if (<[rf_w_sel]> && <[rf_enable]>) begin
                if (<% if {$entry(protected)} {%>(<%}%><[rf_addr]> == <[string trim [param]]><% if {$entry(protected)} {%>) && <[rf_prot_ok]><%}%>) begin<%
                    for {set byte 0} {$byte < 4} {incr byte} {
                        foreach_array_preamble_epilog_with reg $entry(regs) {[write_reg] && [reg_entrybits_in_bytesel $byte]} { %>
                    if (<[rf_bytesel]>[<%=$byte%>] == 1'b1) begin<% } { %><%
                        if {![custom_reg]} {%>
                        <[reg_name]><[reg_range_bytesel $byte]> <= <[rf_w_data]>[<[reg_entrybits_bytesel $byte]>];<%
                        } else { %>
                        <[pop_keep_block_content keep_block_data "keep" "custom_assign_$entry(name)_$reg(name)" ".v" "
                        // TODO: [reg_name][reg_range_bytesel $byte] <= [rf_w_data]\[[reg_entrybits_bytesel $byte]\];
                        "]><% } } { %>
                    end<% } } %>
                end
            end<%
            if {[foreach_array_contains reg $entry(regs) {[custom_reg]}]} {%>
            <[pop_keep_block_content keep_block_data "keep" "custom_code_${entry(name)}"]><% } %>
        end
    end<% foreach_array_with reg $entry(regs) {[write_reg] && ($reg(signal) ne "-")} { %>
    assign <[signal_name]><[signal_entrybits]> = <[string trim [reg_name]]>;<% } %><%="\n"%><%
    }
    foreach_array reg $entry(regs) {
        if {[write_reg]} {
            set _reg_val_output "[string trim [reg_name]]"
        } elseif {[read_reg_sync]} {
            set _reg_val_output "_${entry(name)}_${reg(name)}_sync"
        } elseif {[read_reg]} {
            set _reg_val_output "[string trim [signal_name][signal_entrybits]]"
        } elseif {$reg(type) eq "-"} {
            set _reg_val_output "$reg(width)'b0"
        } else {
            warn_rftp "Unkown regfile type for $entry(name) - $reg(name)-- set to zero"
            set _reg_val_output "$reg(width)'b0"
        }
        if {![custom_reg]} {%>
    assign <[reg_val]>[<[reg_entrybits]>] = <%=$_reg_val_output%>;<%
        } else { %>
    <[pop_keep_block_content keep_block_data "keep" "custom_read_output_$entry(name)_$reg(name)" ".v" "
    // TODO: assign [reg_val]\[[reg_entrybits]\] = ${_reg_val_output};
    "]><% } } %><%="\n"%><% } %><%="\n"
    %><[rf_comment_block "apb ready/error generate"]>
    always @(*) begin
        <[rf_ready_sig]> = 1'b0;
        if (<[rf_enable]> == 1'b1) begin
            <[rf_ready_sig]> = 1'b1;
        end<%
        foreach_array entry $entry_list {
            if {[foreach_array_contains reg $entry(regs) {[custom_reg]}]} {%>
        <[pop_keep_block_content keep_block_data "keep" "custom_ready_$entry(name)" ".v" "
        // TODO: generate ready for custom entry $entry(name)
        //if ([rf_addr] == [string trim [param]]) begin
        //    [rf_ready_sig] = CONDITION;
        //end
        "]><%
            }
        }
        foreach handshake $handshake_list { %>
        if (<[join [dict get $handshake_cond_req $handshake] " || "]>) begin
            <[rf_ready_sig]> = <[dict get $handshake_sig_in_from_out_sync $handshake]> & reg_<%=$handshake%>;
        end<% } %>
        <[rf_err_sig]> = 1'b0;
        if (<[rf_w_sel]> && <[rf_enable]>) begin
            <[rf_err_sig]> = ~<[rf_write_permitted]>;
        end
        if (<[rf_r_sel]> && <[rf_enable]>) begin
            <[rf_err_sig]> = ~<[rf_read_permitted]>;
        end
        <[pop_keep_block_content keep_block_data "keep" "generate-apb-ready-error"]>
    end
    assign <[rf_ready]> = <[rf_ready_sig]>;
    assign <[rf_err]> = <[rf_err_sig]>;

    <[pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-code"]><%
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
                <[rf_r_data_sig]> = <[reg_val]>;<% if {[foreach_array_contains reg $entry(regs) {[write_reg]}]} { %>
                <[rf_next_write_permitted]> = <% if {$entry(protected)} { %><[rf_prot_ok]><% } else { %>1<% } %>;<% } %><%
                if {$entry(protected)} {%>
                <[rf_next_read_permitted]> = <[rf_prot_ok]>;<% } %>
            end<% } %>
            <%=[pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-outputmux"] %>
            default: begin
                <[rf_r_data_sig]> = 32'h0000_0000;
                <[rf_next_read_permitted]> = 0;
            end
        endcase
    end
    assign <[rf_r_data]> = <[rf_r_data_sig]>;
    <%=[pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-outputcode"] %><%
    ## </output mux> ##
    ###########################################
%>
<%-
    }
    ## </regfiles> ##
    ###########################################
-%>

<%- # vim: set filetype=verilog_template: -%>
