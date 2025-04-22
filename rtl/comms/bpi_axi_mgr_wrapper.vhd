library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.bpi.all;
	use lib_azimuth.bpi_axi.all;

entity bpi_axi_mgr_wrapper is
	generic (
		FIFO_DEPTH : natural := 32);
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--BPI interface
		bpi_in : std_ulogic_vector(7 downto 0);
		bpi_out : out std_ulogic_vector(7 downto 0);
		bpi_in_valid : std_ulogic;
		bpi_in_ready : out std_ulogic;
		bpi_out_valid : out std_ulogic;
		bpi_out_ready : std_ulogic;

		--AXI Manager
		m_axi_awaddr : out std_ulogic_vector(31 downto 0);
		m_axi_awvalid : out std_ulogic;
		m_axi_awready : std_ulogic;

		m_axi_wdata : out std_ulogic_vector(31 downto 0);
		m_axi_wstrb : out std_ulogic_vector(3 downto 0);
		m_axi_wvalid : out std_ulogic;
		m_axi_wready : std_ulogic;

		m_axi_bresp : std_ulogic_vector(1 downto 0);
		m_axi_bvalid : std_ulogic;
		m_axi_bready : out std_ulogic;

		m_axi_araddr : out std_ulogic_vector(31 downto 0);
		m_axi_arvalid : out std_ulogic;
		m_axi_arready : std_ulogic;

		m_axi_rdata : std_ulogic_vector(31 downto 0);
		m_axi_rresp : std_ulogic_vector(1 downto 0);
		m_axi_rvalid : std_ulogic;
		m_axi_rready : out std_ulogic);
end entity;

architecture rtl of bpi_axi_mgr_wrapper is
	signal bpi_in_ready_buf : std_ulogic;
	signal bpi_out_valid_buf : std_ulogic;
	signal m_axi_awaddr_buf : std_ulogic_vector(31 downto 0);
	signal m_axi_awvalid_buf : std_ulogic;
	signal m_axi_wdata_buf : std_ulogic_vector(31 downto 0);
	signal m_axi_wvalid_buf : std_ulogic;
	signal m_axi_bready_buf : std_ulogic;
	signal m_axi_araddr_buf : std_ulogic_vector(31 downto 0);
	signal m_axi_arvalid_buf : std_ulogic;
	signal m_axi_rready_buf : std_ulogic;
begin
	bpi_in_ready <= bpi_in_ready_buf;
	bpi_out_valid <= bpi_out_valid_buf;
	m_axi_awaddr <= m_axi_awaddr_buf;
	m_axi_awvalid <= m_axi_awvalid_buf;
	m_axi_wdata <= m_axi_wdata_buf;
	m_axi_wvalid <= m_axi_wvalid_buf;
	m_axi_bready <= m_axi_bready_buf;
	m_axi_araddr <= m_axi_araddr_buf;
	m_axi_arvalid <= m_axi_arvalid_buf;
	m_axi_rready <= m_axi_rready_buf;

	inner: entity lib_azimuth.bpi_axi_mgr
	generic map (
		FIFO_DEPTH => FIFO_DEPTH)
	port map (
		clk => clk,
		rst => rst,

		bpi_in => bpi_in,
		bpi_out => bpi_out,
		bpi_in_valid => bpi_in_valid,
		bpi_in_ready => bpi_in_ready_buf,
		bpi_out_valid => bpi_out_valid_buf,
		bpi_out_ready => bpi_out_ready,

		m_axi_awaddr => m_axi_awaddr_buf,
		m_axi_awvalid => m_axi_awvalid_buf,
		m_axi_awready => m_axi_awready,

		m_axi_wdata => m_axi_wdata_buf,
		m_axi_wstrb => m_axi_wstrb,
		m_axi_wvalid => m_axi_wvalid_buf,
		m_axi_wready => m_axi_wready,

		m_axi_bresp => m_axi_bresp,
		m_axi_bvalid => m_axi_bvalid,
		m_axi_bready => m_axi_bready_buf,

		m_axi_araddr => m_axi_araddr_buf,
		m_axi_arvalid => m_axi_arvalid_buf,
		m_axi_arready => m_axi_arready,

		m_axi_rdata => m_axi_rdata,
		m_axi_rresp => m_axi_rresp,
		m_axi_rvalid => m_axi_rvalid,
		m_axi_rready => m_axi_rready_buf);
end architecture;