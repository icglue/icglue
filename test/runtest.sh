#!/bin/bash

export SHELL=/bin/bash
testpath=${BASH_SOURCE:-$_}
testpath=$(dirname $(readlink -e "${testpath}"))
INDIR=${testpath}/input

# make tools available
source ../env.sh

# create and enter project
PROJDIR=${testpath}/proj

mkdir -p ${PROJDIR}
cd ${PROJDIR}

icprep project

source ./env.sh

# resources
mkdir -p ${PROJDIR}/global_src/stimc
cp ${INDIR}/stimc/* ${PROJDIR}/global_src/stimc

mkdir -p ${PROJDIR}/units/apb_stim/source/behavioral/stimc
mkdir -p ${PROJDIR}/units/apb_stim/source/behavioral/verilog
cp ${INDIR}/apb_stim/*.{h,cpp,inl} ${PROJDIR}/units/apb_stim/source/behavioral/stimc
cp ${INDIR}/apb_stim/*.v           ${PROJDIR}/units/apb_stim/source/behavioral/verilog

# copy/run icglue script
mkdir -p units/crc/source/gen
cp ${INDIR}/test.crc/crc.icglue units/crc/source/gen

icglue units/crc/source/gen/crc.icglue -o "vlog-v,rf-cpp,rf-hpp"

# prepare sim
mkdir -p ${PROJDIR}/units/crc/simulation/iverilog/common
cp ${INDIR}/test.crc/Makefile.rtl.sources ${PROJDIR}/units/crc/simulation/iverilog/common
icprep iverilog --unit crc --testcase tc_rf_access
cp ${INDIR}/test.crc/testcase.cpp ${PROJDIR}/units/crc/simulation/iverilog/tc_rf_access
cp ${INDIR}/test.crc/testcase.vh  ${PROJDIR}/units/crc/simulation/iverilog/tc_rf_access

# prepare regression
icprep regression
cp ${INDIR}/test.crc/regression.Makefile ${PROJDIR}/regression/Makefile

# run regression
cd ${PROJDIR}/regression
make -j 4

#TODO...
# - improve testcase
# - add more testcases?
# - activate cleanup

# cleanup
cd $testpath
#rm -rf $PROJDIR
