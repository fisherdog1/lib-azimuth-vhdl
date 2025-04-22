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
	signal bpi_state : bpi_state_t := bpi_state_init;
	signal bpxi_state : bpxi_state_t := bpxi_state_init;

	--BPI interface side of write fifo
	signal write_fifo_we : std_ulogic;
	signal write_fifo_ready : std_ulogic;

	--Unused
	signal write_fifo_overflow : std_ulogic;

	--Exec side of write fifo
	signal write_fifo_data : std_ulogic_vector(7 downto 0);
	signal write_fifo_data_valid : std_ulogic;
	signal write_fifo_data_ready : std_ulogic := '0';

	--BPI interface side of read fifo
	signal read_fifo_valid : std_ulogic;
	signal read_fifo_ready : std_ulogic;

	--Exec side of read fifo
	signal read_fifo_data : std_ulogic_vector(7 downto 0);
	signal read_fifo_data_ready : std_ulogic;
	signal read_fifo_data_valid : std_ulogic := '0';
begin
	--Accept data when waiting for command bytes or fifo data
	bpi_in_ready <= '1' when 
		(not bpi_state.command_valid 
		and not bpi_state.pop_read_fifo)
		or bpi_state.push_write_fifo 
		else '0';

	write_fifo_we <= '1' when bpi_state.push_write_fifo and bpi_in_valid = '1' else '0';
	write_fifo_overflow <= write_fifo_we and not write_fifo_ready;

	bpi_out_valid <= read_fifo_valid when bpi_state.pop_read_fifo else '0';
	read_fifo_ready <= bpi_out_ready when bpi_state.pop_read_fifo else '0';

	write_fifo: entity work.sync_fifo
	generic map (
		WIDTH => 8,
		DEPTH => FIFO_DEPTH)
	port map (
		clk => clk,
		rst => rst,

		--Loads data from bpi in when a write data command is used
		write_data => bpi_in,
		write_data_valid => write_fifo_we,
		write_data_ready => write_fifo_ready,

		--Reads data to execute commands
		read_data => write_fifo_data,
		read_data_valid => write_fifo_data_valid,
		read_data_ready => write_fifo_data_ready);

	read_fifo: entity work.sync_fifo
	generic map (
		WIDTH => 8,
		DEPTH => FIFO_DEPTH)
	port map (
		clk => clk,
		rst => rst,

		--Response data
		write_data => read_fifo_data,
		write_data_valid => read_fifo_data_valid,
		write_data_ready => read_fifo_data_ready,

		--To peripheral
		--TODO: must be triggered by a Read Data command and a specific
		--number of bytes provided.
		read_data => bpi_out,
		read_data_valid => read_fifo_valid,
		read_data_ready => read_fifo_ready);

	process (clk)
		variable bpxi_op : bpxi_operation;
		variable shift_done : boolean;
		variable axi_done : boolean;
		variable bpxi_state_temp : bpxi_state_t;
		variable bpi_state_temp : bpi_state_t;
		variable shift_ctr : natural range 0 to 7;

		variable m_axi_araddr_temp, m_axi_rdata_temp : std_ulogic_vector(31 downto 0);

		--Wrappers for shift_in_byte / shift_out_byte
		procedure shift_in(
			variable s : inout std_ulogic_vector;
			count : natural;
			variable done : out boolean) is
		begin
			shift_in_byte(
				s,
				write_fifo_data,
				write_fifo_data_ready,
				write_fifo_data_valid,
				shift_ctr,
				count,
				done);
		end procedure;

		procedure shift_out(
			variable s : inout std_ulogic_vector;
			count : natural;
			variable done : out boolean) is
		begin
			shift_out_byte(
				s,
				read_fifo_data,
				read_fifo_data_ready, 
				read_fifo_data_valid,
				shift_ctr,
				count,
				done);
		end procedure;
	begin
	if rising_edge(clk) then
	if rst = '1' then
		bpi_state <= bpi_state_init;
		bpxi_state <= bpxi_state_init;

		write_fifo_data_ready <= '0';
		read_fifo_data_valid <= '0';

		m_axi_arvalid <= '0';
		m_axi_rready <= '0';
		m_axi_awvalid <= '0';
		m_axi_wvalid <= '0';
		m_axi_bready <= '0';
	else
		bpi_state_temp := bpi_state;

		if bpi_out_ready = '1' and bpi_out_valid = '1' then
			bpi_state_temp.data_count := bpi_state_temp.data_count - 1;

			if bpi_state_temp.data_count = 0 then
				bpi_state_temp := bpi_state_init;
			end if;
		end if;

		if bpi_in_valid = '1' and bpi_in_ready = '1' then
			--Parse command
			bpi_parse(bpi_state_temp, bpi_in);

			--Determine state to enter if a command has been activated
			if bpi_state_temp.command_valid then
				bpxi_op := bpxi_decode(bpi_state_temp.exec_type);

				case bpxi_op is
					when bpxi_write_word => 
					when bpxi_read_word => 
						bpxi_state_temp.state := bpxi_shift_raddr;

					when others => 
				end case;
			end if;
		end if;

		if bpi_state_temp.command_valid then
			--Execute (or continue executing) command
			bpxi_state_temp := bpxi_state;

			--Decode bpxi (needed for VHDL 93 to accept case statement below)
			bpxi_op := bpxi_decode(bpi_state_temp.exec_type);

			case bpxi_op is
				when bpxi_write_word =>
					--Write 32 bit addr
				when bpxi_read_word =>
					--Read 4/Length
					case bpxi_state_temp.state is
						when bpxi_shift_raddr => 
							--Shift bytes into address
							m_axi_araddr_temp := m_axi_araddr;

							shift_in(m_axi_araddr_temp, 4, shift_done);

							if shift_done then
								bpxi_state_temp.state := bpxi_wait_rresp;

								m_axi_arvalid <= '1';
								m_axi_rready <= '1';
							end if;

							m_axi_araddr <= m_axi_araddr_temp;

						when bpxi_wait_rresp =>
							--Wait for handshake on both channels
							axi_done := true;

							axi_wait_handshake(
								m_axi_rready,
								m_axi_rvalid,
								axi_done);

							if axi_done then
								m_axi_rdata_temp := m_axi_rdata;
							end if;

							axi_wait_handshake(
								m_axi_arvalid,
								m_axi_arready,
								axi_done);

							if axi_done then
								--Read complete
								bpxi_state_temp.state := bpxi_shift_rdata;

								shift_out(m_axi_rdata_temp, 4, shift_done);
							end if;

						when bpxi_shift_rdata => 
							--Shift out response data
							shift_out(m_axi_rdata_temp, 4, shift_done);

							--Done shifting response data?
							if shift_done then
								bpi_end_command(bpi_state_temp);
							end if;

						when others =>
							--Do nothing, unreachable
					end case;

				when others =>
					--Unsupported command
					bpi_end_command(bpi_state_temp);
			end case;
		end if;

		--Update state
		bpxi_state <= bpxi_state_temp;
		bpi_state <= bpi_state_temp;
	end if;
	end if;
	end process;
end architecture;