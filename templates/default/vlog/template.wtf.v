%(
  proc necho arg {
    if {"[string trim $arg]" ne {}} {
      echo "$arg"
    }
  }
  proc cond_pop_keep_block_content {args} {
    variable keepblocks
    if {$keepblocks} {
      return "[uplevel 1 [list pop_keep_block_content {*}$args]]\n"
    } else {
      return {}
    }
  }

  set keepblocks [ig::db::get_attribute -object $obj_id -attribute "keepblocks" -default "false"]

  array set mod_data [module_to_arraylist $obj_id]

  set systemverilog [expr {$mod_data(language) eq "systemverilog"}]
%)
%I(vlog/include/header.wtf.vh)
%
% if {[llength $mod_data(regfiles)] == 0} {
%I(vlog/include/inst.wtf.vh)
% } else {
%I(vlog/include/regfile.wtf.vh)
% }
%
%I(vlog/include/orphaned-keep-blocks.wtf.vh)
endmodule
% if {$cell_define} {
`endcelldefine
% }
% necho [cond_pop_keep_block_content keep_block_data "keep" "foot"]
