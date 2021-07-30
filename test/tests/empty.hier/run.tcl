# test files
deploy mod.icglue           units/mod/source/gen/

# setup
run icprep project

# generate everything
run icglue units/mod/source/gen/mod.icglue

# check for 0 warnings/errors
eval_run_output {
    glob {W,* *} 0
    glob {E,* *} 0
}
