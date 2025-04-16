library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.realtime_math.all;
	use lib_azimuth.address_math.all;

entity uart_rx_autobaud is
	generic (
		--Max clk frequency and minimum detectable baud rate
		--Used to determine the max detectable pulse width
		MAX_CLK_HZ : natural;
		MIN_DETECT_BAUD : natural;

		--When true, recover the data of the word used for auto-bauding
		RECOVER_FIRST_WORD : boolean);
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--Configuration
		divider_override : 
			unsigned(bits_required(get_clock_divider_int(MAX_CLK_HZ, MIN_DETECT_BAUD)) - 1 downto 0);
		divider_override_valid : std_ulogic;

		start_bits : positive range 1 to 2;
		data_bits : positive range 5 to 10;
		stop_bits : positive range 1 to 2;
		use_parity : boolean := true;
		even_parity : boolean := false;

		--Data
		rx_data : buffer std_ulogic_vector(9 downto 0);
		rx_data_valid : buffer std_ulogic;
		rx_data_ready : std_ulogic;

		--Phy
		rx : std_ulogic);
end entity;

architecture rtl of uart_rx_autobaud is
	constant divider_bits : natural := divider_override'length;
	constant MAX_BITS_PER_WORD : natural := 10;

	signal parity_bit : natural;
	signal data_bits_except_start : natural;
	signal unsigned_data_bits_except_start :
		unsigned(bits_required(MAX_BITS_PER_WORD) - 1 downto 0);

	signal divider, detected_divider : unsigned(divider_bits - 1 downto 0);
	signal divider_valid, detected_divider_valid : std_ulogic;

	signal rx_mutable : std_ulogic;

	signal data_first : std_ulogic_vector(9 downto 0);
	signal data_first_valid : std_ulogic;
	signal data_first_arm : std_ulogic := '1';

	signal rx_data_temp : std_ulogic_vector(9 downto 0);
	signal rx_data_valid_temp : std_ulogic;
begin
	parity_bit <= 1 when use_parity else 0;
	data_bits_except_start <= data_bits + parity_bit + stop_bits;
	unsigned_data_bits_except_start <= 
		to_unsigned(data_bits_except_start, unsigned_data_bits_except_start'length);

	--Allow manual divider control
	divider <= divider_override when divider_override_valid = '1' else detected_divider;
	divider_valid <= '1' when divider_override_valid = '1' else detected_divider_valid;

	--Mute the receiver while baud rate is being determined
	rx_mutable <= rx when divider_valid = '1' or divider_override_valid = '1' else '1';

	basic_rx: entity work.uart_rx
	port map (
		clk => clk,
		rst => rst,

		divider => divider,
		start_bits => start_bits,
		data_bits => data_bits,
		stop_bits => stop_bits,
		use_parity => use_parity,
		even_parity => even_parity,

		rx_data => rx_data_temp,
		rx_data_valid => rx_data_valid_temp,
		rx_data_ready => '1',

		rx => rx_mutable);

	detector: entity work.uart_baud_detect
	generic map (
		MAX_CLK_HZ => MAX_CLK_HZ,
		MIN_DETECT_HZ => MIN_DETECT_BAUD,
		MAX_BITS_PER_WORD => MAX_BITS_PER_WORD,
		RECOVER_FIRST_WORD => RECOVER_FIRST_WORD)
	port map (
		clk => clk,
		rst => rst,

		rx => rx,
		bits_per_word => unsigned_data_bits_except_start,

		divider => detected_divider,
		divider_valid => detected_divider_valid,

		data_first => data_first,
		data_first_valid => data_first_valid);

	process (clk)
	begin
		if rising_edge(clk) then
			if rst ='1' then
				rx_data_valid <= '0';
				data_first_arm <= '1';
			else
				--Accept a read
				if rx_data_valid = '1' and rx_data_ready = '1' then
					rx_data_valid <= '0';
				end if;

				--Take data from baud first word recovery, otherwise from receiver
				if rx_data_valid_temp = '1' then
					rx_data <= rx_data_temp;
					rx_data_valid <= '1';
				elsif data_first_valid = '1' and data_first_arm = '1' then
					rx_data <= data_first;
					rx_data_valid <= '1';
					data_first_arm <= '0';
				end if;
			end if;
		end if;
	end process;
end architecture;