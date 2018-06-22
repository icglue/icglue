#!/bin/bash

root_dir=$(readlink -e $(dirname $0)/..)

echo "TCL Log-Identifier:"
echo "-------------------"
grep -h ig::log  $root_dir/bin/* $root_dir/tcllib/* | sed -nr -e 's/.*-id\s(\w+).*/\1/p' | sort -u

echo ""
echo "C Log-Identifier:"
echo "-----------------"
egrep -h '\<log_(debug|info|warn|error)' $root_dir/lib/*.c  | sed -nr -e 's/.*log_(debug|info|warn|error)\s*\("([^"]+)".*/\2/p' | sort -u

