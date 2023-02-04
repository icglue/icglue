# resources
deploy_resource apb_stim
deploy_resource stimc

# test files
deploy crc.icglue           units/crc/source/gen/
deploy common_crc.v         units/crc/source/rtl/verilog/
deploy Makefile.rtl.sources units/crc/simulation/iverilog/common/
deploy regression.Makefile  regression/Makefile
deploy res.vlog.sources     units/crc/source/list/
deploy rtl.vlog.sources     units/crc/source/list/
deploy tb.vlog.sources      units/crc/source/list/
deploy testcase.cpp         units/crc/simulation/iverilog/tc_rf_access/
deploy testcase.vh          units/crc/simulation/iverilog/tc_rf_access/

# setup
run icprep project
eval_run_output {glob {I,Gen*} 4}

run icglue units/crc/source/gen/crc.icglue -o "vlog-sv,rf-host.cpp,rf-host.h"
eval_run_output {
    re   {^I,Gen\s+Generating \[vlog-sv\].*$}     4
    re   {^I,Gen\s+Generating \[rf-host.h\].*$}   1
    re   {^I,Gen\s+Generating \[rf-host.cpp\].*$} 1
    glob {I,Gen*}                                 6
}

run icprep iverilog --unit crc --testcase tc_rf_access
eval_run_output {glob {I,Gen*} 12}

run icprep regression --simdir iverilog
eval_run_output {glob {I,Gen*} 2}

# run
run_in regression make

# evaluate regression
eval_regression
