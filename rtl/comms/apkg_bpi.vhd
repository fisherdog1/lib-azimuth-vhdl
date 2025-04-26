library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

package bpi is
	subtype bpi_byte is std_ulogic_vector(7 downto 0);
	subtype bpi_long is std_ulogic_vector(63 downto 0);

	type bpi_opcode is (
		bpi_nop,
		bpi_get_status,
		bpi_get_version,
		bpi_get_command_supported,
		bpi_backend_select,
		bpi_command_write,
		bpi_command_verify,
		bpi_command_execute,
		bpi_command_length,
		bpi_response_read,
		bpi_response_length,
		bpi_match_response_read,
		bpi_match_response_length);

	type bpi_opcode_encoding_t is array (bpi_opcode) of bpi_byte;
	constant bpi_opcode_encoding : bpi_opcode_encoding_t := (
		bpi_nop => X"00",
		bpi_get_status => X"73",
		bpi_get_version => X"76",
		bpi_get_command_supported => X"75",
		bpi_backend_select => X"62",
		bpi_command_write => X"77",
		bpi_command_verify => X"79",
		bpi_command_execute => X"78",
		bpi_command_length => X"63",
		bpi_response_read => X"72",
		bpi_response_length => X"6C",
		bpi_match_response_read => X"52",
		bpi_match_response_length => x"4C");

	type bpi_opcode_supported_t is array (bpi_opcode) of boolean;
	constant supported_opcodes : bpi_opcode_supported_t := (
		bpi_nop => true,
		bpi_get_version => true,
		bpi_get_command_supported => true,
		bpi_command_write => true,
		bpi_response_read => false,
		others => false); --TODO: Im gonna forget otherwise

	subtype bpi_current_op_phase is natural range 0 to 7;
	subtype bpi_length is natural range 0 to 255;
	type bpi_op_fields is array (bpi_current_op_phase) of bpi_length;

	--Command parser state
	type bpi_state_t is record
		--Opcode being parsed
		current_op : bpi_opcode;

		--Command field index
		current_op_phase : bpi_current_op_phase;

		--Bytes remaining in variable length field
		data_count : bpi_length;

		--Byte-shift register for moving data in and out
		shiftreg : unsigned(8 * 4 - 1 downto 0);

		--Temp data for commands
		temp_field1 : unsigned(7 downto 0);
	end record;

	constant bpi_state_init : bpi_state_t := (
		current_op => bpi_nop,
		current_op_phase => 0,
		data_count => 0,

		shiftreg => (others => '0'),

		--Temp data
		others => (others => '0'));

	subtype bpi_frontend_status is std_ulogic_vector(15 downto 0);

	type bpi_frontend_if_in_t is record
		--Outside interface
		bpi_in : bpi_byte;
		bpi_in_valid : std_ulogic;
		bpi_out_ready : std_ulogic;
	end record;

	type bpi_frontend_if_out_t is record
		--Outside interface
		bpi_out : bpi_byte;
		bpi_out_valid : std_ulogic;		
		bpi_in_ready : std_ulogic;

		--Interface to FIFOs / backend
		write_command : std_ulogic;
		read_response :std_ulogic;

		backend_execute : std_ulogic;
	end record;

	constant bpi_frontend_init : bpi_frontend_if_out_t := (
		bpi_out => (others => '0'),
		bpi_out_valid => '0',
		bpi_in_ready => '1',
		
		write_command => '0',
		read_response => '0',

		backend_execute => '0');

	type bpi_frontend_to_backend_t is record
		execute_req : std_ulogic;

		command : bpi_byte;
		command_valid : std_ulogic;

		response_ready : std_ulogic;
	end record;

	type bpi_backend_to_frontend_t is record
		available : std_ulogic;

		execute_ack : std_ulogic;

		command_ready : std_ulogic;

		response : bpi_byte;
		response_valid : std_ulogic;
	end record;

	type bpi_frontend_status_t is record
		backend_unavailable : std_ulogic;
		command_full : std_ulogic;
		command_overflow : std_ulogic;
		response_full : std_ulogic;
		response_overflow : std_ulogic;
		response_underflow : std_ulogic;
	end record;

	function bpi_fe_status_to_byte(status : bpi_frontend_status_t) return bpi_frontend_status;
	function bpi_decode(byte : bpi_byte) return bpi_opcode;

	procedure bpi_frontend_shift_in(variable field : inout unsigned; data : bpi_byte);
	procedure bpi_frontend_shift_out(variable field : inout unsigned; variable data : out bpi_byte);
	procedure bpi_frontend(
		variable state : inout bpi_state_t; 
		signal interface_in : in bpi_frontend_if_in_t;
		signal interface_out : inout bpi_frontend_if_out_t);
end package;

package body bpi is
	function bpi_fe_status_to_byte(status : bpi_frontend_status_t) return bpi_frontend_status is
	begin
		return X"0000";
	end function;

	function bpi_decode(byte : bpi_byte) return bpi_opcode is
	begin
		for op in bpi_opcode loop
			if bpi_opcode_encoding(op) = byte then
				return op;
			end if;
		end loop;

		return bpi_nop;
	end function;

	--Shift byte into variable for frontend commands
	procedure bpi_frontend_shift_in(variable field : inout unsigned; data : bpi_byte) is
	begin
		--Right shift byte into field
		field := unsigned(data) & field(field'left downto 8);
	end procedure;

	--Shift byte out of variable for frontend commands
	procedure bpi_frontend_shift_out(variable field : inout unsigned; variable data : out bpi_byte) is
	begin
		data := bpi_byte(field(7 downto 0));
		field := X"00" & field(field'left downto 8);
	end procedure;

	--Frontend state machine for BPI
	--Run every cycle in the BPI frontend's clock domain
	procedure bpi_frontend(
		variable state : inout bpi_state_t; 
		signal interface_in : in bpi_frontend_if_in_t;
		signal interface_out : inout bpi_frontend_if_out_t) 
	is
		variable opcode : bpi_opcode;
		variable shift_done : boolean;

		--Shift bpi_in into variable
		procedure shift_in(
			variable field : out unsigned; 
			length : bpi_length) 
		is
		begin
			--Start of shift?
			if state.data_count = 0 then
				--Load length
				state.data_count := length;

				--Ready interface
				interface_out.bpi_in_ready <= '1';
			end if;

			--Ready will not be 1 on first call
			if interface_in.bpi_in_valid = '1' and interface_out.bpi_in_ready = '1' then
				bpi_frontend_shift_in(state.shiftreg, interface_in.bpi_in);

				state.data_count := state.data_count - 1;
			end if;

			if state.data_count = 0 then
				shift_done := true;
				interface_out.bpi_in_ready <= '0';

				--Copy data out
				field := state.shiftreg(
					state.shiftreg'left downto state.shiftreg'left - field'length + 1);
			end if;
		end procedure;

		--Shift variable to bpi_out
		procedure shift_out(
			field : unsigned;
			length : bpi_length) 
		is
			variable temp : bpi_byte;
		begin
			--Start of shift?
			if state.data_count = 0 then
				--Load length and data
				state.data_count := length;
				state.shiftreg := resize(field, state.shiftreg'length);

				--Set data valid
				interface_out.bpi_out_valid <= '1';

				--Show first byte
				bpi_frontend_shift_out(state.shiftreg, temp);
				interface_out.bpi_out <= temp;
			end if;

			--Valid will not be 1 on the first call
			if interface_out.bpi_out_valid = '1' and interface_in.bpi_out_ready = '1' then
				--Show next byte
				bpi_frontend_shift_out(state.shiftreg, temp);
				interface_out.bpi_out <= temp;

				state.data_count := state.data_count - 1;
			end if;

			if state.data_count = 0 then
				shift_done := true;
				interface_out.bpi_out_valid <= '0';
			end if;
		end procedure;

		--Shift a byte into the data_count field
		procedure shift_data_count is
		begin
			shift_in(state.temp_field1, 1);
			state.data_count := to_integer(state.temp_field1);
		end procedure;

		procedure shift_command is
		begin
			--Enable path to command space
			interface_out.write_command <= '1';

			if interface_in.bpi_in_valid = '1' and interface_out.bpi_in_ready = '1' then
				state.data_count := state.data_count - 1;
			end if;

			if state.data_count = 0 then
				shift_done := true;
				interface_out.write_command <= '0';
			end if;
		end procedure;

		procedure shift_response is
		begin
			interface_out.read_response <= '1';

			if interface_in.bpi_out_ready = '1' and interface_out.bpi_out_valid = '1' then
				state.data_count := state.data_count - 1;
			end if;

			if state.data_count = 0 then
				shift_done := true;
				interface_out.read_response <= '0';
			end if;
		end procedure;

		procedure end_command is
		begin
			state.current_op := bpi_nop;
			state.current_op_phase := 0;
			state.data_count := 0;

			interface_out.write_command <= '0';
			interface_out.read_response <= '0';

			interface_out.bpi_in_ready <= '1';
		end procedure;
	begin
		shift_done := false;

		if state.current_op = bpi_nop then
			--Ready to accept new command
			if interface_in.bpi_in_valid = '1' and interface_out.bpi_in_ready = '1' then
				--Interpret opcode if it's supported, otherwise do nothing
				opcode := bpi_decode(interface_in.bpi_in);

				if supported_opcodes(opcode) then
					state.current_op := opcode;
				end if;
			end if;
		else
			--Currently running command
			case state.current_op is
				--Supported opcodes
				when bpi_get_status => 
					--Respond with FrontendStatus
					--Done

				when bpi_get_version => 
					case state.current_op_phase is
					when 0 => 
						--Respond with fixed Version value
						shift_out(unsigned'(X"ABCD"), 2);
					when others =>
						end_command;
					end case;

				when bpi_get_command_supported => 
					case state.current_op_phase is
					when 0 => 
						shift_in(state.temp_field1, 1);
					when 1 => 
						opcode := bpi_decode(bpi_byte(state.temp_field1));

						if supported_opcodes(opcode) then
							--Supported
							shift_out(unsigned'(X"00"), 1);
						else
							--Not Supported
							shift_out(unsigned'(X"03"), 1);
						end if;
					when others => 
						end_command;
					end case;

				when bpi_backend_select => 
					case state.current_op_phase is
					when others => 
						end_command;
					end case;

				when bpi_command_write => 
					case state.current_op_phase is
					when 0 => 
						shift_data_count;
					when 1 => 
						shift_command;
						--TODO: Supposed to respond with success message
						--Can fail if backend not available
					when others => 
						end_command;
					end case;

				when bpi_command_verify => 
					--Read Checksum
					--Respond with Success based on if Checksum matches current command checksum
					--Done

				when bpi_command_execute => 
					--Trigger backend execution
					--Done

				when bpi_command_length => 
					--Respond with length of written command space (4 bytes)
					--Done

				when bpi_response_read => 
					case state.current_op_phase is
					when 0 => 
						shift_data_count;
					when 1 => 
						shift_response;
					when others => 
						end_command;
					end case;
					--Read length
					--Wait for length bytes from response space
					--Done

				when bpi_response_length => 
					--Respond with length of readable response space (4 bytes)
					--Done

				when bpi_match_response_read => 
					--Read Match field
					--Read Length field
					--Check for match in response space
					--Wait for length bytes from response space
					--Done

				when bpi_match_response_length => 
					--Read Match field
					--Check for match in response space
					--Respond Success if such a match is available
					--Respond with Length of match
					--Done

				when others => 
					--Unreachable
			end case;
		end if;

		--Advance to next phase of command
		if shift_done then
			state.current_op_phase := state.current_op_phase + 1;
		end if;
	end procedure;
end package body;
