# without -tree in bottom to top order
M -rtl -v -u bungo bungo_mgmt
M -rtl -v -u bungo bungo_core
M -rtl -v -u bungo bungo_top    -i {bungo_core bungo_mgmt}
M -tb  -v -u bungo tb_bungo_top -i {bungo_top}

# Equivalent -tree in more natural top to bottom order
#M -unit "bungo" -tree {
#    (tb) tb_bungo_top
#    |
#    \-- (rtl) bungo_top
#          |
#          +-- (rtl) bungo_core
#          |
#          +-- (rtl) bungo_mgmt
#}


# resources have to be registered first as a module before instances can be created
M -resource common_sync
M -tb -v -u test tb_sync -i {common_sync<data> common_sync<valid> common_sync<gpio1, gpio2> common_sync<tx0, tx1, tx2>}

# Equivalent -tree
#M -unit "test" -tree {
#   (tb) tb_sync
#    |
#    +--- (res) common_sync<data>
#    |
#    +--- (res) common_sync<valid>
#    |
#    +--- (res) common_sync<gpio1,gpio2>
#}


## connections
S clk              bungo_mgmt   -> {tb_bungo_top bungo_top:clk_test! bungo_core:clk!}
S clk_ref          tb_bungo_top -> {bungo_mgmt:clk_src!}
S config -w 32     bungo_mgmt   -> bungo_core
S data   -w DATA_W bungo_mgmt   -> bungo_core
S status -w 16     bungo_mgmt  <-  bungo_core

S bddata -w 16 -b  {bungo_mgmt bungo_core tb_bungo_top}

# code
C bungo_mgmt -a {
    assign clk = clk_ref;
}

# parameters
P DATA_W -v 32 {bungo_mgmt bungo_core tb_bungo_top}

# vim: set filetype=icglueconstructtcl :
