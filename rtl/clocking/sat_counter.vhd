--Actually, lets do this as a procedure
--Saturating counter

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity sat_counter is
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--Allow counting
		count_enable : std_ulogic;

		--Counter is at the max value
		counter_top : out std_ulogic);
end entity;

architecture rtl of sat_counter is

begin

end;