#!/bin/bash
# The year is 2025
.ONESHELL:
.SILENT:

# Point to your Go/GHDL executables
GO := go
GHDL := ghdl

MAKE := make
THIS_DIR := $(shell pwd)
VDP_DIR := ${THIS_DIR}/vhdl-dumb-preprocessor/vdp
VDP := ${THIS_DIR}/util/vdp
BUILD_DIR := ${THIS_DIR}/build
TEMPLATES := ${THIS_DIR}/rtl/templates

./util/vdp: ${VDP_DIR}/*.go
	echo "Building vdp"
	-mkdir ./util
	cd ${VDP_DIR}
	go build .
	mv vdp ../../util/vdp

rtl_test_dirs :=\
address_math\
realtime_math

$(rtl_test_dirs): ./rtl/templates/*.vhd ./util/vdp
	# Change directory to target
	cd ./rtl/$@

	# Remove previous run
	rm -f *.gen.vhd
	rm -f *.log

	# Generate unit tests from list of expressions and template
	${VDP} -d package $@ -f tests.vdp -f ${TEMPLATES}/unit_tests_template.vhd -o > $@.gen.vhd

	# Compile and execute unit tests
	-${GHDL} compile --std=08 *.vhd -r unit_tests > $@.log

	# Check for !PASS!
	rm -f PASS
	rm -f FAIL
	if cat $@.log | grep -q "!PASS!"; then\
		echo "=================== Unit Tests for $@ PASSED ===================";\
	touch PASS;\
	else\
		echo "=================== Unit Tests for $@ FAILED ===================";\
		if [ -s $@.log ]; then
			echo "GHDL Log ($@.log):"
			cat $@.log
			echo ""
		fi
	touch FAIL;\
	fi

all_unit_tests: $(rtl_test_dirs)
