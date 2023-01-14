
from pytest import warns

# pylint: disable=unused-import,redefined-outer-name
# flake8: noqa
from fixtures import sessionsubwordregfile

# pylint: disable=line-too-long,missing-function-docstring


def test_uvm_write(sessionsubwordregfile):
    regfile, rfdev = sessionsubwordregfile
    regfile.reset_all()
    write_count = rfdev.write_count
    read_count = rfdev.read_count

    regfile.reg0_r.cfg_f.set(1)
    regfile.reg2_r.config_f.set(2)
    regfile.reg0_r.get_field_by_name('cfg').set(3)
    regfile.reg0_r.update()
    regfile.reg2_r.update()

    assert regfile['reg_addr40'].get_mirrored_value() == 0b01010
    with warns(UserWarning, match=r'enable_feature[2-3]: value 0x2 is truncated to 0x[0-1] \(mask: 0x1\).'):
        for i in range(3, 0, -1):
            regfile['reg_addr40'].field(f'enable_feature{i}').set(i)

    regfile['reg_addr40'].update()

    assert rfdev.getvalue(0xF000_0000) == 0x3
    assert rfdev.getvalue(0xF000_00C0) == 0x2 << 4
    assert rfdev.getvalue(0xF000_0040) == 0b10110
    assert regfile['reg_addr40'].get_mirrored_value() == 0b10110

    assert write_count + 3 == rfdev.write_count

    regfile['reg_addr40'].set(0b01001)
    assert rfdev.getvalue(0xF000_0040) == 0b10110
    assert regfile['reg_addr40'].needs_update() == True
    assert regfile['reg_addr40'].get() == 0b01001

    assert regfile['reg_addr40'].get_mirrored_value() == 0b10110
    regfile['reg_addr40'].update()
    assert rfdev.getvalue(0xF000_0040) == 0b01001
    assert regfile['reg_addr40'].get_mirrored_value() == 0b01001
    assert regfile['reg_addr40'].get_reset() == 0b01010
    assert regfile['reg_addr40'].read() == 0b01001
    assert read_count + 1 == rfdev.read_count
    assert regfile['reg_addr40'].get_offset() == 0x40
    assert regfile['reg_addr40'].get_address()== 0xF000_0040

    write_count = rfdev.write_count
    read_count = rfdev.read_count
    regfile.reg_addr40_r.write_update({'start': 0, 'enable_feature0': 1, 'enable_feature1': 1})
    assert rfdev.getvalue(0xF000_0040) == 0b01110
    assert read_count == rfdev.read_count
    assert write_count + 1 == rfdev.write_count
