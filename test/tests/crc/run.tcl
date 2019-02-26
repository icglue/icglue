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
eval_run_output {glob {I,Gen*} 4}

run icglue units/crc/source/gen/crc.icglue -o "vlog-v,rf-cpp,rf-hpp"
eval_run_output {
    re   {^I,Gen\s+Generating \[vlog-v\].*$} 4
    re   {^I,Gen\s+Generating \[rf-hpp\].*$} 1
    re   {^I,Gen\s+Generating \[rf-cpp\].*$} 1
    glob {I,Gen*}                            6
}

run icprep iverilog --unit crc --testcase tc_rf_access
eval_run_output {glob {I,Gen*} 5}

run icprep regression
eval_run_output {glob {I,Gen*} 2}

# run
run_in regression make

# evaluate regression
eval_regression
