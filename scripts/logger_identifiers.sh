#!/bin/bash

root_dir=$(readlink -e $(dirname $0)/..)

echo "TCL Log-Identifier:"
echo "-------------------"
grep -h ig::log  $root_dir/bin/* $root_dir/tcllib/* | grep -- '-debug' | sed -nr -e 's/.*-id\s(\w+).*/D,\1/p' | sort -u
grep -h ig::log  $root_dir/bin/* $root_dir/tcllib/* | grep -- '-info'  | sed -nr -e 's/.*-id\s(\w+).*/I,\1/p' | sort -u
grep -h ig::log  $root_dir/bin/* $root_dir/tcllib/* | grep -- '-warn'  | sed -nr -e 's/.*-id\s(\w+).*/W,\1/p' | sort -u
grep -h ig::log  $root_dir/bin/* $root_dir/tcllib/* | grep -- '-error' | sed -nr -e 's/.*-id\s(\w+).*/E,\1/p' | sort -u

echo ""
echo "C Log-Identifier:"
echo "-----------------"
egrep -h '\<log_debug' $root_dir/lib/*.c | sed -nr -e 's/.*log_debug\s*\("([^"]+)".*/D,\1/p' | sort -u
egrep -h '\<log_info' $root_dir/lib/*.c  | sed -nr -e 's/.*log_info\s*\("([^"]+)".*/I,\1/p'  | sort -u
egrep -h '\<log_warn' $root_dir/lib/*.c  | sed -nr -e 's/.*log_warn\s*\("([^"]+)".*/W,\1/p'  | sort -u
egrep -h '\<log_debug' $root_dir/lib/*.c | sed -nr -e 's/.*log_debug\s*\("([^"]+)".*/E,\1/p' | sort -u

