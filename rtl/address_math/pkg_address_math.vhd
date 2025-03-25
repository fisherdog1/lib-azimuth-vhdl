library ieee;
	use ieee.math_real.all;

library lib_azimuth;

package address_math is
	function bits_required(unsigned_max : natural) return natural;
end package;
	
package body address_math is
	
	--Get number of bits required to represent the given unsigned integer
	function bits_required(unsigned_max : natural) return natural is
	begin
		return integer(ceil(log2(real(unsigned_max + 1))));
	end function;
end package body;
