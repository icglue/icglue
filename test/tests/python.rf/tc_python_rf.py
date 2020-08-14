from rf_python_rf import rf_python_rf

def read(addr):
    print ("Reading addr 0x%08X" % (addr))
    return 0

def write(addr, value):
    print ("Writing addr 0x%08X = 0x%08X" % (addr, value))

regfile = rf_python_rf(0, read, write)
p  = regfile.gpio_ctrl._word
regfile.gpio_ctrl._word = 0
p = regfile.gpio_ctrl.dout
regfile.gpio_ctrl.dout = 4
d = regfile.gpio_ctrl._dict
regfile.gpio_ctrl._dict = {'dout':1, 'oe':2, 'gpio_mux':3}
