library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.math_real.all;

library lib_azimuth;
	use lib_azimuth.realtime_math.all;
	use lib_azimuth.address_math.bits_required;

--Uart TX with fixed configuration
entity uart_rx_fixed_config is
	generic (
		CLK_HZ : natural := 100e6;
		TX_HZ : natural := 115200;
		START_BITS : positive := 1;
		DATA_BITS : positive := 8;
		STOP_BITS : positive := 1;
		USE_PARITY : boolean := false;
		EVEN_PARITY : boolean := false);
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--Data
		rx_data : out std_ulogic_vector(DATA_BITS - 1 downto 0);
		rx_data_valid : out std_ulogic;
		rx_data_ready : std_ulogic;

		--Phy
		rx : std_ulogic);
end entity;

architecture rtl of uart_rx_fixed_config is
	constant fixed_divider : natural := clock_divider_int(CLK_HZ, TX_HZ);
	constant bits_required : natural := lib_azimuth.address_math.bits_required(fixed_divider);

	constant divider : unsigned(bits_required - 1 downto 0) := to_unsigned(fixed_divider, bits_required);

	signal rx_data_padded : std_ulogic_vector(9 downto 0);
begin
	assert clock_divider_error(CLK_HZ, TX_HZ) < 0.03 
		report "Implausible to produce desired baud rate from provided clock!" severity error;

	rx_data <= rx_data_padded(DATA_BITS - 1 downto 0);

	device: entity lib_azimuth.uart_tx
	port map (
		clk => clk,
		rst => rst,

		divider => divider,
		start_bits => START_BITS,
		data_bits => DATA_BITS,
		stop_bits => STOP_BITS,
		use_parity => USE_PARITY,
		even_parity => EVEN_PARITY,

		rx_data => rx_data_padded,
		rx_data_valid => rx_data_valid,
		rx_data_ready => rx_data_ready,

		tx => rx);
end architecture;