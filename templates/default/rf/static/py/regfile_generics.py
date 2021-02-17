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
import logging
import random
import struct
import sys
import traceback
import warnings

__version__ = "0.0.1"


def regfile_dev_debug_getbits(interactive, bits, default_value, promptprefix):
    if not interactive:
        print(f"{promptprefix} value: 0x{default_value:x}")
        return default_value
    else:
        lasttrace = None
        for t in traceback.extract_stack():
            if __file__ == t[0]:
                if lasttrace:
                    print(f"{lasttrace[0]}:{lasttrace[1]}: {lasttrace[3]}", file=sys.stderr)
                break
            lasttrace = t

        while True:
            v = input(f"{promptprefix} value(0x{default_value:x}): ")
            if not v:
                return default_value
            try:
                return int(v, 0)
            except ValueError:
                print(f"Invalid value {v}.")


def _regfile_warn_user(msg):
    fstacklevel = len(traceback.extract_stack()) + 1
    for t in traceback.extract_stack():
        if __file__ == t[0]:
            break
        fstacklevel -= 1

    warnings.warn(msg, UserWarning, stacklevel=fstacklevel)


class regfile_dev(metaclass=abc.ABCMeta):
    def __init__(self, **kwargs):
        super().__init__()
        kwargs.setdefault('bytes_per_word', 4)
        kwargs.setdefault('logger', logging.getLogger(__name__))
        kwargs.setdefault('prefix', '')
        self._prefix = kwargs['prefix']
        self.n_word_bytes = kwargs['bytes_per_word']
        self.logger = kwargs['logger']

    def readwrite_block(self, addr, value, write, bsel=0b1111):
        if len(addr) != len(value):
            raise Exception(f"Adress size ({len(addr)}) / value size ({len(value)}) mismatch.")

        if write:
            mask = (1 << (8 * self.n_word_bytes)) - 1
            write_mask = mask
            for a, v in zip(addr, value):
                self.write(a, v, mask, write_mask)
        else:
            for i in range(len(addr)):
                value[i] = self.read(addr[i])

    @abc.abstractmethod
    def rfdev_read(self, addr):
        pass

    def read(self, addr):
        value = self.rfdev_read(addr)
        self.logger.debug("%sRegfileDevice read from address 0x%x = 0x%x", self._prefix, addr, value)
        return value

    @abc.abstractmethod
    def rfdev_write(self, addr, value, mask, write_mask):
        pass

    def write(self, addr, value, mask, write_mask):
        self.logger.debug("%RegfileDevice initiate write at address 0x%x -- {value: 0x%x, mask 0x%x, write_mask: 0x%x}", self._prefix, addr, value, mask, write_mask)
        self.rfdev_write(addr, value, mask, write_mask)


class regfile_dev_simple(regfile_dev):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    @abc.abstractmethod
    def rfdev_write_simple(self, addr, value):
        pass

    def rfdev_write(self, addr, value, mask, write_mask):
        keep_mask = ~mask & write_mask

        if keep_mask == 0:
            self.rfdev_write_simple(addr, value)
        else:
            # read, modify, write
            rmw_value = self.read(addr)

            rmw_value &= ~mask
            rmw_value |= (value & mask)

            self.rfdev_write_simple(addr, rmw_value)


class regfile_dev_simple_debug(regfile_dev_simple):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.mem = {}
        self.write_count = 0
        self.read_count = 0
        kwargs.setdefault('interactive', False)
        self.__interactive = kwargs['interactive']

    def rfdev_read(self, addr):
        if addr not in self.mem:
            value = random.getrandbits(8 * self.n_word_bytes)
            print("Generating random regfile value {value}.")
        else:
            value = self.mem[addr]

        value = regfile_dev_debug_getbits(self.__interactive, 8 * self.n_word_bytes, value, f"{self._prefix}REGFILE-READING from addr 0x{addr:x}")
        self.mem[addr] = value

        self.read_count += 1
        return value

    def rfdev_write_simple(self, addr, value):
        print(f"{self._prefix}REGFILE-WRITING to addr 0x{addr:x} value 0x{value:x}")
        self.mem[addr] = value
        self.write_count += 1


class regfile_dev_subword(regfile_dev):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    @abc.abstractmethod
    def rfdev_write_subword(self, addr, value, size):
        pass

    def rfdev_write(self, addr, value, mask, write_mask):
        # register bits that must not be changed
        keep_mask = ~mask & write_mask

        # initial subword mask: full word size - all bits to 1
        subword_mask = (1 << (8 * self.n_word_bytes)) - 1

        # go from full word to shorter subwords (e.g. 32, 16, 8 bits --> 4, 2, 1 bytes)
        n_subword_bytes = self.n_word_bytes
        while n_subword_bytes:
            # iterate over subwords of current size (e.g. 32bits: 0; 16bits: 0, 1; 8bits: 0, 1, 2, 3)
            for i in range(self.n_word_bytes // n_subword_bytes):
                # shift wordmask to current position
                i_word_mask = subword_mask << (i * n_subword_bytes * 8)

                # no keep bit would be overwritten? && all write bits are covered?
                if ((keep_mask & i_word_mask) == 0) and ((mask & (~i_word_mask)) == 0):
                    subword_offset = i * n_subword_bytes

                    # call virtual method
                    self.logger.debug("RegfileDevice: Subwrite address 0x%x -- {value: 0x%x, n_subword_bytes: 0x%x}",
                                      addr + subword_offset, value, n_subword_bytes)
                    self.rfdev_write_subword(addr + subword_offset, value, n_subword_bytes)
                    # we are done here ...
                    return

            # reduce subword bytes - next half
            n_subword_bytes //= 2
            # reduce subword mask - throw away the other half
            subword_mask >>= n_subword_bytes * 8

        # no success?  - full read-modify-write
        rmw_value = self.read(addr)

        rmw_value &= ~mask
        rmw_value |= (value & mask)

        # call virtual method
        self.rfdev_write_subword(addr, rmw_value, self.n_word_bytes)


class regfile_dev_subword_debug(regfile_dev_subword):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        kwargs.setdefault('interactive', False)
        self.__interactive = kwargs['interactive']
        self.mem = {}
        self.write_count = 0
        self.read_count = 0

    def getvalue(self, addr):
        word = []
        for i in range(self.n_word_bytes):
            if (addr + i) not in self.mem:
                v = random.getrandbits(8)
                print("Generating random regfile value {value}.")
                self.mem[addr + i] = v

            v = self.mem[addr + i]
            word.append(v)

        return int.from_bytes(struct.pack(f"{self.n_word_bytes}B", *word), 'little')

    def rfdev_read(self, addr):
        value = self.getvalue(addr)

        value = regfile_dev_debug_getbits(self.__interactive, 8 * self.n_word_bytes, value, f"{self._prefix}REGFILE-READING from addr 0x{addr:x}")
        self.mem[addr] = value

        self.read_count += 1
        return value

    def rfdev_write_subword(self, addr, value, size):
        print("{self._prefix}REGFILE-WRITING to addr 0x{addr:x} value 0x{value:x} size=0x{size:x}")

        b = value.to_bytes(self.n_word_bytes, 'little')
        for i in range(size):
            self.mem[addr + i] = b[i]
        self.write_count += 1


class regfile_mem_access:
    def __init__(self, rfdev, base_addr):
        self._dev = rfdev
        self.__base_addr = base_addr

    def __getitem__(self, index):
        return self._dev.read(self.__base_addr + self._dev.n_word_bytes * index)

    def __setitem__(self, index, value):
        self._dev.write(self.__base_addr + self._dev.n_word_bytes * index, value, -1, -1)

    def get_base_addr(self):
        return self.__base_addr

    def read_image(self, v):
        a = range(self.__base_addr, self.__base_addr + self._dev.n_word_bytes * len(v), self._dev.n_word_bytes)
        self._dev.readwrite_block(a, v, False)

    def write_image(self, v):
        a = range(self.__base_addr, self.__base_addr + self._dev.n_word_bytes * len(v), self._dev.n_word_bytes)
        self._dev.readwrite_block(a, v, True)


class regfile_create_entry:
    def __init__(self, rf, name):
        self.rf = rf
        self.name = name

    def represent(self, **kwargs):
        kwargs.setdefault('regname', self.name)
        e = regfile_entry(self.rf, **kwargs)
        self.rf._entries[self.name] = e
        return e


class regfile:
    _print_deprecation_entry_attr = True

    @staticmethod
    def _deprecation_entry_attr():
        if regfile._print_deprecation_entry_attr:
            warnings.warn("regfile entries as attribute are deprecated - use item operator[] instead.", DeprecationWarning, stacklevel=3)
            regfile._print_deprecation_entry_attr = False

    def __init__(self, rfdev, base_addr):
        super().__setattr__("_lock", False)
        self._dev = rfdev
        self.__value_mask = (1 << (8 * self._dev.n_word_bytes)) - 1
        self.__base_addr = base_addr
        self._entries = {}
        self.__add_entry_mode = False
        self._lock = True

    def __enter__(self):
        self.__add_entry_mode = True
        return self

    def __exit__(self, exception_type, exception_value, traceback):
        self.__add_entry_mode = False

    def read(self, addr):
        return self._dev.read(self.__base_addr + addr)

    def write(self, addr, value, mask, write_mask):
        regvalue = value & self.__value_mask
        if regvalue != value:
            _regfile_warn_user(f"Value 0x{value:x} is to large to fit into the specified word size ({self._dev.n_word_bytes}), truncated to 0x{regvalue:x} / 0x{self.__value_mask:x}")
        self._dev.write(self.__base_addr + addr, regvalue, mask, write_mask)

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
        if self.__add_entry_mode:
            return regfile_create_entry(self, key)

        if key not in self._entries:
            raise Exception(f"Regfile has no entry named '{key}'.")

        return self._entries[key]

    def __getattr__(self, name):
        if name in self.__dict__:
            return super().__getattr__(name)
        elif name in self._entries:
            type(self)._deprecation_entry_attr()
            return self[name]
        else:
            raise AttributeError(f"Attribute {name} does not exist")

    def __setitem__(self, key, value):
        if key not in self._entries:
            raise Exception(f"Regfile has no entry named'{key}'.")

        self._entries[key].write(value)

    def __setattr__(self, name, value):

        if self._lock and name not in self.__dict__:
            type(self)._deprecation_entry_attr()
            self[name] = value
            return

        super().__setattr__(name, value)


class register_entry_create_field:
    def __init__(self, entry, name):
        self.entry = entry
        self.name = name

    def represent(self, **kwargs):
        bits = kwargs['bits'].split(':')
        msb = int(bits[0])
        lsb = int(bits[1]) if (len(bits) == 2) else msb
        field = register_field(self.name, msb, lsb, **kwargs)
        self.entry._fields[self.name] = field
        return field


class register_entry_abstract(metaclass=abc.ABCMeta):
    _print_deprecation_field_attr = True

    def __init__(self, **kwargs):
        super().__setattr__("_lock", False)
        if 'addr' not in kwargs:
            raise Exception("Regfile entry needs an 'addr' value.")

        self._addr = int(kwargs['addr'])
        self._write_mask = int(kwargs.setdefault('write_mask', -1))
        self._fields = {}
        for k, v in kwargs.items():
            if k not in ['addr', 'write_mask']:
                self.__setattr__(k, v)

        self.__add_fields_mode = False
        self._lock = True

    def __enter__(self):
        self.__add_fields_mode = True
        return self

    def __exit__(self, exception_type, exception_value, traceback):
        self.__add_fields_mode = False

    @staticmethod
    def _deprecation_field_attr():
        if register_entry_abstract._print_deprecation_field_attr:
            warnings.warn("register-fields as attribute are deprecated - use item operator[] instead.", DeprecationWarning, stacklevel=3)
            register_entry_abstract._print_deprecation_field_attr = False

    @abc.abstractmethod
    def _get_value(self):
        pass

    @abc.abstractmethod
    def _set_value(self, value, mask):
        pass

    def get_addr(self):
        return self._addr

    def get_write_mask(self):
        return self._write_mask

    def __iter__(self):
        return iter(self._fields.values())

    def items(self):
        return self._fields.items()

    def keys(self):
        return self._fields.keys()

    def values(self):
        return self._fields.values()

    def field(self, name):
        return self._fields[name]

    def get_field_names(self):
        return self.keys()

    def __getitem__(self, key):
        if self.__add_fields_mode:
            return register_entry_create_field(self, key)

        if key not in self._fields:
            raise Exception(f"Field {key} does not exist. Available fields: {list(self._fields.keys())}")

        return self._fields[key].get_field(self._get_value())

    def __getattr__(self, name):
        if name in self.__dict__:
            super().__getattr__(name)
        elif name in self._fields:
            type(self)._deprecation_field_attr()
            return self[name]
        else:
            raise AttributeError(f"Attribute {name} does not exist nor is a valid fieldname. Available fields: {list(self._fields.keys())}")

    def __setitem__(self, key, value):
        if key not in self._fields:
            raise Exception(f"Field {key} does not exist. Available fields: {list(self.get_field_names())}")

        (wval, mask) = self._fields[key].get_int_mask(value)

        if mask & self._write_mask != mask:
            _regfile_warn_user(f"Writing read-only field {key} (value: 0x{value:08x} -- mask: 0x{mask:08x} write_mask: 0x{self._write_mask:08x})")

        self._set_value(wval, mask)

    def __setattr__(self, name, value):
        if self._lock and name not in self.__dict__:
            type(self)._deprecation_field_attr()
            self[name] = value
            return

        super().__setattr__(name, value)

    def get_dict(self, int_value=None):
        if int_value is None:
            int_value = self._get_value()
        d = {}
        for n, f in self.items():
            d[n] = f.get_field(int_value)

        return d

    def __str__(self):
        int_value = self._get_value()
        s = []
        for n, f in self.items():
            s.append(f"'{n}': 0x{f.get_field(int_value):x}")
        return f"Register {self.regname}: {{{', '.join(s)}}} = 0x{int_value:x}"

    def get_value(self):
        return self._get_value()

    def set_value(self, value, mask=None):
        if mask is None:
            mask = self._write_mask

        if isinstance(value, int):
            self._set_value(value, mask)
        elif isinstance(value, dict):
            e = register_entry(addr=self._addr, write_mask=self._write_mask, _fields=self._fields)
            for k, v in value.items():
                e[k] = v

            self._set_value(e.get_value(), self._write_mask)
        elif isinstance(value, register_entry):
            value = value.get_dict()
            e = register_entry(addr=self._addr, _fields=self._fields)
            for k, v in value.items():
                e[k] = v

            self._set_value(e.get_value(), self._write_mask)
        else:
            raise Exception(f"Unable to assign type {type(value)} -- {str(value)}.")

    def __int__(self):
        return self.get_value()

    def __eq__(self, other):
        if isinstance(other, int):
            return (self.get_value() == other)
        super().__eq__(other)

    def __lt__(self, other):
        if isinstance(other, int):
            return (self.get_value() < other)
        super().__lt__(other)

    def __le__(self, other):
        if isinstance(other, int):
            return (self.get_value() <= other)
        super().__le__(other)

    def __gt__(self, other):
        if isinstance(other, int):
            return (self.get_value() > other)
        super().__gt__(other)

    def __ge__(self, other):
        if isinstance(other, int):
            return (self.get_value() >= other)
        super().__ge__(other)


class register_entry(register_entry_abstract):
    def __init__(self, **kwargs):
        entry_args = {k: v for k, v in kwargs.items() if k not in ['value']}
        super().__init__(**entry_args)
        self._lock = False
        self.__value = int(kwargs.setdefault('value', 0))
        self._lock = True

    def _get_value(self):
        return self.__value

    def _set_value(self, value, mask):
        self.__value = (self.__value & ~mask) | (value & mask)


class regfile_entry(register_entry_abstract):
    def __init__(self, regfile, **kwargs):
        super().__init__(**kwargs)
        self._lock = False
        self.__regfile = regfile
        self._lock = True

    def _get_value(self):
        return self.__regfile.read(self._addr)

    def _set_value(self, value, mask):
        self.__regfile.write(self._addr, value, mask, self._write_mask)

    def read(self):
        return self.get_value()

    def write(self, value, mask=None):
        self.set_value(value, mask)

    def read_entry(self):
        new_entry = register_entry(addr=self.get_addr(), write_mask=self._write_mask, value=self.read(), regname=self.regname)
        new_entry._fields = self._fields

        return new_entry


class register_field:
    def __init__(self, name, msb, lsb, **kwargs):
        self.name = name
        self.msb = msb
        self.lsb = lsb
        for k, v in kwargs.items():
            self.__setattr__(k, v)

        self.__mask = (1 << (self.msb + 1)) - (1 << self.lsb)

    def get_field(self, intvalue):
        return (intvalue & self.__mask) >> self.lsb

    def get_int_mask(self, field_value):
        wval = field_value << self.lsb

        if (wval & (~self.__mask)) != 0:
            _regfile_warn_user(f"{self.name}: value 0x{field_value:x} is truncated (mask: 0x{self.__mask >> self.lsb:x})")

        wval &= self.__mask
        return (wval, self.__mask)

    def __str__(self):
        return f"{self.name}"
