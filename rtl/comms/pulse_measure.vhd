--Pulse width measurement utility

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.address_math.all;
	use lib_azimuth.realtime_math.all;

entity pulse_measure is
	generic (
		MAX_CLK_HZ : natural;
		MAX_DETECT_PERIOD : real);
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--Configuration
		--TODO
		reject_width : natural;

		--Input
		pulse_in : std_ulogic;

		--Output
		pulse_width_high : out 
			unsigned(cycles_counter_width(MAX_CLK_HZ, MAX_DETECT_PERIOD) - 1 downto 0);
		pulse_width_high_valid : out std_ulogic := '0';

		pulse_width_low : out 
			unsigned(cycles_counter_width(MAX_CLK_HZ, MAX_DETECT_PERIOD) - 1 downto 0);
		pulse_width_low_valid : out std_ulogic  := '0');
end entity;

architecture rtl of pulse_measure is
	constant counter_bits : natural :=
		cycles_counter_width(MAX_CLK_HZ, MAX_DETECT_PERIOD);

	subtype counter_t is unsigned(counter_bits - 1 downto 0);
	constant counter_max : counter_t := (others => '1');

	signal high_counter : counter_t := (others => '0');
	signal low_counter : counter_t := (others => '0');
begin
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				high_counter <= (others => '0');
				low_counter <= (others => '0');

				pulse_width_low_valid <= '0';
				pulse_width_high_valid <= '0';
			else
				if pulse_in = '1' then
					low_counter <= (others => '0');
					pulse_width_low <= low_counter;
					pulse_width_low_valid <= '1';

					if high_counter /= counter_max then
						high_counter <= high_counter + 1;
					end if;
				else
					high_counter <= (others => '0');
					pulse_width_high <= high_counter;
					pulse_width_high_valid <= '1';

					if low_counter /= counter_max then
						low_counter <= low_counter + 1;
					end if;
				end if;
			end if;
		end if;
	end process;
end architecture;