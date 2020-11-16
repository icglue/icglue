/* ICGLUE GENERATED FILE - manual changes out of prepared *icglue keep begin/end* blocks will be overwritten */
% set cell_define [ig::db::get_attribute -object $obj_id -attribute "cell" -default "false"]
%I(vlog/include/header.wtf.vh)
%if {[llength $mod_data(regfiles)] == 0} {
%I(vlog/include/inst.wtf.vh)
%} else {
%I(vlog/include/regfile.wtf.vh)
%}
%#I(vlog/include/orphaned-keep-blocks.wtf.vh)
endmodule
%if {$cell_define} {
`endcelldefine
%}
% echo "\n[pop_keep_block_content keep_block_data "keep" "foot"]\n"
