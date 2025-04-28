--AXI backend for Byte Procedure Interface
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.bpi.all;

package bpi_axi is
	subtype bpxi_byte is std_ulogic_vector(7 downto 0);
	subtype bpxi_length is natural range 0 to 7;

	type axi4_interface_in_t is record
		awready : std_ulogic;

		wready : std_ulogic;

		bresp : std_ulogic_vector(1 downto 0);
		bvalid : std_ulogic;

		arready : std_ulogic;

		rdata : std_ulogic_vector(31 downto 0);
		rresp : std_ulogic_vector(1 downto 0);
		rvalid : std_ulogic;
	end record;

	type axi4_interface_out_t is record
		awaddr : std_ulogic_vector(31 downto 0);
		awvalid : std_ulogic;

		wdata : std_ulogic_vector(31 downto 0);
		wstrb : std_ulogic_vector(3 downto 0);
		wvalid : std_ulogic;

		bready : std_ulogic;

		araddr : std_ulogic_vector(31 downto 0);
		arvalid : std_ulogic;

		rready : std_ulogic;
	end record;

	constant axi4_interface_out_init : axi4_interface_out_t := (
		awaddr => (others => '0'),
		awvalid => '0',

		wdata => (others => '0'),
		wstrb => (others => '0'),
		wvalid => '0',

		bready => '0',

		araddr => (others => '0'),
		arvalid => '0',

		rready => '0');

	type bpxi_opcode is (
		bpxi_nop,
		bpxi_read_word,
		bpxi_write_word);

	type bpxi_operation_encoding_t is 
		array (bpxi_opcode) of bpxi_byte;

	constant bpxi_operation_encoding : bpxi_operation_encoding_t := (
		bpxi_nop => X"FF",
		bpxi_read_word => X"01",
		bpxi_write_word => X"00");

	type bpxi_fs is (
		bpxi_shift_raddr, 
		bpxi_wait_rresp, 
		bpxi_shift_rdata,
		bpxi_shift_rresp,

		bpxi_shift_waddr,
		bpxi_shift_wdata,
		bpxi_wait_wresp,
		bpxi_wait_bresp,
		bpxi_shift_bresp);

	--Per-AXI-channel status
	type bpxi_channel_status is (
		axi_chan_idle,			--Mgr = 0 Sub = 0
		axi_chan_mgr_wait,		--Mgr = 1 Sub = 0
		axi_chan_sub_wait,		--Mgr = 0 Sub = 1
		axi_chan_accepting);	--Mgr = 1 Sub = 1

	type bpxi_state_t is record
		--Currently executing operation and sub-operation
		current_op : bpxi_opcode;
		current_op_phase : bpxi_fs;

		--Temp variable for shifting address/data/status
		temp_addr : std_ulogic_vector(31 downto 0);
		temp_data : std_ulogic_vector(31 downto 0);
		temp_strb : std_ulogic_vector(3 downto 0);
		temp_resp : std_ulogic_vector(1 downto 0);

		--Number of transfers left in multi-beat transaction
		--TODO

		--ID of transaction belonging to this machine
		--TODO

		--Number of cycles left in shift step
		shift_counter : natural range 0 to 7;
	end record;

	constant bpxi_state_init : bpxi_state_t := (
		current_op => bpxi_nop,
		current_op_phase => bpxi_shift_raddr,

		temp_addr => (others => '0'),
		temp_data => (others => '0'),
		temp_strb => (others => '0'),
		temp_resp => (others => '0'),

		shift_counter => 0);

	procedure check_handshake(
		signal mgr : inout std_ulogic;
		signal sub : std_ulogic);

	procedure bpi_axi_backend(
		variable state : inout bpxi_state_t;
		signal backend_if_in : bpi_frontend_to_backend_t;
		signal backend_if_out : inout bpi_backend_to_frontend_t;
		signal axi4_if_in : axi4_interface_in_t;
		signal axi4_if_out : inout axi4_interface_out_t);
end package;

package body bpi_axi is
	--Get opcode from command Op byte
	function bpxi_decode(byte : bpxi_byte) return bpxi_opcode is
	begin
		for op in bpxi_opcode loop
			if bpxi_operation_encoding(op) = byte then
				return op;
			end if;
		end loop;

		return bpxi_nop;
	end function;

	--Check status of ready/valid handshake
	--The manager- and subordinate-side signals are passed regardless of if they are Ready or Valid
	procedure check_handshake(
		signal mgr : inout std_ulogic;
		signal sub : std_ulogic) is
	begin
		--Transaction outstanding?
		if mgr = '1' then
			if sub = '1' then
				--Completed
				mgr <= '0';
			else
				--Still ongoing
			end if;
		end if;
	end procedure;

	--BPI AXI backend
	--Run every cycle in the backend clock domain
	procedure bpi_axi_backend(
		variable state : inout bpxi_state_t;
		signal backend_if_in : bpi_frontend_to_backend_t;
		signal backend_if_out : inout bpi_backend_to_frontend_t;
		signal axi4_if_in : axi4_interface_in_t;
		signal axi4_if_out : inout axi4_interface_out_t) 
	is
		--Shift data from command space to signal
		--Done is set to false when shifting is not complete
		--The shifter variable will be used as a shift register
		procedure shift_in (
			variable shifter : inout std_ulogic_vector;
			count : bpxi_length; --This can be calculated
			done : inout boolean) is
		begin
			--Request data from command space
			backend_if_out.command_ready <= '1';

			if state.shift_counter = 0 then
				state.shift_counter := count; --I think
			end if;

			if backend_if_out.command_ready = '1' and backend_if_in.command_valid = '1' then
				--Shift
				shifter := backend_if_in.command & shifter(shifter'left downto 8);
				state.shift_counter := state.shift_counter - 1;
			end if;

			if state.shift_counter = 0 then
				backend_if_out.command_ready <= '0'; --This might be a cycle late?
			else
				done := false;
			end if;
			
		end procedure;

		procedure end_command is
		begin
			state.current_op := bpxi_nop;

			--Shift counter should already be zero
		end procedure;

		function max (a, b  : integer) return integer is
		begin
			if a >= b then
				return a;
			else
				return b;
			end if;
		end function;

		procedure shift_out (
			variable shifter : inout std_ulogic_vector;
			count : bpxi_length;
			done : inout boolean) 
		is
			variable temp : std_ulogic_vector(max(shifter'length, 8) - 1 downto 0);
		begin
			backend_if_out.response_valid <= '1';
	
			if state.shift_counter = 0 then
				state.shift_counter := count;

				backend_if_out.response <= 
					std_ulogic_vector(resize(unsigned(shifter(shifter'left downto 0)), 8));
			end if;

			if backend_if_out.response_valid = '1' and backend_if_in.response_ready = '1' then
				temp := X"00" & shifter(shifter'left downto 8);
				shifter := temp(shifter'range);

				backend_if_out.response <= 
					std_ulogic_vector(resize(unsigned(shifter(shifter'left downto 0)), 8));

				state.shift_counter := state.shift_counter - 1;
			end if;

			if state.shift_counter = 0 then
				backend_if_out.response_valid <= '0';
			else
				done := false;
			end if;

		end procedure;

		variable temp_opcode : bpxi_byte;
		variable shift_done : boolean;
	begin
		shift_done := true;
		
		--Handshakes must be handled regardless of what else is going on!
		--                  Manager	out			Manager in
		check_handshake(axi4_if_out.awvalid, axi4_if_in.awready);	--AW
		check_handshake(axi4_if_out.wvalid, axi4_if_in.wready);		--W
		check_handshake(axi4_if_out.bready, axi4_if_in.bvalid);		--B
		check_handshake(axi4_if_out.arvalid, axi4_if_in.arready);	--AR
		check_handshake(axi4_if_out.rready, axi4_if_in.rvalid);		--R

		--Current operation
		case state.current_op is
			when bpxi_nop => 
				--Start new operation
				--TODO: gate on execute sync
				shift_in(temp_opcode, 1, shift_done);

				if shift_done then
					state.current_op := bpxi_decode(temp_opcode);
				end if;

			when bpxi_read_word =>
				case state.current_op_phase is
					when bpxi_shift_raddr => 
						--Move command into raddr
						shift_in(state.temp_addr, 4, shift_done);

						if shift_done then
							axi4_if_out.araddr <= state.temp_addr;
							axi4_if_out.arvalid <= '1';
							axi4_if_out.rready <= '1';
							state.current_op_phase := bpxi_wait_rresp;
						end if;

					when bpxi_wait_rresp => 
						--Wait for rresp handshake
						--A sub that illegally asserts rvalid the same cycle as arrvalid
						--will break this
						if axi4_if_in.rvalid = '1' then
							--Save rresp and rdata
							state.temp_data := axi4_if_in.rdata;
							state.temp_resp := axi4_if_in.rresp;
						end if;

						if axi4_if_out.rready = '0' then
							state.current_op_phase := bpxi_shift_rdata;
						end if;

					when bpxi_shift_rdata => 
						--Move rdata and rresp to response space
						shift_out(state.temp_data, 4, shift_done);

						if shift_done then
							state.current_op_phase := bpxi_shift_rresp;
						end if;

					when bpxi_shift_rresp => 
						shift_out(state.temp_resp, 1, shift_done);

						if shift_done then
							end_command;
						end if;

					when others => 
						end_command;
				end case;

			when bpxi_write_word =>
				case state.current_op_phase is
					when bpxi_shift_waddr => 
					when bpxi_shift_wdata => 
					when bpxi_wait_wresp => 
					when bpxi_wait_bresp => 
					when bpxi_shift_bresp => 
					when others => 
						end_command;
				end case;

			when others => 
				--Unsupported or nop
		end case;
	end procedure;
end package body;
