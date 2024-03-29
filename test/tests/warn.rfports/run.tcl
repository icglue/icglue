# test files
deploy mod.icglue           units/mod/source/gen/

# setup
run icprep project
eval_run_output {glob {I,Gen*} 4}

run_nocheck icglue units/mod/source/gen/mod.icglue -o "vlog-v"
# check for missing regfile ports warnings
eval_run_output {
    glob {W,ChkRP*Regfile mod expects port*in module mod_rf} 13
}
