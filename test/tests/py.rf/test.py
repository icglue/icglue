#!/usr/bin/env python3

import logging
from regfile_access import regfiles

from regfile_access.regfile_generics import regfile_dev_subword_debug


logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s: %(message)s",
    handlers=[
        logging.FileHandler("test.log", mode='w'),
        logging.StreamHandler()
    ]
)

"""
regfile devices could inherit from regfile_dev (-> implement rfdev_write // rfdev_read)
    or its highlevel classes (which are simplifing implementation as:
    - regfile_dev_simple  -> implementation of rfdev_write_simple(self, addr, value) // rfdev_read(self, addr)
    - regfile_dev_subword -> implementation of rfdev_write_subword(self, addr, value, size) // rfdev_read(self, addr) [keep in mind that addr is unaligned(!) to bytes_per_word]
"""

rf_dev = regfile_dev_subword_debug()

# create register files - access through rf_dev
rf = regfiles(rf_dev)

"""
Writing Values:
    1. Dictionary assignment
        rf.submod['entry_name1_high'] = {'s_cfg': 0x0ff, 's_cfg_trigger': 0x1}
    2. Subfield write (may issue a Read-Modify-Write)
        rf.submod['entry_name1_high']['s_cfg'] = 0xa5
    3. Raw value assignment (base function used by the 2 methods above)
        rf.submod['entry_name1_high'].set_value(0x1ff)
"""

# dict assign
rf.submod['entry_name1_high'] = {'s_cfg': 0x0ff, 's_cfg_trigger': 0x1, 's_cfg_trigger_mode': 0x0}

if 0xf0000020 not in rf_dev.mem:
    print("FAILED Write -- memdump:")
    for (addr, val) in rf_dev.mem.items():
        print(f"0x{addr:x}: 0x{val:x}")
    raise Exception("Error write failed.")
else:
    print("PASSED: sanity memory write.")

if rf_dev.getvalue(0xf0000020) != 0x1ff:
    raise Exception(f"Wrong value has been written -- 0x{rf_dev.getvalue(0xf0000020):x}.")
else:
    print(f"PASSED readback (0x{rf_dev.getvalue(0xf0000020):x}).")

# subfield write
read_count = rf_dev.read_count
rf.submod['entry_name1_high']['s_cfg'] = 0xa5
if rf_dev.getvalue(0xf0000020) != 0x1a5:
    raise Exception(f"Wrong value has been written -- 0x{rf_dev.getvalue(0xf0000020):x}.")
else:
    print(f"PASSED readback (0x{rf_dev.getvalue(0xf0000020):x})")

if rf_dev.read_count != read_count:
    raise Exception("Subword read failed -- Read-Modify-Write has been issued.")
else:
    print("PASSED: read_counter test on Read-Modify-Write")

rf.submod['entry_name1_high']['s_cfg_trigger_mode'] = 0x3

if rf_dev.getvalue(0xf0000020) != 0x7a5:
    raise Exception(f"Wrong value has been written -- 0x{rf_dev.getvalue(0xf0000020):x}.")
else:
    print("PASSED: aligned subfield write")

if rf_dev.read_count != read_count + 1:
    raise Exception("Subword read failed -- Read counter erronous.")
else:
    print("PASSED: aligned subfield write through byte select")

for e in ['entry_name0', 'entry_name1_low']:
    rf.submod[e]['s_cfg'] = 0xf
if rf_dev.getvalue(0xf0000000) != 0x00f:
    raise Exception(f"Wrong value has been written -- 0x{rf_dev.getvalue(0xf0000000):x}.")
if rf_dev.getvalue(0xf0000004) != 0x00f:
    raise Exception(f"Wrong value has been written -- 0x{rf_dev.getvalue(0xf0000004):x}.")

print("PASSED: write sanity write tests.")

"""
Reading Values:
    1. Single Field read
        rf.submod['entry_name0']['s_cfg']}
    2. read_entry -> single regfile device access performed, regfile_entry object hand back
        rf.submod['entry_name0'].read_entry()
    3. as dictionary
        rf.submod['entry_name0'].get_dict()
    4. raw value
        rf.submod['entry_name0'].get_value()
    5. as string for debugging purpose, fields + raw value as hex
        -> use in string context or explicit cast
        print(rf.submod['entry_name0'])
        or
        str(rf.submod['entry_name0'])
"""

for e in ['entry_name0', 'entry_name1_low']:
    print(f"Readback: 0x{rf.submod[e]['s_cfg']:x}")

rf.submod['entry_sync0'] = {f'enable_feature{i}': 1 for i in range(4)}

print(f"{rf.submod['entry_sync0']}")

# entry read - static
entry_name0 = rf.submod['entry_name0'].read_entry()

read_count = rf_dev.read_count

# printing example:
print(entry_name0)
print(f"(s_cfg, s_status) = 0x{entry_name0['s_cfg']:x} -- 0x{entry_name0['s_status']:x}")

if read_count != rf_dev.read_count:
    raise Exception(f"Regfile reads count increment by {rf_dev.read_count - read_count}")
else:
    print("PASSED: Regfile-read to variable")

# entry read - active
entry_name0 = rf.submod['entry_name0']
read_count = rf_dev.read_count
print(f"{entry_name0['s_cfg']} -- {entry_name0['s_status']}")
if read_count + 2 != rf_dev.read_count:
    raise Exception("Regfile reads count not increment by 2")

print("PASSED: Regfile reads counter test")

print("DONE.")
