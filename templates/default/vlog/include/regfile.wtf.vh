%(
proc warn_rftp {msg} {
    upvar mod_data(name) rfname
    log -warn -id RFTP "$rfname: $msg"
}

array set rf [lindex $mod_data(regfiles) 0]

set rf_interface [ig::db::get_attribute -object $rf(object) -attribute "interface"]
set rf_prot_sfx {[0]}
if {$rf_interface ne "apb"} {set rf_prot_sfx {}}
set rf_ports     [ig::db::get_attribute -object $rf(object) -attribute "ports"]

proc rf_clk                  {} { variable rf_ports ; return [lindex [dict get $rf_ports "clk"]         0] }
proc rf_reset                {} { variable rf_ports ; return [lindex [dict get $rf_ports "reset"]       0] }
proc rf_addr                 {} { variable rf_ports ; return [lindex [dict get $rf_ports "addr"]        0] }
proc rf_sel                  {} { variable rf_ports ; return [lindex [dict get $rf_ports "sel"]         0] }
proc rf_enable               {} { variable rf_ports ; return [lindex [dict get $rf_ports "enable"]      0] }
proc rf_write                {} { variable rf_ports ; return [lindex [dict get $rf_ports "write"]       0] }
proc rf_wdata                {} { variable rf_ports ; return [lindex [dict get $rf_ports "wdata"]       0] }
proc rf_bytesel              {} { variable rf_ports ; return [lindex [dict get $rf_ports "bytesel"]     0] }
proc rf_prot                 {} { variable rf_ports ; variable rf_prot_sfx ; return [lindex [dict get $rf_ports "prot"] 0]$rf_prot_sfx }
proc rf_prot_enable          {} { variable rf_ports ; return [lindex [dict get $rf_ports "prot_enable"] 0] }

proc rf_rdata                {} { variable rf_ports ; return [lindex [dict get $rf_ports "rdata"]       0] }
proc rf_ready                {} { variable rf_ports ; return [lindex [dict get $rf_ports "ready"]       0] }
proc rf_err                  {} { variable rf_ports ; return [lindex [dict get $rf_ports "err"]         0] }


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

# synchronizers
set sync_mod   [ig::db::get_attribute -object $rf(object) -attribute "sync_module"]
set sync_pfx   [ig::db::get_attribute -object $rf(object) -attribute "sync_prefix"]
set sync_ports [ig::db::get_attribute -object $rf(object) -attribute "sync_ports"]
set sync_port_mlen 0
foreach {p d} $sync_ports {
    lassign $d n s
    set sync_port_mlen [expr {max ($sync_port_mlen, [string length $n])}]
}
proc sync_clk   {} { variable sync_ports ; return [lindex [dict get $sync_ports "clk"]   0] }
proc sync_reset {} { variable sync_ports ; return [lindex [dict get $sync_ports "reset"] 0] }
proc sync_in    {} { variable sync_ports ; return [lindex [dict get $sync_ports "in"]    0] }
proc sync_out   {} { variable sync_ports ; return [lindex [dict get $sync_ports "out"]   0] }

set fpga_impl [ig::db::get_attribute -object $obj_id -attribute "fpga" -default "false"]

proc rf_comment_block {blockname {pre "    "}} {
    set textw 69
    return [string cat \
               "$pre/**[string repeat * $textw]**/\n" \
               [format "$pre/* %-*s */\n" $textw $blockname] \
               "$pre/**[string repeat * $textw]**/" \
        ]
}
proc param     {} {
    upvar entry(name) name maxlen_name maxlen_name
    return [format "RA_%-${maxlen_name}s" [string toupper $name]]
}
proc addr_vlog {} {
    upvar entry(address) address
    variable rf_aw

    set aw_nibbles [expr {($rf_aw+3) / 4}]

    return [format "%d'h%0*X" $rf_aw $aw_nibbles $address]
}

proc reg_name {} {
    upvar entry(name) name maxlen_signame maxlen_signame reg(name) regname
    set maxlen_reg_name [expr {[string length $name] + 1 + $maxlen_signame}]
    return [format "reg_%-${maxlen_reg_name}s" "${name}_${regname}"]
}
proc trig_name {} {
    upvar entry(name) name maxlen_signame maxlen_signame reg(name) regname
    set maxlen_reg_name [expr {[string length $name] + 1 + $maxlen_signame}]
    return [format "trg_%-${maxlen_reg_name}s" "${name}_${regname}"]
}
proc reg_range {} {
    upvar reg(width) width
    return [format "%7s" [ig::vlog::bitrange $width]]
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
            if {$sigid == ""} {
                ig::log -error "Signal ${signal} for entrybits not found"
            } else {
                if {[ig::db::get_attribute -object $sigid -attribute size] == 1} {
                    return [format "%7s" {}]
                }
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
proc bits_to_suffix {bitrange} {
    set bitrange [string trim $bitrange]

    if {$bitrange eq ""} {return ""}

    set bitrange [string map {: _ [ {} ] {} { } {}} $bitrange]

    return "_${bitrange}"
}

# todo iterate ?
set entry_list $rf(entries)

set rf_aw $rf(addrwidth)
set rf_dw $rf(datawidth)
set rf_bw [expr {($rf_dw + 7)/8}]

set maxlen_name            [max_array_entry_len $entry_list name]
set maxlen_signame         0

set has_read_reg_sync false
set sig_syncs {}
set handshake_list {}
set handshake_cond_req {}
set handshake_sig_in_from_out {}
set handshake_sig_in_from_out_sync {}

foreach_array entry $entry_list {
    foreach_array_with reg $entry(regs) {[read_reg_sync]} {
        set has_read_reg_sync true
        lappend sig_syncs "$reg(signal)" "${entry(name)}_${reg(name)}" "[reg_range]" "[signal_entrybits]"
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
            dict set handshake_sig_in_from_out_sync $handshake_sig_out sync_${handshake_sig_in}
        } else {
            dict set handshake_sig_in_from_out_sync $handshake_sig_out [adapt_signalname ${handshake_sig_in} $obj_id]
        }
    } else {
        if {[dict get $handshake_sig_in_from_out $handshake_sig_out] ne $handshake_sig_in} {
            warn_rftp "Handshake signal $handshake_sig_out is used with different feedback signals -- " \
                "first occurence: [dict get $handshake_sig_in_from_out $handshake_sig_out] / redeclared $handshake_sig_in (ignored)"
        }
    }
    set write_only_reg true
    foreach_array_with reg $entry(regs) {[read_reg]} {
        set write_only_reg false
    }

    set additional_handshake_cond_req {}
    if {$write_only_reg} {
        set additional_handshake_cond_req " && [rf_w_sel]"
    }
    if {$entry(protected)} {
        dict lappend handshake_cond_req $handshake_sig_out "([rf_addr] == [string trim [param]])$additional_handshake_cond_req && [rf_prot_ok]"
    } else {
        dict lappend handshake_cond_req $handshake_sig_out "([rf_addr] == [string trim [param]])$additional_handshake_cond_req"
    }
}
%)


[rf_comment_block "Regfile ADDRESS definition"]
% foreach_array entry $entry_list {
    localparam [param] = [addr_vlog];
% }
    [pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-addresses"]

[rf_comment_block "regfile signal definition"]

    reg  [format "%7s" [ig::vlog::bitrange $rf_dw]] [rf_r_data_sig];
    reg          [rf_ready_sig];
    reg          [rf_err_sig];
    wire         [rf_w_sel];
    wire         [rf_r_sel];
    wire         [rf_prot_ok];
    reg          [rf_write_permitted];
    reg          [rf_next_write_permitted];
    reg          [rf_read_permitted];
    reg          [rf_next_read_permitted];
% if {$has_read_reg_sync} {

    reg          do_ready_sync_delay;
    wire         ready_sync_delay;
    reg          ready_sync_delay_r;
    wire         ready_sync_delay_done;
% }
% foreach_preamble {s r w sb} $sig_syncs {

    // common sync signals
%   } {
    wire $w sync_$r;
% }
% foreach_preamble handshake $handshake_list {

    // handshake register
% } {
    reg          reg_$handshake;
% }
% foreach_array_preamble entry $entry_list {

    // regfile registers / wires
% } {
    wire [format "%7s" [ig::vlog::bitrange $rf_dw]] [reg_val];
%     foreach_array_with reg $entry(regs) {[write_reg] && [sctrigger_reg] && ![custom_reg]} {
    reg          [string trim [trig_name]];
%     }
%     foreach_array_with reg $entry(regs) {[write_reg] && ![fullcustom_reg]} {
    reg  [reg_range] [string trim [reg_name]];
%     }
% echo "\n"
% }
    [pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-declaration"]

    assign [rf_prot_ok] = [rf_prot] | ~[rf_prot_enable];


% ###########################################
% # icglue instance code
%I(vlog/include/inst.wtf.vh)
% ###########################################
%
% if {$has_read_reg_sync} {

    // "not a synchronizer" - just for delay measurement
    $sync_mod i_${sync_pfx}_delay_ready (
        .[format %-*s $sync_port_mlen [sync_clk]  ] ([rf_clk]),
        .[format %-*s $sync_port_mlen [sync_reset]] ([rf_reset]),
        .[format %-*s $sync_port_mlen [sync_in]   ] (do_ready_sync_delay),
        .[format %-*s $sync_port_mlen [sync_out]  ] (ready_sync_delay)
    );
%    if {$fpga_impl} {
    initial begin
        ready_sync_delay_r = 1'b0;
    end
%    }
    always @(posedge [rf_clk][expr {$fpga_impl ? {} : " or negedge [rf_reset]"}]) begin
        if ([rf_reset] == 1'b0) begin
            ready_sync_delay_r <= 1'b0;
        end else begin
            if (ready_sync_delay) begin
                ready_sync_delay_r <= 1'b1;
            end
            if ([rf_ready]) begin
                ready_sync_delay_r <= 1'b0;
            end
        end
    end
    assign ready_sync_delay_done = ready_sync_delay | ready_sync_delay_r;
% }
%
% foreach_preamble {s r w sb} $sig_syncs {

[rf_comment_block "synchronizers"]
% } {
    $sync_mod i_${sync_pfx}_${s}[bits_to_suffix $sb][string trim $w] (
        .[format %-*s $sync_port_mlen [sync_clk]  ] ([rf_clk]),
        .[format %-*s $sync_port_mlen [sync_reset]] ([rf_reset]),
        .[format %-*s $sync_port_mlen [sync_in]   ] ([adapt_signalname $s $obj_id][string trim $sb]),
        .[format %-*s $sync_port_mlen [sync_out]  ] (sync_$r)
    );
% }
%
% if {$handshake_list ne ""} {
[rf_comment_block "handshake"]
%  if {$fpga_impl} {
%   foreach_preamble_epilog $handshake $handshake_list {
    initial begin
%   } {
        reg_$handshake = 1'b0;
%   } {
    end
%   }
%  }
    always @(posedge [rf_clk][expr {$fpga_impl ? {} : " or negedge [rf_reset]"}]) begin
        if ([rf_reset] == 1'b0) begin
%    foreach handshake $handshake_list {
            reg_$handshake <= 1'b0;
%    }
        end else begin
            if (([rf_sel] == 1'b1) && ([rf_enable] == 1'b1)) begin
%    foreach handshake $handshake_list {
                if (([join [dict get $handshake_cond_req $handshake] " || "]) && ([dict get $handshake_sig_in_from_out_sync $handshake] == 1'b0)) begin
                    reg_$handshake <= 1'b1;
                end
%    }
            end
%    foreach handshake $handshake_list {
            if (([rf_enable] == 1'b0) || ((reg_$handshake == 1'b1) && ([dict get $handshake_sig_in_from_out_sync $handshake] == 1'b1))) begin
                reg_$handshake <= 1'b0;
            end
%    }
        end
    end
%    foreach handshake $handshake_list {
    assign [adapt_signalname $handshake $obj_id] = reg_$handshake;
%    }
%
% }

[rf_comment_block "Regfile - registers (write-logic & read value assignmment)"]
    assign [rf_r_sel] = ~[rf_write] & [rf_sel];
    assign [rf_w_sel] =  [rf_write] & [rf_sel];
% if {$fpga_impl} {
    initial begin
        [rf_write_permitted] = 1'b0;
        [rf_read_permitted]  = 1'b0;
    end
% }
    always @(posedge [rf_clk][expr {$fpga_impl ? {} : " or negedge [rf_reset]"}]) begin
        if ([rf_reset] == 1'b0) begin
            [rf_write_permitted] <= 1'b0;
            [rf_read_permitted]  <= 1'b0;
        end else begin
            if ([rf_r_sel] == 1'b1) begin
                [rf_read_permitted]  <= [rf_next_read_permitted];
            end
            if ([rf_w_sel] == 1'b1) begin
                [rf_write_permitted] <= [rf_next_write_permitted];
            end
        end
    end

%foreach_array entry $entry_list {
% set maxlen_signame [max_array_entry_len $entry(regs) name]
% set maxlen_signalname [expr [max_array_entry_len $entry(regs) signal] + 2]
    [format "// %s @ %s" $entry(name)  $entry(address)[expr {[info exists entry(handshake)] ? [format " (%s)" [regsub -all {\m\S+:} $entry(handshake) {}]] : ""}]]
% if {[foreach_array_contains reg $entry(regs) {[write_reg] && ![fullcustom_reg]}]} {
%  if {$fpga_impl} {
    initial begin
%   foreach_array_with reg $entry(regs) {[write_reg] && ![fullcustom_reg]} {
        [reg_name] = $reg(reset);
%   }
%   if {[foreach_array_contains reg $entry(regs) {[fullcustom_reg]}]} {
%    set fc_reset_list {}
%    foreach_array_with reg $entry(regs) {[write_reg] && [fullcustom_reg]} {
%     lappend fc_reset_list [format "%12s// TODO: [reg_name] = $reg(reset);" {}]
%    }
        [pop_keep_block_content keep_block_data "keep" "fullcustom_reset_${entry(name)}_fpga" {} "\n[join $fc_reset_list "\n"]"]
%    } elseif {[foreach_array_contains reg $entry(regs) {[custom_reg]}]} {
        [pop_keep_block_content keep_block_data "keep" "custom_reset_${entry(name)}_fpga" {} ""]
%    }
    end
%  }
    always @(posedge [rf_clk][expr {$fpga_impl ? {} : " or negedge [rf_reset]"}]) begin
        if ([rf_reset] == 1'b0) begin
%  foreach_array_with reg $entry(regs) {[write_reg] && ![fullcustom_reg]} {
%   if {[sctrigger_reg] && ![custom_reg]} {
            [trig_name] <= 1'b0;
%   }
            [reg_name] <= $reg(reset);
%  }
%  if {[foreach_array_contains reg $entry(regs) {[fullcustom_reg]}]} {
%   set fc_reset_list {}
%   foreach_array_with reg $entry(regs) {[write_reg] && [fullcustom_reg]} {
%    lappend fc_reset_list [format "%12s// TODO: [reg_name] <= $reg(reset);" {}]
%   }
           [pop_keep_block_content keep_block_data "keep" "fullcustom_reset_${entry(name)}" {} "\n[join $fc_reset_list "\n"]"]
%  } elseif {[foreach_array_contains reg $entry(regs) {[custom_reg]}]} {
           [pop_keep_block_content keep_block_data "keep" "custom_reset_${entry(name)}" {} ""]
%  }
        end else begin
%  if {[foreach_array_contains reg $entry(regs) {[custom_reg]}]} {
            [pop_keep_block_content keep_block_data "keep" "custom_preface_code_${entry(name)}"]
%  }
%  foreach_array_with reg $entry(regs) {[write_reg] && [sctrigger_reg] && ![custom_reg]} {
            if ([trig_name]) begin
                [reg_name] <= $reg(reset);
                if ([rf_ready]) begin
                    [trig_name] <= 1'b0;
                end
            end
%  }
            if ([rf_w_sel] && [rf_enable]) begin
                if ([expr {$entry(protected) ? "(" : "" }][rf_addr] == [string trim [param]][expr {$entry(protected) ? ") && [rf_prot_ok]" : ""}]) begin
%  for {set byte 0} {$byte < $rf_bw} {incr byte} {
%   foreach_array_preamble_epilog_with reg $entry(regs) {[write_reg] && [reg_entrybits_in_bytesel $byte]} {
                    if ([rf_bytesel]\[$byte\] == 1'b1) begin
%   } {
%    if {![custom_reg]} {
%     if {[sctrigger_reg]} {
                        if (![trig_name]) begin
                            [trig_name]        <= 1'b1;
                            [reg_name][reg_range_bytesel $byte] <= [rf_wdata]\[[reg_entrybits_bytesel $byte]\];
                        end
%     } else {
                        [reg_name][reg_range_bytesel $byte] <= [rf_wdata]\[[reg_entrybits_bytesel $byte]\];
%     }
%    } else {
                        [pop_keep_block_content keep_block_data "keep" "custom_assign_$entry(name)_$reg(name)" {} "
                        // TODO: [reg_name][reg_range_bytesel $byte] <= [rf_wdata]\[[reg_entrybits_bytesel $byte]\];
                       "]
%    }
%   } {
                    end
%   }
%  }
                end
            end
%  if {[foreach_array_contains reg $entry(regs) {[custom_reg]}]} {
      [pop_keep_block_content keep_block_data "keep" "custom_code_${entry(name)}"]
%  }
        end
    end
% }
% foreach_array_with reg $entry(regs) {[write_reg] && ($reg(signal) ne "-")} {
    assign [signal_name][signal_entrybits] = [string trim [reg_name]];
% }
% foreach_array_preamble reg $entry(regs) {
%   echo "\n"
% } {
%  if {[write_reg]} {
%   set _reg_val_output "[string trim [reg_name]]"
%  } elseif {[read_reg_sync]} {
%   set _reg_val_output "sync_${entry(name)}_${reg(name)}"
%  } elseif {[read_reg]} {
%   if {[custom_reg] && $reg(signal) eq "-"} {
%    set _reg_val_output "/*CUSTOMSIGNAL*/"
%   } else {
%    set _reg_val_output "[string trim [signal_name][signal_entrybits]]"
%   }
%  } elseif {$reg(type) eq "-"} {
%   set _reg_val_output "$reg(width)'b0"
%  } else {
%   warn_rftp "Unkown regfile type for $entry(name) - $reg(name)-- set to zero"
%   set _reg_val_output "$reg(width)'b0"
%  }
%  if {![custom_reg]} {
    assign [reg_val]\[[reg_entrybits]\] = $_reg_val_output;
%  } else {
   [pop_keep_block_content keep_block_data "keep" "custom_read_output_$entry(name)_$reg(name)" {} "
   // TODO: assign [reg_val]\[[reg_entrybits]\] = ${_reg_val_output};
   "]
%  }
% }
% echo "\n"
%}

[rf_comment_block "apb ready/error generate"]
    always @(*) begin
        [rf_ready_sig] = 1'b1;
%if {$has_read_reg_sync} {
        do_ready_sync_delay = 1'b0;
%}
%foreach_array entry $entry_list {
% if {[foreach_array_contains reg $entry(regs) {[custom_reg]}]} {
        [pop_keep_block_content keep_block_data "keep" "custom_ready_$entry(name)" {} "
        // TODO: generate ready for custom entry $entry(name)
        //if ([rf_addr] == [string trim [param]]) begin
        //    [rf_ready_sig] = CONDITION;
        //end
        "]
% }
% if {[foreach_array_contains reg $entry(regs) {[sctrigger_reg] && ![custom_reg]}]} {
%  set trig_l [list]
%  set trig_strb_l [list]
%  for {set byte 0} {$byte < $rf_bw} {incr byte} {
%   set trig_l_in_cur_byte false
%   foreach_array_with reg $entry(regs) {[write_reg] && [sctrigger_reg] && ![custom_reg] && [reg_entrybits_in_bytesel $byte]} {
%    set trig_l_in_cur_byte true
%    lappend trig_l [string trim [trig_name]]
%   }
%   if {$trig_l_in_cur_byte} {
%    lappend trig_strb_l "[rf_bytesel]\[$byte\]"
%   }
%  }
        if (([rf_addr] == [string trim [param]]) && [rf_write] && ([join $trig_strb_l " | "])) begin
            [rf_ready_sig] = [join $trig_l " | "];
        end
% }
%}
%foreach_array entry $entry_list {
% if {[foreach_array_contains reg $entry(regs) {[read_reg_sync]}]} {
        if ([rf_addr] == [string trim [param]]) begin
            do_ready_sync_delay = ([rf_sel] == 1'b1) && ([rf_enable] == 1'b0);
            [rf_ready_sig] = ready_sync_delay_done;
        end
% }
%}
%foreach handshake $handshake_list {
        if (([join [dict get $handshake_cond_req $handshake] ") || ("])) begin
            [rf_ready_sig] = [dict get $handshake_sig_in_from_out_sync $handshake] & reg_$handshake;
        end
%}
        [rf_err_sig] = 1'b0;
        if ([rf_w_sel] && [rf_enable]) begin
            [rf_err_sig] = ~[rf_write_permitted];
        end
        if ([rf_r_sel] && [rf_enable]) begin
            [rf_err_sig] = ~[rf_read_permitted];
        end
        [pop_keep_block_content keep_block_data "keep" "generate-apb-ready-error"]
    end
    assign [rf_ready] = [rf_ready_sig];
    assign [rf_err] = [rf_err_sig];

    [pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-code"]

[rf_comment_block "Regfile registers (read-logic)"]
    always @(*) begin
        [rf_next_write_permitted] = 0;
        [rf_next_read_permitted] = 1'b1;
        case ([rf_addr])
%foreach_array entry $entry_list {
            [string trim [param]]: begin
                [rf_r_data_sig] = [reg_val];
%  if {[foreach_array_contains reg $entry(regs) {[write_reg]}]} {
                [rf_next_write_permitted] = [expr {$entry(protected) ? "[rf_prot_ok]" : "1'b1"}];
%  }
%  if {$entry(protected)} {
                [rf_next_read_permitted] = [rf_prot_ok];
%  }
            end
%}
            [pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-outputmux"]
            default: begin
                [rf_r_data_sig] = [format "%d'h%0*x" $rf_dw [expr {$rf_bw*2}] 0];
                [rf_next_read_permitted] = 1'b0;
            end
        endcase
    end
    assign [rf_rdata] = [rf_r_data_sig];
    [pop_keep_block_content keep_block_data "keep" "regfile-${rf(name)}-outputcode"]
%# vim: ft=verilog_wooftemplate
