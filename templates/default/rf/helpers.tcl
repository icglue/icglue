##  icglue - template regfile
%(
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
proc rf_prot                 {} { return {apb_prot_i[0]}           }
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
array set rf [lindex $mod_data(regfiles) 0] 
set entry_list $rf(entries)

set rf_aw $rf(addrwidth)
set rf_dw $rf(datawidth)
set rf_bw [expr {($rf_dw + 7)/8}]

set w_checks [list \
    rf_addr    $rf_aw \
    rf_bytesel $rf_bw \
    rf_w_data  $rf_dw \
    rf_r_data  $rf_dw \
]

foreach {pp w} $w_checks {
    set p [$pp]
    foreach mp $mod_data(ports) {
        if {[dict get $mp name] eq $p} {
            set pw [dict get $mp size]
            if {$pw != $w} {
                warn_rftp "Port $p should be $w bits wide but is $pw bits wide."
            }
        }
    }
}

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
