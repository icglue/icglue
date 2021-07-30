# test files
deploy attributes.icglue           units/attributes/source/gen/

# setup
run icprep project

# generate everything
run_nocheck icglue units/attributes/source/gen/attributes.icglue

# check for 12 warnings/errors
eval_run_output {
    glob {W,* *} 12
    glob {E,* *} 0
}
