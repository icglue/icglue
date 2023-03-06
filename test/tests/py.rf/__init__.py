from .rf_submod import SubmodRegfile


class Regfiles:
    def __init__(self, rf_dev):
        self.submod = SubmodRegfile(rf_dev, 0xf0000000)
