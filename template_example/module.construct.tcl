
create_module -name tb_proc_top
create_module -name proc_top
create_module -name proc_core
create_module -name proc_mgmt
create_instance -name proc_core -of-module proc_core -parent-module proc_top
create_instance -name proc_mgmt -of-module proc_mgmt -parent-module proc_top
create_instance -name proc_top -of-module proc_top -parent-module tb_proc_top

connect -from [get_instances -name proc_mgmt] -to [list [get_modules -name tb_proc_top] [get_instances -name proc_core]] -signal-name clk

