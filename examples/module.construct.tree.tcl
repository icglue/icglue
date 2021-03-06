#!/usr/bin/env icglue
# modules
M -unit "chungo" -tree {
    chungo(rtl)
    |
    \-- chungo_inst .................... (rtl)
        |
        \-- common_sync<chungo12..15> .. (res)
}

M -unit "rftest" -tree {
    tb_top .................................... (tb,v)
    |
    \-- top ................................... (rtl)
        |
        +-- mgmt .............................. (rtl)
        |   |
        |   +-- mgmt_regfile .................. (rf,rfattr=accesscargs={uint8_t xcoord} {uint8_t ycoord})
        |   |   |
        |   |   \-- common_sync<1..2,4,test> .. (res)
        |   |
        |   +-- test_mgmt ..................... (res)
        |   +-- test_mgmt2 .................... (res)
        |   +-- test_mgmt3 .................... (res)
        |   +-- test_mgmt4 .................... (res)
        |   |
        |   +-- chungo ........................ (inc)
        |   |
        |   +-- mgmt_wrap0 .................... (rtl)
        |   |   |
        |   |   +-- mgmt_wrap1 ................ (rtl)
        |   |   |   |
        |   |   |   +-- test_mgmt5 ............ (rtl)
        |   |   |   |   |
        |   |   |   |   +-- test_mgmt6 ........ (res)
        |   |   |   |   +-- test_mgmt7 ........ (res)
        |   |   |   |
        |   |   |   \-- test_mgmt71 ........... (rtl,unit=test,attr=clang => tcl, attr= compile=>ncsim)
        |   |   |
        |   |   \-- test_mgmt8 ................ (res)
        |   |
        |   \-- test_mgmt9 .................... (res)
        |
        +-- core .............................. (rtl)
        |
        +-- common_sync<a,b1..4> .............. (res)
        \-- common_sync_pedge ................. (res)
}

# connections
set mod_reset_clk_core {
    common_sync<a,b1..4> reset_n_i clk_i
    common_sync_pedge    reset_n_i clk_i
}

foreach {mod reset_port clk_port} $mod_reset_clk_core {
    lappend reset_core_list $mod:$reset_port
    lappend clk_core_list   $mod:$clk_port
}

S "resetn"   tb_top --> $reset_core_list
S "clk_core" tb_top --> $clk_core_list

S -pin "testmode_i" = "1'b0" common_sync<a,b1..4>
S -pin "testmode_i" = "1'b0" common_sync_pedge
S -pin "data_o"              common_sync_pedge

# connections
S clk                mgmt         --> top core:clk!
S clk_ref            tb_top       --> mgmt:clk_src_i mgmt_regfile:clk_ref_i common_sync<1..2,4,test>:clk_i
S rf_addr     -w 32  tb_top       --> mgmt_regfile
S rf_w_data   -w 32  tb_top       --> mgmt_regfile
S rf_en              tb_top       --> mgmt_regfile
S rf_r_data   -w 32  tb_top       <-- mgmt_regfile
S en_invtest         mgmt         --> ~core

S reset_n_ref              tb_top --> {mgmt_regfile common_sync<1..2,4,test>:resetn_i}
S config      -w32  mgmt_regfile  --> core
S config2     -w32  mgmt_regfile  --> core
S config3     -w32  mgmt_regfile  --> core

S data   -w DATA_W mgmt_regfile  -> core
S status -w 16     mgmt_regfile <-  core

# code
C mgmt -a {
    assign clk = clk_ref;
}

# parameters
P DATA_W = 32 "mgmt_regfile core tb_top"
P DATA_W0 -v 32 {mgmt_regfile core}
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
    {name            entrybits type reset signal             signalbits comment}
    {cfg_test_0      4:0       RW   5'h0  config_test0       4:0        "abc"}
    {cfg_test___1    4:0       RW   5'h0  config_test___1    4:0        "def"}
    {cfg_test______2 4:0       RW   5'h0  config_test______2 4:0        "ghi"}
    {status_test     15:0      R    16'h0 status_test        16:0       "jkl"}
}

# vim: set filetype=icglueconstructtcl :
