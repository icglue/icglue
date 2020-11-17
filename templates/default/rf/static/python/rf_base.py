# Copyright (C) 2020 Heiner Bauer
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

import logging


class base_registerfile(object):
    def __init__(self, addr, read_function, write_function, log_level=logging.DEBUG):
        self.base_addr = addr
        self.read_func = read_function
        self.write_func = write_function

        # configure logging
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.DEBUG)
        ch = logging.StreamHandler()
        ch.setLevel(log_level)
        formatter = logging.Formatter('%(name)s - %(levelname)s - %(message)s')
        ch.setFormatter(formatter)
        self.logger.addHandler(ch)

    def read_word(self, addr):
        addr  = self.base_addr | addr
        value = self.read_function(addr)
        #self.logger.debug("RD addr 0x%08X = 0x%08X" % (addr, value))
        return value

    def write_word(self, addr, value):
        addr = self.base_addr | addr
        #self.logger.debug("WR addr 0x%08X = 0x%08X" % (addr, value))
        self.write_function(addr, value)


class base_word(object):
    """ Methods for working on register words, implemented without side effects (i.e. using read_word() or write_word())."""

    def __init__(self):
        self.read_word = None
        self.write_word = None

    def get_mask(self, offset, width):
        mask = ((1 << width) - 1) << offset
        return mask

    def clear_bits(self, old_word, offset, width):
        word = old_word & (~self.get_mask(offset, width))
        return word

    def get_bits(self, word, offset, width):
        bits = word & self.get_mask(offset, width)
        bits = bits >> offset
        return bits

    def set_bits(self, old_word, val, offset, width):
        word  = self.clear_bits(old_word, offset, width)
        word |= ((self.get_mask(0, width) & val) << offset)
        return word
