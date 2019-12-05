namespace import ::ig::db::*

set_attribute -object [create_module -name tb_bungo_top] -attributes {"language" verilog "parentunit" bungo "mode" tb}
set_attribute -object [create_module -name bungo_top]    -attributes {"language" verilog "parentunit" bungo "mode" rtl}
set_attribute -object [create_module -name bungo_core]   -attributes {"language" verilog "parentunit" bungo "mode" rtl}
set_attribute -object [create_module -name bungo_mgmt]   -attributes {"language" verilog "parentunit" bungo "mode" rtl}

create_instance -name bungo_core -of-module bungo_core -parent-module bungo_top
create_instance -name bungo_mgmt -of-module bungo_mgmt -parent-module bungo_top
create_instance -name bungo_top -of-module bungo_top -parent-module tb_bungo_top

# Equivalent -tree
#M -unit="bungo" -tree {
#    (tb) tb_bungo_top
#    |
#    +--- (rtl,v) bungo_top
#           |
#           +--- (rtl,v) bungo_mgmt
#           |
#           +--- (rtl,v) bungo_core
#}

connect -from [get_instances -name bungo_mgmt] -to [list [get_modules -name tb_bungo_top] [get_modules -name bungo_top]:clk_test! [get_instances -name bungo_core]:clk!] -signal-name clk
connect -from [get_modules -name tb_bungo_top] -to [list [get_instances -name bungo_mgmt]:clk_src!] -signal-name clk_ref
connect -from [get_instances -name bungo_mgmt] -to [list [get_instances -name bungo_core]] -signal-name config -signal-size 32
connect -from [get_instances -name bungo_mgmt] -to [list [get_instances -name bungo_core]] -signal-name data -signal-size "DATA_W"
connect -from [get_instances -name bungo_core] -to [list [get_instances -name bungo_mgmt]] -signal-name status -signal-size 16
connect -bidir [list [get_instances -name bungo_mgmt] [get_instances -name bungo_core] [get_modules -name tb_bungo_top]] -signal-name bddata -signal-size 16

set cs [add_codesection -parent-module [get_modules -name bungo_mgmt] -code {    assign clk! = clk_ref!;

}]

set_attribute -object $cs -attribute "adapt" -value "selective"

parameter -targets [list [get_instances -name bungo_mgmt] [get_instances -name bungo_core] [get_modules -name tb_bungo_top]] -name DATA_W -value 32

# vim: set filetype=icglueconstructtcl :
