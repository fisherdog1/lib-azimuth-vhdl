library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.bpi.all;
	use lib_azimuth.bpi_axi.all;

entity bpi_axi_mgr is
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
		bpi_in_ready : buffer std_ulogic;
		bpi_out_valid : buffer std_ulogic;
		bpi_out_ready : std_ulogic;

		--AXI Manager
		m_axi_awaddr : buffer std_ulogic_vector(31 downto 0);
		m_axi_awvalid : buffer std_ulogic := '0';
		m_axi_awready : std_ulogic;

		m_axi_wdata : buffer std_ulogic_vector(31 downto 0);
		m_axi_wstrb : out std_ulogic_vector(3 downto 0);
		m_axi_wvalid : buffer std_ulogic := '0';
		m_axi_wready : std_ulogic;

		m_axi_bresp : std_ulogic_vector(1 downto 0);
		m_axi_bvalid : std_ulogic;
		m_axi_bready : buffer std_ulogic := '0';

		m_axi_araddr : buffer std_ulogic_vector(31 downto 0)
			:= (others => '0');
		m_axi_arvalid : buffer std_ulogic := '0';
		m_axi_arready : std_ulogic;

		m_axi_rdata : std_ulogic_vector(31 downto 0);
		m_axi_rresp : std_ulogic_vector(1 downto 0);
		m_axi_rvalid : std_ulogic;
		m_axi_rready : buffer std_ulogic := '0');
end entity;

architecture rtl of bpi_axi_mgr is
	--BPI interface
	signal bpi_frontend_if_in : bpi_frontend_if_in_t;
	signal bpi_frontend_if_out : bpi_frontend_if_out_t;

	--Command space
	signal write_command_ready : std_ulogic;
	signal write_command_valid : std_ulogic;

	--Response space
	signal read_response : bpi_byte;
	signal read_response_valid : std_ulogic;
	signal read_response_ready : std_ulogic;

	--Backend selection
	--Frontend <-> Selected <-> Back
	signal front_to_selected_if : bpi_frontend_to_backend_t;
	signal selected_to_front_if : bpi_backend_to_frontend_t;

	--Backend signals
	--For testing, backend 0 is connected and backend 1 does nothing
	constant NUM_BACKENDS : natural := 2;
	subtype backend_index_t is natural range 0 to NUM_BACKENDS - 1;

	signal backend_index : backend_index_t := 0;
	signal selected_to_backends : bpi_frontend_to_backend_array(0 to NUM_BACKENDS - 1);
	signal backends_to_selected : bpi_backend_to_frontend_array(0 to NUM_BACKENDS - 1);
begin
	--BPI frontend signals group
	bpi_frontend_if_in.bpi_in <= bpi_in;
	bpi_frontend_if_in.bpi_in_valid <= bpi_in_valid;
	bpi_frontend_if_in.bpi_out_ready <= bpi_out_ready;

	--Muxing between frontend and command space
	front_to_selected_if.command <= bpi_in;
	front_to_selected_if.command_valid <= bpi_frontend_if_out.write_command and bpi_in_valid;
	bpi_in_ready <= selected_to_front_if.command_ready when bpi_frontend_if_out.write_command = '1' else bpi_frontend_if_out.bpi_in_ready;

	--Muxing between frontend and response space
	bpi_out <= selected_to_front_if.response when bpi_frontend_if_out.read_response = '1' else bpi_frontend_if_out.bpi_out;
	bpi_out_valid <= selected_to_front_if.response_valid when bpi_frontend_if_out.read_response = '1' else bpi_frontend_if_out.bpi_out_valid;
	front_to_selected_if.response_ready <= bpi_out_ready and bpi_frontend_if_out.read_response;

	--Mux/Demux to selected backend
	process (backend_index, backends_to_selected, front_to_selected_if)
	begin
	    --To backends...
		for i in 0 to NUM_BACKENDS - 1 loop
			if i = backend_index then
			    --...of which only one is selected
				selected_to_backends(i) <= front_to_selected_if;
			else
				selected_to_backends(i) <= bpi_frontend_to_backend_tieoff;
			end if;
		end loop;
		
		--From selected backend
		selected_to_front_if <= backends_to_selected(backend_index); 
	end process;

	--Generate backend memories
	backend_fifo: for i in 0 to NUM_BACKENDS - 1 generate
		write_fifo: entity work.sync_fifo
		generic map (
			WIDTH => 8,
			DEPTH => FIFO_DEPTH)
		port map (
			clk => clk,
			rst => rst,

			--From frontend
			write_data => selected_to_backends(i).command,
			write_data_valid => selected_to_backends(i).command_valid,
			write_data_ready => backends_to_selected(i).command_ready,

			--To selected backend
			read_data => open,
			read_data_valid => open,
			read_data_ready => '0');

		read_fifo: entity work.sync_fifo
		generic map (
			WIDTH => 8,
			DEPTH => FIFO_DEPTH)
		port map (
			clk => clk,
			rst => rst,

			--From selected backend
			write_data => (others => '0'),
			write_data_valid => '0',
			write_data_ready => open,

			--To frontend
			read_data => backends_to_selected(i).response,
			read_data_valid => backends_to_selected(i).response_valid,
			read_data_ready => selected_to_backends(i).response_ready);
	end generate;

	process (clk)
	   variable bpi_state : bpi_state_t := bpi_state_init;
	begin
		if rising_edge(clk) then
			if rst = '1' then
				bpi_state := bpi_state_init;
				bpi_frontend_if_out <= bpi_frontend_init;
				backend_index <= 0;
			else
                bpi_frontend(bpi_state, bpi_frontend_if_in, bpi_frontend_if_out);
			end if;
		end if;
	end process;
end architecture;