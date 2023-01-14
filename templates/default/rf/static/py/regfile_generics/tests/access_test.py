"""Regfile access tests"""
from pytest import warns

# pylint: disable=unused-import,redefined-outer-name
# flake8: noqa
from fixtures import sessionsubwordregfile, sessionsimpleregfile, sessionmemregfile

# pylint: disable=line-too-long,missing-function-docstring


def test_dict_access(sessionsubwordregfile):
    """dict like access"""
    regfile, rfdev = sessionsubwordregfile

    write_count = rfdev.write_count
    regfile['reg1_high'] = {'cfg': 0x0ff,
                            'cfg_trigger': 0x1,
                            'cfg_trigger_mode': 0x0}

    assert 0xF000_0008 in rfdev.mem.keys()
    assert rfdev.getvalue(0xF000_0008) == 0x1ff

    regfile['reg0'] = {'cfg': 0x11}

    read_count = rfdev.read_count
    reg0 = dict(regfile['reg0'])
    print(f"Debug: dict-read: {reg0}")

    assert reg0['cfg'] == 0x11
    assert read_count + 1 == rfdev.read_count
    assert rfdev.getvalue(0xF000_0000) & 0b11111 == 0x11

    assert write_count + 2 == rfdev.write_count


def test_str_cast(sessionsubwordregfile):
    regfile, rfdev = sessionsubwordregfile

    write_count = rfdev.write_count
    read_count = rfdev.read_count
    regfile['reg1_high'] = {'cfg': 0x0aa,
                            'cfg_trigger': 0x0,
                            'cfg_trigger_mode': 0x0}

    print("Byte aligned - should no do read-modify-write...")
    regfile['reg1_high']['cfg_trigger_mode'] = 0b11

    print("Reading register to string...")
    reg1_high_string = f"{regfile['reg1_high']}"
    print(reg1_high_string)
    expect_str = "Register reg1_high: {'cfg': 0xaa, 'cfg_trigger': 0x0, 'cfg_trigger_mode': 0x3} = 0x300aa"
    assert reg1_high_string == expect_str
    assert write_count + 2 == rfdev.write_count
    assert read_count + 1 == rfdev.read_count
    assert str(regfile['reg1_high'].field('cfg')) == 'cfg'


def test_truncation_warning(sessionsubwordregfile):
    regfile, rfdev = sessionsubwordregfile

    with warns(UserWarning, match=r'Field\(s\) cfg_trigger_mode were not explicitly set during write '
                                  'of register reg1_high!'):
        regfile['reg1_high'] = {'cfg': 0x0bb,
                                'cfg_trigger': 0x1}
    assert rfdev.getvalue(0xF000_0008) == 0x1bb

    with warns(UserWarning, match=r'^Ignoring non existent Field NOT_EXISTENT for write.$'):
        regfile['reg1_high'] = {'NOT_EXISTENT': 0x0ff,
                                'cfg_trigger': 0x1}

    assert rfdev.getvalue(0xF000_0008) == 0x100

    with warns(UserWarning, match=r'^Writing read-only field status \(value: 0x00000100 -- mask: 0xffff0000 write_mask: 0x0000001f\).$'):
        regfile['reg0']['status'] = 0x100


def test_read_entry(sessionsubwordregfile):
    regfile, rfdev = sessionsubwordregfile
    write_count = rfdev.write_count
    read_count = rfdev.read_count

    regfile['reg1_high'] = {'cfg': 0x011,
                            'cfg_trigger': 0x0,
                            'cfg_trigger_mode': 0b01}

    entry = regfile['reg1_high'].read_entry()
    assert rfdev.getvalue(0xF000_0008) == 0x10011

    entry['cfg'] = 0x22
    entry['cfg_trigger'] = 0x1
    entry['cfg_trigger_mode'] = 0x0
    assert entry['cfg'] == 0x22

    regfile['reg1_high'] = entry
    assert rfdev.getvalue(0xF000_0008) == 0x00122
    assert {'cfg': 0x077,
            'cfg_trigger': 0x0,
            'cfg_trigger_mode': 0b10} == dict(regfile['reg1_high'].get_dict(0x20077))

    assert regfile['reg1_high'].get_value({'cfg': 0x077,
                                           'cfg_trigger': 0x0,
                                           'cfg_trigger_mode': 0b10}) == 0x20077

    assert write_count + 2 == rfdev.write_count
    assert read_count + 1 == rfdev.read_count
    assert {'cfg': 0x22,
            'cfg_trigger': 0x1,
            'cfg_trigger_mode': 0x0} == dict(regfile['reg1_high'].get_dict())
    assert read_count + 2 == rfdev.read_count


def test_int_access(sessionsubwordregfile):
    regfile, rfdev = sessionsubwordregfile

    read_count = rfdev.read_count
    write_count = rfdev.write_count

    regfile['reg1_low'] = 0xabcd1234
    assert regfile['reg1_low']['cfg'] == 0xabcd1234

    regfile['reg1_high'] = 0x1234abcd
    assert {'cfg': 0xcd,
            'cfg_trigger': 0x1,
            'cfg_trigger_mode': 0x0} == dict(regfile['reg1_high'])

    assert regfile['reg1_high'] == 0x1234abcd
    assert int(regfile['reg1_low']) == 0xabcd1234
    assert 0x1234abcc < regfile['reg1_high'] < 0x1234abce
    assert 0x1234abcd <= regfile['reg1_high'] <= 0x1234abce
    assert write_count + 2 == rfdev.write_count
    assert read_count + 8 == rfdev.read_count


def test_get_reset_values(sessionsubwordregfile):
    regfile, rfdev = sessionsubwordregfile
    assert dict(regfile['reg_addr40'].get_reset_values()) == {'start': 0, **{f'enable_feature{i}': (i + 1) & 0x1 for i in range(4)}}


def test_rfdev_simple(sessionsimpleregfile):
    regfile, rfdev = sessionsimpleregfile

    print("write")
    regfile['reg1_high'] = {'cfg': 0x07a,
                            'cfg_trigger': 0x1,
                            'cfg_trigger_mode': 0x0}

    write_count = rfdev.write_count
    read_count = rfdev.read_count

    print("compare")
    assert rfdev.getvalue(0xF000_0008) == 0x0000_017a

    # read-modify-write
    regfile['reg1_high']['cfg'] = 0x7b
    assert rfdev.getvalue(0xF000_0008) == 0x0000_017b

    # read-modify-write
    regfile['reg1_high']['cfg_trigger_mode'] = 0x3
    assert rfdev.getvalue(0xF000_0008) == 0x0003_017b

    regfile['reg0']['cfg'] = 0x1c

    assert rfdev.getvalue(0xF000_0000) & 0x1f == 0x1c

    assert read_count + 2 == rfdev.read_count
    assert write_count + 3 == rfdev.write_count


def test_mem(sessionmemregfile):
    regfile, rfdev = sessionmemregfile

    regfile.write_image(0x8, tuple(i for i in range(16)))

    print(rfdev.mem)
    for i in range(16):
        assert rfdev.mem[0xA000_0000 +  0x8 + i * rfdev.n_word_bytes] == i

    image = regfile.read_image(0xC, 15)
    print(image)
    for i in range(15):
        assert image[i] == i + 1
