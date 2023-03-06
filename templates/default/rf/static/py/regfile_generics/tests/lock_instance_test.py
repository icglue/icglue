"""Regfile access tests"""

import pytest
from pytest import warns

# pylint: disable=unused-import,redefined-outer-name
# flake8: noqa
from fixtures import sessionsubwordregfile, sessionsimpleregfile, sessionmemregfile

def test_regfile_attribute_exception(sessionsubwordregfile):
    regfile, rfdev = sessionsubwordregfile
    with pytest.raises(Exception):
        regfile.reg1_high_r = 0xdead

def test_regfile_entry_attribute_exception(sessionsubwordregfile):
    regfile, rfdev = sessionsubwordregfile
    entry = regfile['reg1_high'].get_register_entry(0x1)
    with pytest.raises(Exception):
        entry.cfg_f = 0xdead
    with pytest.raises(Exception):
        regfile.reg1_high_r.cfg_f = 0xdead
