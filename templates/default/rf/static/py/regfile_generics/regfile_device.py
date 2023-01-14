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
Generic Device on which a regfile can operate
"""

__version__ = "0.0.3"

import logging
import os
import random
import struct
import sys
import traceback

# pylint: disable=missing-class-docstring, missing-function-docstring


class RegfileDev():
    def __init__(self, **kwargs):
        super().__init__()
        kwargs.setdefault('bytes_per_word', 4)
        kwargs.setdefault('logger', logging.getLogger(__name__))
        kwargs.setdefault('prefix', '')
        self._prefix = kwargs['prefix']
        self.n_word_bytes = kwargs['bytes_per_word']
        self.logger = kwargs['logger']

        self.callback = kwargs.pop('callback', {})
        if not isinstance(self.callback, dict):
            raise TypeError("Argument 'callback' has to dict with name, callback function.")

        if not set(self.callback) <= self.allowed_callbacks():
            raise AttributeError(f"Only {self.allowed_callbacks} are allowed as callback functions.")

        for func in self.allowed_callbacks() - set(self.callback):
            if not hasattr(self, func):
                raise TypeError(f"Function {func} has to be implemented or passed as callback function.")

    def allowed_callbacks(self):
        return {'rfdev_read', 'rfdev_write'}

    def readwrite_block(self, start_addr, values, write):
        if not write:
            for i in range(len(values)):  # pylint: disable=consider-using-enumerate
                # Modifications are be done by reference
                values[i] = self.rfdev_read(start_addr + i * self.n_word_bytes)
        else:
            mask = (1 << (8 * self.n_word_bytes)) - 1
            write_mask = mask
            for i, value in enumerate(values):
                self.rfdev_write(start_addr + i * self.n_word_bytes, value, mask, write_mask)

    def rfdev_read(self, addr):
        """Read method could be overridden when deriving a new RegfileDev"""
        return self.callback['rfdev_read'](addr)

    def read(self, baseaddr, entry):
        value = self.rfdev_read(baseaddr + entry.addr)
        self.logger.debug("%sRegfileDevice reading entry %s from address "
                          "0x%x = 0x%x", self._prefix, entry.name, entry.addr, value)
        return value

    def rfdev_write(self, addr, value, mask, write_mask):
        """Read method could be overridden when deriving a new RegfileDev"""
        self.callback['rfdev_write'](addr, value, mask, write_mask)

    def write(self, baseaddr, entry, value, mask):
        addr = baseaddr + entry.addr

        self.logger.debug("%sRegfileDevice initiate write of entry %s at address "
                          "0x%x -- {value: 0x%x, mask 0x%x, write_mask: 0x%x}",
                          self._prefix, entry.name, entry.addr, value, mask, entry.write_mask)
        self.rfdev_write(addr, value, mask, entry.write_mask)


class RegfileDevSimple(RegfileDev):
    def rfdev_write(self, addr, value, mask, write_mask):
        keep_mask = ~mask & write_mask

        if keep_mask == 0:
            self.rfdev_write_simple(addr, value)
        else:
            # read, modify, write
            rmw_value = self.rfdev_read(addr)

            rmw_value &= ~mask
            rmw_value |= (value & mask)

            self.rfdev_write_simple(addr, rmw_value)

    def allowed_callbacks(self):
        return {'rfdev_read', 'rfdev_write_simple'}

    def rfdev_write_simple(self, addr, value):
        self.callback['rfdev_write_simple'](addr, value)


def regfile_dev_debug_getbits(interactive, default_value, promptprefix):
    if not interactive:
        print(f"{promptprefix} value: 0x{default_value:x}")
        return default_value

    lasttrace = []
    regfile_generics_package_path = os.path.dirname(__file__)

    for stacktrace in traceback.extract_stack():
        if stacktrace[0].startswith(regfile_generics_package_path):
            if lasttrace:
                print(f"{lasttrace[0]}:{lasttrace[1]}: {lasttrace[3]}", file=sys.stderr)
            break
        lasttrace = stacktrace

    while True:
        value = input(f"{promptprefix} value(0x{default_value:x}): ")
        if not value:
            return default_value
        try:
            return int(value, 0)
        except ValueError:
            print(f"Invalid value {value}.")


class RegfileDevSimpleDebug(RegfileDevSimple):
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
            print(f"Generating random regfile value {value}.")
        else:
            value = self.mem[addr]

        value = regfile_dev_debug_getbits(self.__interactive, value,
                                          f"{self._prefix}REGFILE-READING from addr 0x{addr:x}")
        self.mem[addr] = value

        self.read_count += 1
        return value

    def rfdev_write_simple(self, addr, value):
        print(f"{self._prefix}REGFILE-WRITING to addr 0x{addr:x} value 0x{value:x}")
        self.mem[addr] = value
        self.write_count += 1

    def getvalue(self, addr):
        if addr not in self.mem:
            value = random.getrandbits(8 * self.n_word_bytes)
            self.mem[addr] = value

        return self.mem[addr]


class RegfileDevSubword(RegfileDev):
    def rfdev_write(self, addr, value, mask, write_mask):
        # register bits that must not be changed
        keep_mask = ~mask & write_mask

        # initial subword mask: full word size - all bits to 1
        subword_mask = (1 << (8 * self.n_word_bytes)) - 1

        # go from full word to shorter subwords (e.g. 32, 16, 8 bits --> 4, 2, 1 bytes)
        n_subword_bytes = self.n_word_bytes
        while n_subword_bytes:
            # iterate subwords of current size (e.g. 32bits: 0; 16bits: 0, 1; 8bits: 0, 1, 2, 3)
            for i in range(self.n_word_bytes // n_subword_bytes):
                # shift wordmask to current position
                i_word_mask = subword_mask << (i * n_subword_bytes * 8)

                # no keep bit would be overwritten? && all write bits are covered?
                if ((keep_mask & i_word_mask) == 0) and ((mask & (~i_word_mask)) == 0):
                    subword_offset = i * n_subword_bytes

                    # call virtual method
                    self.logger.debug("RegfileDevice: Subwrite address 0x%x -- "
                                      "{value: 0x%x, n_subword_bytes: 0x%x}",
                                      addr + subword_offset, value, n_subword_bytes)
                    self.rfdev_write_subword(addr + subword_offset, value, n_subword_bytes)
                    # we are done here ...
                    return

            # reduce subword bytes - next half
            n_subword_bytes //= 2
            # reduce subword mask - throw away the other half
            subword_mask >>= n_subword_bytes * 8

        # no success?  - full read-modify-write
        rmw_value = self.rfdev_read(addr)

        rmw_value &= ~mask
        rmw_value |= (value & mask)

        # call virtual method
        self.rfdev_write_subword(addr, rmw_value, self.n_word_bytes)

    def allowed_callbacks(self):
        return {'rfdev_read', 'rfdev_write_subword'}

    def rfdev_write_subword(self, addr, value, size):
        self.callback['rfdev_write_subword'](addr, value, size)


class RegfileDevSubwordDebug(RegfileDevSubword):
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
                byte_value = random.getrandbits(8)
                print(f"Generating random regfile value {byte_value}.")
                self.mem[addr + i] = byte_value

            byte_value = self.mem[addr + i]
            word.append(byte_value)

        return int.from_bytes(struct.pack(f"{self.n_word_bytes}B", *word), 'little')

    def rfdev_read(self, addr):
        value = self.getvalue(addr)

        value = regfile_dev_debug_getbits(self.__interactive, value,
                                          f"{self._prefix}REGFILE-READING from addr 0x{addr:x}")
        for i in range(self.n_word_bytes):
            self.mem[addr + i] = (value >> (8 * i)) & 0xff

        self.read_count += 1
        return value

    def rfdev_write_subword(self, addr, value, size):
        print(f"{self._prefix}REGFILE-WRITING to addr 0x{addr:x} value 0x{value:x} size=0x{size:x}")

        byte_values = value.to_bytes(self.n_word_bytes, 'little')
        for i in range(size):
            self.mem[addr + i] = byte_values[i + addr & 0b11]
        self.write_count += 1


class StringCmdRegfileDevSimple(RegfileDevSimple):
    '''Forwards regfile operations to a function call with string command,
       to do the regfile operations.

        Read:
            r<NUMBITS> <address>
                e.g. r32 0x1C

        Write:
            w<NUMBITS> <address> <value>
                e.g. w32 0x80 0xF9852A
     '''

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.execute = kwargs['execute']

    def rfdev_read(self, addr):
        return int(self.execute(f"r{8*self.n_word_bytes} 0x{addr:x}"), 0)

    def rfdev_write_simple(self, addr, value):
        self.execute(f"w{8*self.n_word_bytes} 0x{addr:x} 0x{value:x}")


class StringCmdRegfileDevSubword(RegfileDevSubword):
    '''Forwards regfile operations to a function call with string command,
       to do the regfile operations.

        Read:
            r<NUMBITS> <address>
                e.g. r32 0x1C

        Write:
            w<NUMBITS> <address> <value> [bsel]
                e.g. w32 0x80 0xF9852A
                     w32 0x80 0xF9852A 0x1
     '''

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.execute = kwargs['execute']

    def rfdev_read(self, addr):
        return int(self.execute(f"r{8*self.n_word_bytes} 0x{addr:x}"), 0)

    def rfdev_write_subword(self, addr, value, size):
        subword_addrbits = self.n_word_bytes.bit_length() - 1
        bsel = ((1 << size) - 1) << (addr & subword_addrbits)
        addr_aligned = addr & ~subword_addrbits

        self.execute(f"w{8*self.n_word_bytes} 0x{addr_aligned:x} 0x{value:x} 0x{bsel:x}")
