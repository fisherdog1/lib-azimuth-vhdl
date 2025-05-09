library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.math_real.all;

library lib_azimuth;
	use lib_azimuth.realtime_math.all;
	use lib_azimuth.address_math.bits_required;

--Uart TX with fixed configuration
entity uart_tx_fixed_config is
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
		tx_data : std_ulogic_vector(DATA_BITS - 1 downto 0);
		tx_data_valid : std_ulogic;
		tx_data_ready : out std_ulogic;

		--Phy
		tx : out std_ulogic);
end entity;

architecture rtl of uart_tx_fixed_config is
	constant fixed_divider : natural := clock_divider_int(CLK_HZ, TX_HZ);
	constant bits_required : natural := lib_azimuth.address_math.bits_required(fixed_divider);

	constant divider : unsigned(bits_required - 1 downto 0) := to_unsigned(fixed_divider, bits_required);

	signal tx_data_padded : std_ulogic_vector(9 downto 0);
	signal tx_data_ready_buf : std_ulogic;
begin
	assert clock_divider_error(CLK_HZ, TX_HZ) < 0.03 
		report "Implausible to produce desired baud rate from provided clock!" severity error;

	tx_data_padded(DATA_BITS - 1 downto 0) <= tx_data(DATA_BITS - 1 downto 0);
	tx_data_ready <= tx_data_ready_buf;

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

		tx_data => tx_data_padded,
		tx_data_valid => tx_data_valid,
		tx_data_ready => tx_data_ready_buf,

		tx => tx);
end architecture;