
# setup
run icprep project

deploy pytest.icglue           units/pytest/source/gen/
deploy test.py software/py/test.py
deploy __init__.py software/py/regfile_access/__init__.py
deploy_resource pyregfile

# generate everything
run icglue units/pytest/source/gen/pytest.icglue

# check for 0 warnings/errors
eval_run_output {
    glob {W,*:*} 0
    glob {E,*:*} 0
}

# python test
run python software/py/test.py
