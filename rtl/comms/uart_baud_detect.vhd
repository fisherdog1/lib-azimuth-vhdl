--Baud rate detector for uart receiver
--Calculates the integer divider needed to make the narrowest observed pulse on RX

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.realtime_math.all;
	use lib_azimuth.address_math.all;

entity uart_baud_detect is
	generic (
		--Max clk frequency and minimum detectable baud rate
		--Used to determine the max detectable pulse width
		MAX_CLK_HZ : natural := 25e6;
		MIN_DETECT_HZ : natural := 1200;

		--Max allowed value of bits_per_word
		--Used to determine size of total width counter
		MAX_BITS_PER_WORD : natural := 10;

		--When true, recover the data of the word used for auto-bauding
		RECOVER_FIRST_WORD : boolean := true);
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--Signal to detect the bit rate of
		rx : std_ulogic;

		--Number of bits in a word
		bits_per_word : unsigned(bits_required(MAX_BITS_PER_WORD) - 1 downto 0)
			:= to_unsigned(9, 4); --Temporary

		--Number of clock cycles per bit at detected baud rate
		divider : out unsigned(
			bits_required(get_clock_divider_int(MAX_CLK_HZ, MIN_DETECT_HZ)) - 1 downto 0);
		divider_valid : out std_ulogic;

		--Data of first word, when RECOVER feature enabled
		data_first : out std_ulogic_vector(MAX_BITS_PER_WORD - 1 downto 0);
		data_first_valid : out std_ulogic);
end entity;

architecture rtl of uart_baud_detect is
	--Calculate needed counter sizes and max values
	constant width_counter_sat_level : natural := get_clock_divider_int(MAX_CLK_HZ, MIN_DETECT_HZ);
	constant total_counter_sat_level : natural := width_counter_sat_level * MAX_BITS_PER_WORD;

	subtype width_counter_t is unsigned(bits_required(width_counter_sat_level) - 1 downto 0);
	subtype total_counter_t is unsigned(bits_required(total_counter_sat_level) - 1 downto 0);

	constant width_counter_sat : width_counter_t := to_unsigned(width_counter_sat_level, width_counter_t'length);
	constant total_counter_sat : total_counter_t := to_unsigned(total_counter_sat_level, total_counter_t'length);

	--Edge detector signals
	signal rx_buf : std_ulogic := '1';
	signal edge : boolean;

	--Total width observed since starting
	signal total_width : total_counter_t := total_counter_sat;

	--Estimated word width based on smallest observed pulse
	signal estimated_word_width_sat : width_counter_t;
	signal estimated_word_width :
		unsigned(bits_per_word'length + width_counter_t'length - 1 downto 0);

	signal width_counter : width_counter_t := width_counter_sat;
	signal width_counter_prev : width_counter_t := width_counter_sat;

	signal width_saturated : boolean;
	signal total_saturated : boolean;

	--When recording previous pulses, only enough resolution is required
	--to disambiguate in the worst case of bad estimation, i.e. ..10000000101..
	--The estimate in this case is 7 times what it should be
	--Truncate the first estimate to 4 bits, which should be more than enough
	subtype prev_pulse_t is unsigned(3 downto 0);
	type prev_pulse_array_t is array (0 to MAX_BITS_PER_WORD - 1) of prev_pulse_t;
	subtype prev_pulse_ptr_t is natural range 0 to MAX_BITS_PER_WORD;
	signal prev_pulses : prev_pulse_array_t := (others => (others => '0'));
	signal prev_pulse_ptr : prev_pulse_ptr_t := 0;

	subtype width_index_t is natural range 3 to width_counter_t'left;
	signal width_index : width_index_t := width_counter_t'left;
	signal width_counter_prev_msb : prev_pulse_t;

	--Gobbler turns pulse widths into data bits
	subtype shiftreg_t is std_ulogic_vector(MAX_BITS_PER_WORD - 1 downto 0);
	signal enable_pulse_gobbler : std_ulogic := '0';
	signal pulse_gobbler_done : std_ulogic := '0';
	signal gobbler_polarity : std_ulogic_vector(0 downto 0) := "0";
	signal data_first_shiftreg : shiftreg_t := (others => '0');

	procedure gobble_pulses(
		signal pulses : inout prev_pulse_array_t; 
		signal ptr : inout prev_pulse_ptr_t;
		signal shiftreg : inout shiftreg_t;
		signal polarity : inout std_ulogic_vector;
		signal done : out std_ulogic) 
	is
		variable current_pulse_width : prev_pulse_t;
		variable three_quarter : prev_pulse_t;
		variable new_ptr : prev_pulse_ptr_t;
	begin
		current_pulse_width := pulses(ptr);
		new_ptr := ptr;
		three_quarter := resize(
			width_counter_prev_msb(prev_pulse_t'left downto 1) +
			width_counter_prev_msb(prev_pulse_t'left downto 2), three_quarter'length);

		if current_pulse_width > three_quarter then
			if width_counter_prev_msb <= current_pulse_width then
				current_pulse_width := current_pulse_width - width_counter_prev_msb;
			else
				current_pulse_width := to_unsigned(0, current_pulse_width'length);
			end if;

			shiftreg <= polarity & shiftreg(shiftreg_t'left downto 1);
		else
			current_pulse_width := to_unsigned(0, prev_pulse_t'length);
			polarity <= not polarity;
			new_ptr := prev_pulse_ptr + 1;
		end if;

		if to_unsigned(new_ptr, bits_per_word'length) > bits_per_word then
			ptr <= 0;
			done <= '1';
		else
			ptr <= new_ptr;
		end if;

			pulses(ptr) <= current_pulse_width;
	end procedure;

	--Extract four most significant bits from unsigned
	procedure extract_4_msb(
		variable extracted : out prev_pulse_t;
		signal new_index : out width_index_t; 
		signal v : width_counter_t) 
	is
		variable msb : natural;
	begin
		--Has width range not been estimated yet?
		if width_index = width_counter_t'left then
			for I in v'left downto 3 loop
				msb := I;

				if v(I) = '1' then
					new_index <= I;
					exit;	
				end if;
			end loop;
		else
			msb := width_index;
		end if;

		extracted := v(msb downto msb - 3);
	end procedure;
begin
	--Edge detector
	edge <= (rx xor rx_buf) = '1';
	width_saturated <= width_counter = width_counter_sat_level;
	total_saturated <= total_width = total_counter_sat_level;

	--Estimate when the end of the word will be
	estimated_word_width <= 
		bits_per_word * width_counter_prev
		+ width_counter_prev(width_counter_t'length - 1 downto 1);

	estimated_word_width_sat <= 
		(others => '1') when estimated_word_width >= width_counter_sat_level 
		else estimated_word_width(width_counter_t'left downto 0);

	width_counter_prev_msb <= width_counter_prev(width_index downto width_index - 3);

	process (clk)
		variable prev : prev_pulse_t;
	begin
		if rising_edge(clk) then
			if rst = '1' then
				rx_buf <= '1';
				total_width <= total_counter_sat;
				width_counter <= width_counter_sat;
				width_counter_prev <= width_counter_sat;
				divider_valid <= '0';

				enable_pulse_gobbler <= '0';
				pulse_gobbler_done <= '0';
				width_index <= width_counter_t'left;
			else
				rx_buf <= rx;

				--Saturating counter measuring pulse width
				if width_counter < width_counter_sat then
					width_counter <= width_counter + 1;
				end if;

				if total_width < total_counter_sat then
					total_width <= total_width + 1;
				end if;

				--TODO: accept after 6 nearly identical pulse widths, too
				if total_width >= estimated_word_width then
					--It's likely no more pulses are coming
					--output divider value
					divider <= width_counter_prev;
				end if;

				if edge then
					--If width too high, ignore this edge
					if total_width < estimated_word_width then
						--Measure this pulse,
						--If lower than previous count, replace previous count
						if width_counter < width_counter_prev then
							width_counter_prev <= width_counter;
						end if;

						--Record pulse width
						if not total_saturated then
							extract_4_msb(prev, width_index, width_counter);
							prev_pulses(prev_pulse_ptr) <= prev;
							prev_pulse_ptr <= prev_pulse_ptr + 1;
						end if;
					else
						--Rearm detection
						total_width <= (others => '0');
						prev_pulse_ptr <= 0;

						if not total_saturated then
							--Start pulse gobbler
							enable_pulse_gobbler <= '1';
							gobbler_polarity <= "0";
							data_first_shiftreg <= (others => '0');
						end if;
					end if;

					--Reset counter
					width_counter <= (others => '0');
				end if;

				if pulse_gobbler_done = '1' then
					--Reset regs used by gobbler
					prev_pulse_ptr <= 0;
					data_first <= "00" & data_first_shiftreg(9 downto 2);
					enable_pulse_gobbler <= '0';
					pulse_gobbler_done <= '0';
					width_counter_prev <= width_counter_sat;
					width_index <= width_counter'left;
					divider_valid <= '1';
				elsif enable_pulse_gobbler = '1' then
					gobble_pulses(prev_pulses, prev_pulse_ptr, data_first_shiftreg, gobbler_polarity, pulse_gobbler_done);
				end if;
			end if;
		end if;
	end process;
end architecture;