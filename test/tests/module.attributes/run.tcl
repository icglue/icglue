# test files
deploy attributes.icglue           units/attributes/source/gen/

# setup
run icprep project

# generate everything
run icglue units/attributes/source/gen/attributes.icglue

# check for 0 warnings/errors
eval_run_output {
    glob {W,*:*} 0
    glob {E,*:*} 0
}
