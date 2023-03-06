#!/bin/sh

coverage run -m pytest -s -v || exit 1
coverage report -m
