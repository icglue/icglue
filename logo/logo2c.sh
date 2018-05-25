#!/bin/bash

d=$(dirname $0)
SED_CONV=(-e 's/\\/\\\\/g' -e 's/^\s\s/"/')
head -n-5 $d/logo.txt | sed -r ${SED_CONV[@]} -e 's/$/",/g'
tail -n5 $d/logo.txt  | sed -r ${SED_CONV[@]} > $d/logo-tail.tmp
paste -d '%' $d/logo-tail.tmp $d/info.txt | sed -e 's/%/  /' -e 's/$/",/g'
rm $d/logo-tail.tmp

