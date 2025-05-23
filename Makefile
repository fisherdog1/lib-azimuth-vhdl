.ONESHELL:
.SILENT:

vdp = ../../util/vdp

export directories:=\
address_math\
realtime_math\
clocking\
comms

build_vdp:
	cd ./vhdl-dumb-preprocessor/vdp
	go build .
	cd ../..
	mkdir util
	mv ./vhdl-dumb-preprocessor/vdp/vdp ./util/vdp

unit_test:
	$(vdp) -f tests.vdp -f ../templates/unit_tests_template.vhd -o > $(shell basename `pwd`).gen_vhd
	ghdl compile --std=08 -P../../lib/ *.gen_vhd *.vhd -r unit_tests > $(shell basename `pwd`)_08.log
	ghdl compile --std=93 -P../../lib/ *.gen_vhd *.vhd -r unit_tests > $(shell basename `pwd`)_93.log

	cat $(shell basename `pwd`)_08.log | egrep '!PASS!|!FAIL!'
	cat $(shell basename `pwd`)_93.log | egrep '!PASS!|!FAIL!'
	
all_unit_tests:
	$(foreach dir,$(directories),$(MAKE) -C ./rtl/$(dir) -f ../../Makefile unit_test;)

all_libs:
	$(MAKE) -C ./lib -f Libraries.mk
