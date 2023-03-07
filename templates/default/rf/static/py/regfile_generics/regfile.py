# Copyright (C) 2020-2021 Andreas Dixius, Felix Neumärker
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

"""
Generic Regfile file access through names / items operator of the regfile class
"""

import abc
import traceback
import warnings

__version__ = "0.0.3"


# pylint: disable=missing-class-docstring, missing-function-docstring

class RegisterEntryAbstract(metaclass=abc.ABCMeta):
    """Abstract class handling dict-like access to Field of the register."""

    def __init__(self, **kwargs):
        """Constructor - Mandatory kwargs: regfile and address offset."""
        object.__setattr__(self, "_lock", False)
        self.regfile = kwargs.pop('regfile')
        self.addr = int(kwargs.pop('addr'))

        self.write_mask = int(kwargs.pop('write_mask', -1))
        self._fields = kwargs.pop('fields', {})
        self._writable_fieldnames = kwargs.pop('_writable_fieldnames', None)
        self._userattributes = tuple(kwargs.keys())

        for attr, value in kwargs.items():
            self.__setattr__(attr, value)
        self._lock = True

    @abc.abstractmethod
    def _get_value(self):
        """Abstract method to get the value of the register."""

    @abc.abstractmethod
    def _set_value(self, value, mask):
        """Abstract method to set the value of the register."""

    def __iter__(self):
        """Iterator over the (name, fieldvalue) mainly for dict() conversion."""
        int_value = self._get_value()
        for key, value in self._fields.items():
            yield key, value.get_field(int_value)

    def items(self):
        """Providing the tuple (fieldname, field[RegisterField]) for (self-)inspection."""
        return self._fields.items()

    def get_field_names(self):
        """Returns a copy of the field's dictionary's list of keys (fieldnames)."""
        return self._fields.keys()

    def __getitem__(self, key):
        """Dict-like access to read a value from a field."""
        if key in self._fields:
            return self._fields[key].get_field(self._get_value())

        raise KeyError(f"Field {key} does not exist. "
                       f"Available fields: {list(self._fields.keys())}")  # pragma: nocover

    def __setattr__(self, name, value):
        if self._lock is True and name not in self.__dict__:
            raise AttributeError(f"Unable to allocate attribute {name} - Instance is locked.")

        super().__setattr__(name, value)

    def __setitem__(self, key, value):
        """Dict-like access to write a value to a field."""
        if key not in self._fields:
            raise KeyError(f"Field {key} does not exist. "
                           f"Available fields: {list(self.get_field_names())}")  # pragma: nocover

        field = self._fields[key]
        truncval = self._fit_fieldvalue_for_write(field, value)
        self._set_value(truncval << field.lsb, field.get_mask())

    def _fit_fieldvalue(self, field, value):
        """Truncate a value to fit into the field is necessary and raise a warning."""
        mask = field.get_mask()
        fieldmask = mask >> field.lsb
        truncval = value & fieldmask

        if value != truncval:
            _regfile_warn_user(f"{field.name}: value 0x{value:x} is truncated to 0x{truncval:x} "
                               f"(mask: 0x{fieldmask}).")
        return truncval

    def _fit_fieldvalue_for_write(self, field, value):
        """Additional to the truncation, check if field is writable."""
        mask = field.get_mask()
        if mask & self.write_mask != mask:
            _regfile_warn_user(f"Writing read-only field {field.name} (value: 0x{value:08x} -- "
                               f"mask: 0x{mask:08x} write_mask: 0x{self.write_mask:08x}).")

        return self._fit_fieldvalue(field, value)

    def get_dict(self, int_value=None):
        """Get dictionary field view of the register.
        If int_value is not specified a read will be executed,
        otherwise the int_value is decomposed to the fields"""
        if int_value is None:
            int_value = self._get_value()
        return {name: field.get_field(int_value) for name, field in self.items()}

    def get_value(self, field_dict=None):
        """Return the integer view of the register.
        If field_dict is not specified a read will be executed,
        otherwise the dict is composed to get the integer value"""
        if field_dict is None:
            return self._get_value()

        if isinstance(field_dict, dict):
            value = 0
            for fieldname, fieldvalue in field_dict.items():
                field = self._fields[fieldname]
                value |= self._fit_fieldvalue(field, fieldvalue) << field.lsb
            return value
        raise TypeError(f"Unable to get_value for type {type(value)} "
                        f"-- {str(value)}.")  # pragma: nocover

    def get_writable_fieldnames(self):
        """Return a copied list containing all writable fieldnames"""
        return list(self._writable_fieldnames)

    def writable_field_items(self):
        """Tuple of object over all writable fieldnames"""
        writable_fields = []
        for name, field in self.items():
            field_mask = field.get_mask()
            if field_mask & self.write_mask == field_mask:
                writable_fields.append((name, field))
        return writable_fields

    def get_name(self):
        """Get the name of the register, if set otherwise return UNNAMED"""
        name = "UNNAMED"
        if hasattr(self, 'name'):
            name = self.name

        return name

    def __str__(self):
        """Read the register and format it decomposed as fields as well as integer value."""
        int_value = self._get_value()
        strfields = []
        for name, field in self.items():
            strfields.append(f"'{name}': 0x{field.get_field(int_value):x}")
        return f"Register {self.get_name()}: {{{', '.join(strfields)}}} = 0x{int_value:x}"

    def set_value(self, value, mask=None):
        """Set the value of register. The value can be an integer a dict or
        a register object (e.g. obtained by 'read_entry()'."""
        if mask is None:
            mask = self.write_mask

        if isinstance(value, int):
            self._set_value(value, mask)
        elif isinstance(value, dict):
            writable_fieldnames = self.get_writable_fieldnames()
            write_value = 0
            for fieldname, fieldvalue in value.items():
                if fieldname in writable_fieldnames:
                    writable_fieldnames.remove(fieldname)
                    field = self._fields[fieldname]
                    write_value |= self._fit_fieldvalue_for_write(field, fieldvalue) << field.lsb
                elif fieldname not in self.get_field_names():
                    _regfile_warn_user(
                        f"Ignoring non existent Field {fieldname} for write.")

            if writable_fieldnames:
                _regfile_warn_user(f"Field(s) {', '.join(writable_fieldnames)} were not explicitly "
                                   f"set during write of register {self.get_name()}!")

            self._set_value(write_value, self.write_mask)
        elif isinstance(value, RegisterEntry):
            self._set_value(value.get_value(), self.write_mask)
        else:
            raise TypeError(f"Unable to assign type {type(value)} "
                            f"-- {str(value)}.")  # pragma: nocover

    def __int__(self):
        """Integer conversion - executes a read"""
        return self.get_value()

    def __eq__(self, other):
        """Equal comparison with integer -executes a read"""
        if isinstance(other, int):
            return self.get_value() == other
        return super().__eq__(other)  # pragma: nocover

    def __lt__(self, other):
        """Less-than comparison with integer -executes a read"""
        if isinstance(other, int):
            return self.get_value() < other
        return super().__lt__(other)  # pragma: nocover

    def __le__(self, other):
        """Less-than/equal comparison with integer -executes a read"""
        if isinstance(other, int):
            return self.get_value() <= other
        return super().__le__(other)  # pragma: nocover

    def __gt__(self, other):
        """Greater-than comparison with integer -executes a read"""
        if isinstance(other, int):
            return self.get_value() > other
        return super().__gt__(other)  # pragma: nocover

    def __ge__(self, other):
        """Greater-than/equal comparison with integer -executes a read"""
        if isinstance(other, int):
            return self.get_value() >= other
        return super().__ge__(other)  # pragma: nocover


class RegisterEntry(RegisterEntryAbstract):
    """Register Entry class - adding .represent() initialization for fields
    and UVM-like access"""

    def __init__(self, **kwargs):
        """Constructor see also RegisterEntryAbstract"""
        super().__init__(**kwargs)
        self._lock = False
        self._add_fields_mode = kwargs.pop('_add_fields_mode', False)
        self.desired_value = kwargs.pop('desired_value', 0)
        self.mirrored_value = kwargs.pop('mirrored_value', 0)
        self._reset = kwargs.pop('_reset', 0)
        self._lock = True

    def _get_value(self):
        """Get value returns the mirrored value."""
        return self.mirrored_value

    def _set_value(self, value, mask):
        """Set value updates the desired and mirrored value"""
        self.desired_value = (self.desired_value & ~mask) | (value & mask)
        self.mirrored_value = self.desired_value

    def __enter__(self):
        """The with statement allows to add fields to the register -

        with reg as add_fields_register:
            add_fields_register.represent(name="FIELDNAME", bits=(msb,lsb), reset=0x0, ...)
        """
        self._add_fields_mode = True
        return self

    def __exit__(self, exception_type, exception_value, exception_traceback):
        """Lock the register fields - sort-out the writable_fieldnames
        with the help of the write_mask"""
        # TODO: sanity check write mask
        self._add_fields_mode = False
        self._writable_fieldnames = tuple(name for name, _ in self.writable_field_items())

    def __getitem__(self, key):
        """Add the represent() logic to the dict-like access method"""
        if self._add_fields_mode:
            def represent(**kwargs):
                bits = kwargs['bits'].split(':')
                msb = int(bits[0])
                lsb = int(bits[1]) if len(bits) == 2 else msb
                field = RegisterField(name=key, msb=msb, lsb=lsb, **kwargs)
                self._fields[key] = field
                if "reset" in kwargs:
                    reset = int(kwargs['reset'], 0) << lsb

                    truncreset = reset & field.get_mask()
                    if truncreset != reset:
                        _regfile_warn_user(f"{key}: reset value 0x{reset >> lsb:x} "
                                           f"is truncated to 0x{truncreset >> lsb:x}.")  \
                                                   # pragma: nocover

                    self._reset |= truncreset
                    self.desired_value = self._reset
                    self.mirrored_value = self._reset

                return field

            return SyntasticSugarRepresent(represent)

        return super().__getitem__(key)

    def get_reset_values(self):
        """Get iterator object of the tuple (fieldname, resetvalue)."""
        return {fieldname: field.get_field(self._reset) for fieldname, field in self.writable_field_items()}

    def field(self, name):
        """ Get the field by name and add callback for UVM-like set() method of fields"""
        field = self._fields[name]
        if not hasattr(field, "set"):
            def setfunc(value):
                self.desired_value &= ~field.get_mask()
                self.desired_value |= self._fit_fieldvalue_for_write(field, value) << field.lsb

            setattr(field, "set", setfunc)

        return field

    def __getattr__(self, name):
        """Allow member access of fields - must have '_f' as suffix (<FIELDNAME>_f)."""
        if name[-2:] == '_f' and name[:-2] in self._fields:
            return self.field(name[:-2])

        raise AttributeError(f"Attribute {name} does not exist nor is a valid fieldname. "
                             f"Available fields: {list(self._fields.keys())}")

    def get_register_entry(self, value):
        """Return a new RegisterEntry (shallow copy)."""
        userattr = {}
        for attr in ('regfile', 'addr', 'write_mask', '_fields', '_reset'):
            userattr[attr] = getattr(self, attr)

        for attr in self._userattributes:
            userattr[attr] = getattr(self, attr)

        return RegisterEntry(mirrored_value=value, desired_value=value, **userattr)

    def read_entry(self):
        """Reads the value and returns a new RegisterEntry."""
        return self.get_register_entry(self._get_value())

    def set(self, value):
        """UVM-like - Set the desired value for this register."""
        self.desired_value = value

    def get(self):
        """UVM-like - Return thee desired value of the fields in the register."""
        return self.desired_value

    def get_mirrored_value(self):
        """UVM-like - Return the mirrored value of the fields in the register."""
        return self.mirrored_value

    def get_mirrored_dict(self):
        """UVM-like - Variation of get_mirrored_value() return a dict instead of an int"""
        return self.get_dict(self.mirrored_value)

    def get_mirrored_reg(self):
        """UVM-like - Variation of get_mirrored_value() return a reg instead of an int"""
        return self.get_register_entry(self.mirrored_value)

    def needs_update(self):
        """UVM-like - Returns True if any of the fields need updating"""
        return self.desired_value != self.mirrored_value

    def reset(self):
        """UVM-like - Reset the desired/mirrored value for this register."""
        self.desired_value = self._reset
        self.mirrored_value = self._reset

    def get_reset(self):
        """UVM-like - Get the specified reset value for this register."""
        return self._reset

    def write(self, value, mask=None):
        """UVM-like - Write the specified value in this register."""
        self.set_value(value, mask)

    def read(self):
        """UVM-like - Read the current value from this register."""
        return self.get_value()

    def update(self):
        """UVM-like - Updates the content of the register in the design
        to match the desired value."""
        self._set_value(self.desired_value, self.write_mask)

    def get_field_by_name(self, name):
        """UVM-like - Return the fields in this register."""
        return self.field(name)

    def get_offset(self):
        """UVM-like - Returns the offset of this register."""
        return self.addr

    def get_address(self):
        """UVM-like - Returns the base external physical address of this register"""
        return self.regfile.get_base_addr() + self.addr

    def write_update(self, values):
        """Wrapper function around set() fields defined by value[dict] and update()"""
        for field_name, field_value in values.items():
            self.field(field_name).set(field_value)
        self.update()


class RegfileEntry(RegisterEntry):
    def _get_value(self):
        value = self.regfile.read(self)
        if self.needs_update():
            _regfile_warn_user(f"Register {self.get_name()}: Desired value 0x{self.desired_value:x} "
                               f"has never been written via update() "
                               f" --> mirrored value is 0x{self.mirrored_value:x}.\n"
                               f"Reseting desired/mirrored value by readvalue 0x{value:x}")

        self.desired_value = value
        self.mirrored_value = value
        return value

    def _set_value(self, value, mask):
        super()._set_value(value, mask)
        self.regfile.write(self, value, mask)


class RegisterField:
    def __init__(self, **kwargs):
        self.name = kwargs.pop('name')
        self.msb = kwargs.pop('msb')
        self.lsb = kwargs.pop('lsb')

        for key, value in kwargs.items():
            self.__setattr__(key, value)

        self.__mask = (1 << (self.msb + 1)) - (1 << self.lsb)

    def get_field(self, intvalue):
        return (intvalue & self.__mask) >> self.lsb

    def get_mask(self):
        return self.__mask

    def __str__(self):
        return f"{self.name}"


def _regfile_warn_user(msg):
    fstacklevel = len(traceback.extract_stack()) + 1
    for stacktrace in traceback.extract_stack():
        if __file__ == stacktrace[0]:
            break
        fstacklevel -= 1

    warnings.warn(msg, UserWarning, stacklevel=fstacklevel)


class Regfile:
    def __init__(self, rfdev, base_addr=0x0):
        object.__setattr__(self, "_lock", False)
        self._dev = rfdev
        self.__value_mask = (1 << (8 * self._dev.n_word_bytes)) - 1
        self.__base_addr = base_addr
        self._entries = {}
        self.__add_entry_mode = False
        self._lock = True

    def __enter__(self):
        self.__add_entry_mode = True
        return self

    def __exit__(self, exception_type, exception_value, exception_traceback):
        self.__add_entry_mode = False

    def read(self, entry):
        return self._dev.read(self.get_base_addr(), entry)

    def write(self, entry, value, mask):
        regvalue = value & self.__value_mask
        if value != regvalue:
            _regfile_warn_user(f"Value 0x{value:x} is too large to fit into "
                               f"the specified word size ({self._dev.n_word_bytes}), "
                               f"truncated to 0x{regvalue:x} / 0x{self.__value_mask:x}.")
        self._dev.write(self.get_base_addr(), entry, value, mask)

    def get_base_addr(self):
        return self.__base_addr

    def get_rfdev(self):
        return self._dev

    def set_rfdev(self, dev):
        self._dev = dev

    def __iter__(self):
        return iter(self._entries.values())

    def items(self):
        return self._entries.items()

    def keys(self):
        return self._entries.keys()

    def values(self):
        return self._entries.values()

    def __getitem__(self, key):
        if key not in self._entries:
            if self.__add_entry_mode:
                def represent(**kwargs):
                    kwargs.setdefault('name', key)
                    self._entries[key] = RegfileEntry(regfile=self, **kwargs)
                    return self._entries[key]
                return SyntasticSugarRepresent(represent)
            raise KeyError(f"Regfile has no entry named '{key}'.")
        return self._entries[key]

    def __setattr__(self, name, value):
        if self._lock is True and name not in self.__dict__:
            raise AttributeError(f"Unable to allocate attribute {name} - Instance is locked.")

        super().__setattr__(name, value)

    def __getattr__(self, name):
        if name[-2:] == '_r' and name[:-2] in self._entries:
            return self._entries[name[:-2]]
        raise AttributeError(f"Attribute {name} does not exist")

    def __setitem__(self, key, value):
        if key not in self._entries:
            raise KeyError(f"Regfile has no entry named '{key}'.")

        self._entries[key].write(value)

    def reset_all(self):
        for regs in self._entries.values():
            regs.reset()


class SyntasticSugarRepresent:
    # pylint: disable=too-few-public-methods
    __slots__ = ("represent",)

    def __init__(self, represent):
        self.represent = represent


class RegfileMemAccess:
    def __init__(self, rfdev, base_addr, **kwargs):
        self._dev = rfdev
        if kwargs['size']:
            self.index_range = kwargs['size'] // self._dev.n_word_bytes
            self.__check_idx_func = self.__check_idx
        else:
            self.__check_idx_func = lambda self, index: None
        self.__base_addr = base_addr

    def __check_idx(self, index):
        if index >= self.index_range:
            raise IndexError(f"Index {index} is out of bounds")

    def __getitem__(self, index):
        self.__check_idx_func(index)
        return self._dev.rfdev_read(self.__base_addr + self._dev.n_word_bytes * index)

    def __setitem__(self, index, value):
        self.__check_idx_func(index)
        self._dev.rfdev_write(
            self.__base_addr + self._dev.n_word_bytes * index, value, -1, -1)

    def get_rfdev(self):
        return self._dev

    def set_rfdev(self, dev):
        self._dev = dev

    def get_base_addr(self):
        return self.__base_addr

    def read_image(self, addr, size):
        image = size * [0]
        self._dev.readwrite_block(self.__base_addr + addr, image, False)
        return image

    def write_image(self, addr, image):
        self._dev.readwrite_block(self.__base_addr + addr, image, True)
