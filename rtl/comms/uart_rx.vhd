library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.realtime_math.all;

entity uart_rx is
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--Configuration
		divider : unsigned;
		start_bits : positive range 1 to 2;
		data_bits : positive range 5 to 10;
		stop_bits : positive range 1 to 2;
		use_parity : boolean := false;
		even_parity : boolean := true;

		--Data
		rx_data : out std_ulogic_vector(9 downto 0);
		rx_data_valid : out std_ulogic;
		rx_data_ready : std_ulogic;

		--Phy
		rx : std_ulogic);
end entity;

architecture rtl of uart_rx is
	--Received data shift register
	subtype shiftreg_t is std_ulogic_vector(7 downto 0);
	signal shiftreg : shiftreg_t := (others => '1');

	--Current divider count
	signal divider_count : natural;

	--Whether this is the first cycle of baud_divider
	signal first_count : boolean;

	--Sample enable offset by half a cycle
	signal half_count : boolean;

	--RX sample enable
	signal rx_clken : std_ulogic;

	--Falling edge detected
	signal rx_buf : std_ulogic := '1';
	signal rx_falling : boolean;

	--Bit counter
	signal counter : unsigned(3 downto 0) := (others => '0');
	signal rx_start_ready : boolean;
	signal not_started : std_ulogic;
	signal started : std_ulogic;

	--Enable sampling on data or parity bits
	signal sample_en : boolean;

	impure function total_bits return positive is
		variable parity_bit : natural;
	begin
		if use_parity then
			parity_bit := 1;
		else
			parity_bit := 0;
		end if;

		return start_bits + data_bits + parity_bit + stop_bits;
	end function;
begin
	sample_en <= counter > stop_bits and counter <= stop_bits + data_bits;

	rx_falling <= rx = '0' and rx_buf = '1';
	rx_start_ready <= counter = 0;

	started <= '0' when rx_start_ready else '1';
	not_started <= not started;

	first_count <= counter = to_unsigned(total_bits, counter'length);
	half_count <= to_unsigned(divider_count, divider'length - 1) = divider(divider'left downto 1);

	baud_divider: entity lib_azimuth.clock_enable_divider
	generic map (
		FIRST_CYCLE => false,
		CHANGE_DIVIDER_IMMEDIATELY => true)
	port map (
		clk => clk,
		rst => not_started,
		divider => divider,
		clkdiv_en => rx_clken,
		count => divider_count);

	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				rx_buf <= '1';
				counter <= (others => '0');
				shiftreg <= (others => '1');
			else
				rx_buf <= rx;

				--Start on falling edge
				if rx_start_ready and rx_falling then
					counter <= to_unsigned(total_bits, counter'length);
				end if;

				--First count down is half duration, sample on center of bit
				if started = '1' and ((first_count and rx_clken = '1') or half_count) then
					--Count down and shift in data
					counter <= counter - 1;

					if sample_en then
						shiftreg <= rx_buf & shiftreg(shiftreg'left downto 1);
					end if;
				else

				end if;
			end if;
		end if;
	end process;
end architecture;