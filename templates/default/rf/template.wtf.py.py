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
%)
from .regfile_generics import regfile


class ${rf_name}(regfile):
    def __init__(self, rfdev, base_addr):
        super().__init__(rfdev, base_addr)

        with self as r:
%           foreach_array entry $entry_list {
%           # available keys in entry: entryname address

            with r\['${entry(name)}'\].represent(addr=[format "0x%x" ${entry(address)}], write_mask=[write_mask]) as e:
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
                e\['${reg(name)}'\].represent(bits="${reg(entrybits)}", access="${reg(type)}", ${reset_attr}desc="${reg(comment)}")
%(              }
           }
%)
%#echo "\n    [pop_keep_block_content keep_block_data "keep" "custom_class_defs" "" "    "]"
