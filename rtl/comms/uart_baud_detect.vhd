--Baud rate detector for uart receiver
--Calculates the integer divider needed to make the narrowest observed pulse on RX

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.realtime_math.all;

entity uart_baud_detect is
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		rx : std_ulogic;
		divider : out unsigned;
		divider_valid : out std_ulogic);
end entity;

architecture rtl of uart_baud_detect is
	signal rx_buf : std_ulogic := '1';
	signal edge : boolean;

	subtype width_counter_t is unsigned(divider'length - 1 downto 0);
	constant width_counter_sat_level : width_counter_t := (others => '1');

	constant bits_per_word : 
		unsigned(3 downto 0) := to_unsigned(9, 4); --8 + start

	--Total width observed since starting
	signal total_width : width_counter_t := (others => '0');

	--Estimated word width based on smallest observed pulse
	signal estimated_word_width_sat : width_counter_t;
	signal estimated_word_width :
		unsigned(bits_per_word'length + divider'length - 1 downto 0);

	signal width_counter : width_counter_t := (others => '1');
	signal width_counter_prev : width_counter_t := (others => '1');
	signal width_saturated : boolean;
begin
	--Edge detector
	edge <= (rx xor rx_buf) = '1';
	width_saturated <= width_counter = width_counter_sat_level;

	--Estimate when the end of the word will be
	estimated_word_width <= 
		bits_per_word * width_counter_prev
		+ width_counter_prev(width_counter_t'length - 1 downto 1);

	estimated_word_width_sat <= 
		(others => '1') when estimated_word_width >= width_counter_sat_level 
		else estimated_word_width(width_counter_t'left downto 0);

	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				rx_buf <= '1';
				total_width <= (others => '0');
				width_counter <= (others => '1');
				width_counter_prev <= (others => '1');
				divider_valid <= '0';
			else
				rx_buf <= rx;

				--Saturating counter measuring pulse width
				if width_counter < width_counter_sat_level then
					width_counter <= width_counter + 1;
				end if;

				if total_width < width_counter_sat_level then
					total_width <= total_width + 1;
				end if;

				--TODO: accept after 6 nearly identical pulse widths, too
				if total_width >= estimated_word_width then
					--It's likely no more pulses are coming
					--output divider value
					divider <= width_counter_prev;
					divider_valid <= '1';
				end if;

				if edge then
					--If width too high, ignore this edge
					if total_width < estimated_word_width then
						--Measure this pulse,
						--If lower than previous count, replace previous count
						if width_counter < width_counter_prev then
							width_counter_prev <= width_counter;
						end if;
					else
						--Rearm detection
						total_width <= (others => '0');
						width_counter_prev <= (others => '1');
					end if;

					--Reset counter
					width_counter <= (others => '0');
				end if;
			end if;
		end if;
	end process;
end architecture;