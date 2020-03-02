% # Python register file template
% # TODO:
% #      - filter field list to not contain unused '-' fields
% #      - check field names and register names against Python keywords and issue warning at ICGlue runtime.
% #        Doing this at Python runtime with keywords.iskeyword() might be too late.
%
% # Tempalte helper
%(
    set register_list [regfile_to_arraylist $obj_id]

    set rf_name [object_name $obj_id]

    proc low_entry_bits {bit_str} {
        set bit_list [split $bit_str ":"]
        set bit_low [lindex [lsort -integer $bit_list] 0]
        return $bit_low
    }

    set base_indent [string repeat " " 4]
    set indent $base_indent
%)
# ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten

from rf_base import base_word, base_registerfile


################################################################################
# representation of register words with multiple fielads
%(
foreach_array register $register_list {
    echo "class _word_${register(name)}(base_word):\n"
    foreach_array field $register(regs) {
        # filter '-' fields
        if {${field(name)} ne "-"} {
                echo "${indent}${field(name)} = 0\n"
        }
    }
%)


%   # constructor
    def __init__(self, read_function, write_function):
        self.read_word  = read_function
        self.write_word = write_function
        self.offsets = {
%(
    foreach_array_join field $register(regs) {
        echo "${indent}${indent}${indent}${indent}\"${field(name)}\": [low_entry_bits ${field(entrybits)}]"
    } {
        echo ",\n" }
%)

        }
        self.widths = {
%(
    foreach_array_join field $register(regs) {
        echo "${indent}${indent}${indent}${indent}\"${field(name)}\": [low_entry_bits ${field(width)}]"
    } {
        echo ",\n" }
%)

        }


%    # read and write methods for each field
% foreach_array field $register(regs) {
%     set name ${field(name)}
%     if { $name ne "-" } {
    def read_${name}(self):
        register = self.read_word()
        return self.get_bits(register, self.offsets\[\"${name}\"\], self.widths\[\"${name}\"\])

    def write_${name}(self, val):
        register = self.read_word()
        register = self.set_bits(register, val, self.offsets\[\"${name}\"\], self.widths\[\"${name}\"\])
        self.write_word(register)

    ${name} = property(read_${name}, write_${name})

%        }
%    }

%   # special methods to access whole word with <REGISTER>._word which should not conflict with read_word / write_word class attributes
    def _read_word(self):
        return self.read_word()

    def _write_word(self, val):
        self.write_word(val)

    _word = property(_read_word, _write_word)

%   # dict helper methods for access with <REGISTER>._dict
    def _read_word_dict(self):
        word = self.read_word()
        word_dict = {}
        for name, offset, width in zip(self.offsets.keys(), self.offsets.values(), self.widths.values()):
            word_dict.update({name: self.get_bits(word, offset, width)})
        return word_dict

    def _write_word_dict(self, val_dict, old_val=None):
        if(old_val == None):
            word = self.read_word()
        else:
            word = old_val
        for name, val in zip(val_dict.keys(), val_dict.values()):
            assert (name in self.offsets.keys())
            word = self.set_bits(word, val, self.offsets\[name\], self.widths\[name\])
        self.write_word(word)

    _dict = property(_read_word_dict, _write_word_dict)


% # close "foreach_array register $register_list"
%}




################################################################################
# register file representations
class rf_${rf_name}(base_registerfile):

    def __init__(self, base_addr, read_function, write_function):
        self.base_addr      = base_addr
        self.read_function  = read_function
        self.write_function = write_function
        self.word_offsets = {
%(
set indent [string repeat $base_indent 3]
foreach_array_join entry $register_list {
    echo "${indent}\"${entry(name)}\": $entry(address)"
     } {
    echo ",\n" }
%)

        }
%(
set indent [string repeat $base_indent 2]
foreach_array entry $register_list {
    echo "${indent}self.${entry(name)} = _word_${entry(name)}(self.read_${entry(name)}, self.write_${entry(name)})\n"
}
%)


%(
set indent [string repeat $base_indent 1]
foreach_array entry $register_list {
    echo "${indent}# ${entry(name)}\n"
    echo "${indent}def read_${entry(name)}(self):\n"
    echo "${indent}${indent}return self.read_word(self.word_offsets\[\"${entry(name)}\"\])\n\n"

    echo "${indent}def write_${entry(name)}(self, val):\n"
    echo "${indent}${indent}self.write_word(self.word_offsets\[\"${entry(name)}\"\], val)\n\n"
}
%)
