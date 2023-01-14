#!/usr/bin/env python

import pytest

from regfile_generics import Regfile
from regfile_generics import RegfileDevSimpleDebug, RegfileDevSubwordDebug, RegfileMemAccess


# Specific registerfile description

class submod_regfile(Regfile):
    def __init__(self, rfdev, base_addr):
        super().__init__(rfdev, base_addr)

        with self as r:

            with r['reg0'].represent(addr=0x0000, write_mask=0x0000001F) as e:
                e['cfg'].represent(
                    bits="4:0",
                    access="RW",
                    reset="0x0",
                    desc="Configure component")
                e['status'].represent(
                    bits="31:16", access="R", desc="Component status")

            with r['reg1_low'].represent(addr=0x0004, write_mask=0xFFFFFFFF) as e:
                e['cfg'].represent(
                    bits="31:0",
                    access="RW",
                    reset="0x0",
                    desc="Configure submod part 0")

            with r['reg1_high'].represent(addr=0x0008, write_mask=0x000301FF) as e:
                e['cfg'].represent(
                    bits="7:0",
                    access="RW",
                    reset="0x0",
                    desc="Configure submod part 1")
                e['cfg_trigger'].represent(
                    bits="8", access="RWT", reset="0b0", desc="trigger config update")
                e['cfg_trigger_mode'].represent(
                    bits="17:16", access="RWT", reset="0b0", desc="trigger config update")

            with r['reg2'].represent(addr=0x00C0, write_mask=0x000001F0) as e:
                e['config'].represent(
                    bits="8:4",
                    access="RW",
                    reset="0x0",
                    desc="Configure component")
                e['status'].represent(
                    bits="31:16", access="R", desc="Component status")

            with r['reg_addr40'].represent(addr=0x0040, write_mask=0x0000001F) as e:
                e['start'].represent(
                    bits="0",
                    access="RW",
                    reset="0b0",
                    desc="start's the module")
                e['enable_feature0'].represent(
                    bits="1", access="RW", reset="0b1", desc="enables feature0")
                e['enable_feature1'].represent(
                    bits="2", access="RW", reset="0b0", desc="enables feature1")
                e['enable_feature2'].represent(
                    bits="3", access="RW", reset="0b1", desc="enables feature2")
                e['enable_feature3'].represent(
                    bits="4", access="RW", reset="0b0", desc="enables feature3")


"""
regfile devices could inherit from regfile_dev (-> implement rfdev_write // rfdev_read)
    or its highlevel classes (which are simplifing implementation as:
    - regfile_dev_simple  -> implementation of rfdev_write_simple(self, addr, value) // rfdev_read(self, addr)
    - regfile_dev_subword -> implementation of rfdev_write_subword(self, addr, value, size) // rfdev_read(self, addr) [note that addr is unaligned(!) to byteper_word]
"""


@pytest.fixture(scope="session")
def sessionsubwordregfile():
    regfile = submod_regfile(RegfileDevSubwordDebug(), 0xF000_0000)
    return regfile, regfile.get_rfdev()

@pytest.fixture(scope="session")
def sessionsimpleregfile():
    regfile = submod_regfile(RegfileDevSimpleDebug(), 0xF000_0000)
    return regfile, regfile.get_rfdev()

@pytest.fixture(scope="session")
def sessionmemregfile():
    regfile = RegfileMemAccess(RegfileDevSubwordDebug(), 0xA000_0000, size=1024)
    return regfile, regfile.get_rfdev()
