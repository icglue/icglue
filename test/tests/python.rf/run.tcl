# test files
deploy python_rf.icglue           units/python_rf/source/gen/


# setup
run icprep project

# generate everything
run icglue units/python_rf/source/gen/python_rf.icglue

# check for 0 warnings/errors
eval_run_output {
    glob {W,* *} 0
    glob {E,* *} 0
}
deploy_resource python-regfile
deploy tc_python_rf.py software/python/regfile_access/

run python software/python/regfile_access/tc_python_rf.py
