namespace eval ig {
# modules
M -rtl -v -u proc proc_mgmt
M -rtl -v -u proc proc_core
M -rtl -v -u proc proc_top    -i {proc_core proc_mgmt}
M -tb  -v -u proc tb_proc_top -i {proc_top}

## connections
#S clk              proc_mgmt   -> {tb_proc_top proc_top->clk_test! proc_core->clk!}
#S clk_ref          tb_proc_top -> {proc_mgmt->clk_src!}
#S config -s 32     proc_mgmt   -> proc_core
#S data   -s DATA_W proc_mgmt   -> proc_core
#S status -s 16     proc_mgmt  <-  proc_core
#
#S bddata -s 16 -b  {proc_mgmt proc_core tb_proc_top}
#
## code
#C -m proc_mgmt -a {
#    assign clk = clk_ref;
#}
#
## parameters
#P DATA_W -v 32 {proc_mgmt proc_core tb_proc_top}
}
