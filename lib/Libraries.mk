all: lib_azimuth-obj08.cf lib_azimuth-obj93.cf

lib_azimuth-obj08.cf: $(foreach dir,$(directories),../rtl/$(dir)/*.vhd)
	echo "Building VHDL-08 library"
	ghdl -a --std=08 --work=lib_azimuth $^

lib_azimuth-obj93.cf: $(foreach dir,$(directories),../rtl/$(dir)/*.vhd)
	echo "Building VHDL-93 library"
	ghdl -a --std=93 --work=lib_azimuth $^
