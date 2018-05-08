namespace eval ig {
# modules
M -rtl -v -u rftest mgmt_regfile -rf {mgmt_regfile}
M -rtl -v -u rftest mgmt         -i {mgmt_regfile}
M -rtl -v -u rftest core
M -rtl -v -u rftest top          -i {core mgmt}
M -tb  -v -u rftest tb_top       -i {top}

## connections
S clk                mgmt          -> {top core->clk!}
S clk_ref            tb_top        -> {mgmt->clk_src! mgmt_regfile->clk_ref_i}
S rf_addr_i   -w 32  tb_top        -> {mgmt_regfile}
S rf_w_data_i -w 32  tb_top        -> {mgmt_regfile}
S rf_en_i            tb_top        -> {mgmt_regfile}
S rf_r_data_o -w 32  tb_top       <- {mgmt_regfile}

S reset_n_ref      tb_top        -> {mgmt_regfile}
S config -w 32     mgmt_regfile  -> core
S config2 -w 32     mgmt_regfile  -> core
S config3 -w 32     mgmt_regfile  -> core
S data   -w DATA_W mgmt_regfile  -> core
S status -w 16     mgmt_regfile <-  core

# code
C -m mgmt -a {
    assign clk = clk_ref;
}

# parameters
P DATA_W -v 32 {mgmt_regfile core tb_top}

# regfile
R -rf mgmt_regfile "config" @0x0004 {
    {name        entrybits type reset signal  signalbits}
    {cfg1_zzzzz  4:0       RW   5'h0  config  4:0       }
    {cfg2_eu     11:5      RW   6'h0  config2 6:0       }
}

# regfile
R -rf mgmt_regfile "config2" @0x0008 {
    {name       entrybits type reset signal  signalbits}
    {cfg_uiae3  4:0       RW   5'h0  config3  4:0        }
    {status     15:0      R    16'h0  status  16:0       }
}

}
