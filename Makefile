# The year is 2025
.ONESHELL:

# Point to your Go/GHDL executables
GO := go
GHDL := ghdl

MAKE := make
THIS_DIR := $(shell pwd)
VDP_DIR := ${THIS_DIR}/vhdl-dumb-preprocessor/vdp
VDP := ${THIS_DIR}/util/vdp
BUILD_DIR := ${THIS_DIR}/build
TEMPLATES := ${THIS_DIR}/rtl/templates

# GHDL log checker
define checklog
rm -f PASS
rm -f FAIL
if cat $(1) | grep -q "!PASS!"; then\
	echo "$(2) PASSED";\
	touch PASS;\
else\
	echo "$(2) FAILED";\
	touch FAIL;\
fi
endef

build_vdp: ${VDP_DIR}/*.go
	echo "Building vdp"
	-mkdir ./util
	cd ${VDP_DIR}
	go build .
	mv vdp ../../util/vdp

rtl_test_dirs :=\
address_math\
realtime_math

$(rtl_test_dirs): ./rtl/templates/*.vhd build_vdp
	# Change directory to target
	$(shell pushd .)
	cd ./rtl/$@

	# Remove previous run
	rm -f *.gen.vhd
	rm -f *.log

	# Generate unit tests from list of expressions and template
	${VDP} -d package $@ -f tests.vdp -f ${TEMPLATES}/unit_tests_template.vhd -o > $@.gen.vhd

	# Compile and execute unit tests
	-${GHDL} compile --std=08 *.vhd -r unit_tests > $@.log

	# Check for !PASS!
	$(call checklog,$@.log,$@)

	# Leave directory
	$(shell popd .)

all_lib_tests: $(rtl_test_dirs)