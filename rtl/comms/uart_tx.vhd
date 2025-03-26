library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.realtime_math.all;

entity uart_tx is
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
		tx_data : std_ulogic_vector(9 downto 0);
		tx_data_valid : std_ulogic;
		tx_data_ready : buffer std_ulogic;

		--Phy
		tx : out std_ulogic);
end entity;

architecture rtl of uart_tx is
	subtype shiftreg_t is std_ulogic_vector(14 downto 0);
	signal tx_clken : std_ulogic;
	signal tx_accept : boolean;
	signal shiftreg : shiftreg_t := (others => '1');
	signal counter : unsigned(3 downto 0) := (others => '0');

	impure function get_parity return std_ulogic is
		variable temp : std_ulogic := '0';
		variable taps : std_ulogic_vector(tx_data'range);
	begin
		parity_chain: for i in tx_data'low to tx_data'high loop
			temp := temp xor tx_data(i);
			taps(i) := temp;
		end loop;

		parity_sel: temp := taps(data_bits - 1);

		parity_polarity_sel: if even_parity then
			return not temp;
		else
			return temp;
		end if;
	end function;

	impure function shiftreg_load_value return shiftreg_t is
		variable temp : shiftreg_t := (others => '1');
	begin
		temp(start_bits - 1 downto 0) := (others => '0');
		temp((start_bits + data_bits - 1) downto start_bits) := tx_data(data_bits - 1 downto 0);

		if use_parity then
			temp(start_bits + data_bits) := get_parity;
		end if;

		return temp;
	end function;

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
	tx_data_ready <= '1' when counter = 0 and rst = '0' and tx_clken = '1' else '0';
	tx_accept <= (tx_data_valid and tx_data_ready) = '1';
	tx <= shiftreg(0);

	baud_divider: entity lib_azimuth.clock_enable_divider
	generic map (
		FIRST_CYCLE => true,
		CHANGE_DIVIDER_IMMEDIATELY => true)
	port map (
		clk => clk,
		rst => rst,
		divider => divider,
		clkdiv_en => tx_clken);

	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				shiftreg <= (others => '1');
				counter <= (others => '0');

			elsif tx_clken = '1' then
				if tx_accept then
					counter <= to_unsigned(total_bits - 1, counter'length);
					shiftreg <= shiftreg_load_value;
				else
					counter <= counter - 1;
					shiftreg <= "1" & shiftreg(shiftreg_t'left downto 1);
				end if;
			end if;
		end if;
	end process;
end architecture rtl;
