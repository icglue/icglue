% # Python register file template
%
% # Template helper
%(
    set entry_list [regfile_to_arraylist $obj_id]
    set rf_name [object_name $obj_id]
    proc write_reg {} {
        return [uplevel 1 {regexp -nocase {W} $reg(type)}]
    }
    proc write_mask {} {
        upvar entry(regs) regs
        variable maxlen_reg
        set mask 0
        foreach_array_with reg $regs {$reg(name) ne "-" && [write_reg]} {
            set mask [expr {$mask | (1<<(${reg(bit_high)}+1)) - (1<<(${reg(bit_low)}))}]
        }
        return [format "0x%08X" $mask]
    }
    proc snake_case {str} {
        return [subst [regsub -all {(^|_)(\w)} $str {[string toupper "\2"]}]]
    }

    set rf_aw [ig::db::get_attribute -object $obj_id -attribute addrwidth]
    set aw_nibble [expr {int(ceil($rf_aw / 4.0))}]
%)
"""
Registerfile module for address offset translation (${rf_name} registers).
Generated by icglue. - https://icglue.org"""
# pylint:disable=too-many-lines

from regfile_generics import Regfile


class [snake_case ${rf_name}]Regfile(Regfile):
    # pylint: disable=missing-class-docstring,too-many-statements,too-few-public-methods
    def __init__(self, rfdev, base_addr=0x0):
        super().__init__(rfdev, base_addr)
        with self as regfile:
            # pylint: disable=line-too-long
%           foreach_array_join entry $entry_list {
%           # available keys in entry: entryname address
            with regfile\['${entry(name)}'\].represent(addr=[format "0x%0*X" $aw_nibble ${entry(address)}], write_mask=[write_mask]) as reg:
%(              foreach_array_with reg $entry(regs) {$reg(name) ne "-"} {
                # available keys in reg: name signal width type entrybits reset comment
                set reset_attr {}
                if {[write_reg]} {
                    set prstval [ig::vlog::parse_value $reg(reset)]
                    if {![lindex $prstval 0]} {
                        set reset_attr "reset=\"$reg(reset)\","
                    } else {
                        set reset_attr "reset=\"[lindex $prstval 1]\", "
                    }
                }
%)
                reg\['${reg(name)}'\].represent(bits="${reg(entrybits)}", access="${reg(type)}", ${reset_attr}desc="[string map {"\n" "\\n"} ${reg(comment)}]")
%(              }
           } { echo "\n"}
%)
%#echo "\n    [pop_keep_block_content keep_block_data "keep" "custom_class_defs" "" "    "]"

# vim: nowrap
