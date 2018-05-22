# modules
M -rtl -v -u rftest common_sync -res
M -rtl -v -u rftest mgmt_regfile -rf {mgmt_regfile} -i {common_sync<1..2,4,test>}
M -rtl -v -u rftest mgmt         -i {mgmt_regfile}
M -rtl -v -u rftest core
M -rtl -v -u rftest top          -i {core mgmt}
M -tb  -v -u rftest tb_top       -i {top}

#M -unit "rftest" -tree {
#    ..tb_top(tb,v)
#    ....top(rtl)
#    ......mgmt(rtl)
#    .........mgmt_regfile(rf)
#    ......core(rtl)
#}
    #........common_sync<1,4..9,test1..3>(res)


## connections
S clk                mgmt          -> {top core->clk!}
S clk_ref            tb_top        -> {mgmt->clk_src! mgmt_regfile->clk_ref_i common_sync<1..2,4,test>->clk_i}
S rf_addr     -w 32  tb_top        -> {mgmt_regfile}
S rf_w_data   -w 32  tb_top        -> {mgmt_regfile}
S rf_en              tb_top        -> {mgmt_regfile}
S rf_r_data   -w 32  tb_top       <- {mgmt_regfile}

S reset_n_ref      tb_top        -> {mgmt_regfile common_sync<1..2,4,test>->resetn_i}
S config -w 32     mgmt_regfile  -> core
S config2 -w 32     mgmt_regfile  -> core
S config3 -w 32     mgmt_regfile  -> core

S data   -w DATA_W mgmt_regfile  -> core
S status -w 16     mgmt_regfile <-  core

# code
C mgmt -a {
    assign clk = clk_ref;
}

# parameters
P DATA_W = 32 "mgmt_regfile core tb_top"
P DATA_W0 -v32 {mgmt_regfile core}
P DATA_W1 {mgmt_regfile} = 32
P =0.1 DELAY      {common_sync<4,test>}
P TEST    = "uiae"   {common_sync<4,test>}

C mgmt_regfile -a {
    // assign clk signal
    assign clk = clk_ref;
}

# regfile
R -rf=mgmt_regfile "config" @0x0004 {
    {name        entrybits type reset signal  signalbits}
    {cfg1_zzzzz  4:0       RW   5'h0  config  4:0       }
    {cfg2_eu     11:5      RW   6'h0  config2 6:0       }
}

R -rf=mgmt_regfile "config2" @0x0008 {
    {name       entrybits type reset signal  signalbits}
    {cfg_uiae3  4:0       RW   5'h0  config3  4:0        }
    {status     15:0      R    16'h0  status  16:0       }
}

S config_test0       -w 32 mgmt_regfile -> core
S config_test___1    -w 32 mgmt_regfile -> core
S config_test______2 -w 32 mgmt_regfile -> core
S status_test        -w 16 mgmt_regfile <- core

R -rf mgmt_regfile "config1" @0x0008 {
    {name            entrybits type reset signal             signalbits}
    {cfg_test_0      4:0       RW   5'h0  config_test0       4:0         }
    {cfg_test___1    4:0       RW   5'h0  config_test___1    4:0         }
    {cfg_test______2 4:0       RW   5'h0  config_test______2 4:0         }
    {status_test     15:0      R    16'h0 status_test        16:0        }
}

