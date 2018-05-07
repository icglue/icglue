namespace eval ig {
# modules
M -rtl -v -u rftest mgmt_regfile -rf {mgmt_regfile}
M -rtl -v -u rftest mgmt         -i {mgmt_regfile}
M -rtl -v -u rftest core
M -rtl -v -u rftest top          -i {core mgmt}
M -tb  -v -u rftest tb_top       -i {top}

## connections
S clk              mgmt          -> {top core->clk!}
S clk_ref          tb_top        -> {mgmt->clk_src! mgmt_regfile->clk!}
S config -w 32     mgmt_regfile  -> core
S data   -w DATA_W mgmt_regfile  -> core
S status -w 16     mgmt_regfile <-  core

# code
C -m mgmt -a {
    assign clk = clk_ref;
}

# parameters
P DATA_W -v 32 {mgmt_regfile core tb_top}

# regfile
R -rf mgmt_regfile "RA_CONFIG" @0x0004 {
    {name width entrybits type reset signal signalbits}
    {cfg1 5     4:0       RW   5'h0  config  4:0}
    {cfg2 6    11:5       RW   6'h0  config2 6:0}
}

# regfile
R -rf mgmt_regfile "RA_CONFIG2" @0x0008 {
    {name width entrybits type reset signal  signalbits}
    {cfg3 5     4:0       RW   5'h0  config3 4:0}
    {cfg4 6     11:5      R    6'h0  config4 6:0}
}

}
