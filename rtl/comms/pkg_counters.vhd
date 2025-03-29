--Common counter procedures

library ieee;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.address_math.all;

package counters is
	generic (
		MAX_COUNT : natural);

	constant counter_bits : natural := bits_required(MAX_COUNT);
	subtype counter_t is unsigned(counter_bits - 1 downto 0);
	constant max : counter_t := to_unsigned(MAX_COUNT, counter_bits);
	constant zero : counter_t := to_unsigned(0, counter_bits);

	procedure sat_count(signal counter : inout counter_t);
	procedure sat_load_max(signal counter : inout counter_t);
	procedure sat_load_zero(signal counter : inout counter_t);
end package counters;

package body counters is
	procedure sat_count(signal counter : inout counter_t) is
	begin
		if counter < max then
			counter <= counter + 1;
		end if;
	end procedure;

	procedure sat_load_max(signal counter : inout counter_t) is
	begin
		counter <= max;
	end procedure;

	procedure sat_load_zero(signal counter : inout counter_t) is
	begin
		counter <= to_unsigned(0, counter_bits);
	end procedure;

	function saturated(signal counter : in counter_t) return boolean is
	begin
		return counter = max;
	end function;
end package body counters;
