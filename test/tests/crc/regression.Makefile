# icglue keep begin testcaselist
TESTCASES := \
	crc.tc_rf_access \
# icglue keep end

# icglue keep begin cleanup
OLDAFTERDAYS := 10
# icglue keep end

include ${ICPRO_DIR}/env/regression/Makefile.regression
