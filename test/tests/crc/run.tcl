# resources
deploy_resource apb_stim
deploy_resource stimc

# test files
deploy crc.icglue           units/crc/source/gen/
deploy Makefile.rtl.sources units/crc/simulation/iverilog/common/
deploy regression.Makefile  regression/Makefile
deploy testcase.cpp         units/crc/simulation/iverilog/tc_rf_access/
deploy testcase.vh          units/crc/simulation/iverilog/tc_rf_access/

# setup
run icprep project
run icglue units/crc/source/gen/crc.icglue -o "vlog-v,rf-cpp,rf-hpp"
run icprep iverilog --unit crc --testcase tc_rf_access
run icprep regression

# run
run_in regression make

# evaluate regression
eval_regression
