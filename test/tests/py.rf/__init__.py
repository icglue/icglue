from .rf_submod_regfile import submod_regfile


class regfiles:
    def __init__(self, rf_dev):
        self.submod = submod_regfile(rf_dev, 0xf0000000)
