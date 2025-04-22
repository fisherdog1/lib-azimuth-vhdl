library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

package bpi is
	subtype bpi_byte is std_ulogic_vector(7 downto 0);
	subtype bpi_long is std_ulogic_vector(63 downto 0);

	type bpi_opcode is (
		bpi_nop,
		bpi_reset_itf,
		bpi_get_status,
		bpi_write_data,
		bpi_read_data,
		bpi_execute,
		bpi_test,
		bpi_clear_status);

	type bpi_opcode_encoding_t is array (bpi_opcode) of bpi_byte;
	constant bpi_opcode_encoding : bpi_opcode_encoding_t := (
		bpi_nop => X"55",
		bpi_reset_itf => X"00",
		bpi_get_status => X"01",
		bpi_write_data => X"02",
		bpi_read_data => X"03",
		bpi_execute => X"04",
		bpi_test => X"05",
		bpi_clear_status => X"10");

	type bpi_state_t is record
		--Command parser state
		current_op : bpi_opcode;
		field_index : natural range 0 to 1;
		data_count : unsigned(7 downto 0);
		exec_type : bpi_byte;

		--Indicates command status to backend
		command_valid : boolean;

		--Controls read and write fifos (part of the backend)
		--When true, data are popped continuously from the read fifo to the output
		pop_read_fifo : boolean;
		--When true, received data are pushed to the write fifo instead of being parsed
		push_write_fifo : boolean;
	end record;

	constant bpi_state_init : bpi_state_t := (
		current_op => bpi_nop,
		field_index => 0,
		data_count => (others => '0'),
		exec_type => (others => '0'),

		command_valid => false,
		pop_read_fifo => false,
		push_write_fifo => false);

	function bpi_decode(byte : bpi_byte) return bpi_opcode;
	procedure bpi_parse(variable state : inout bpi_state_t; data : bpi_byte);
	procedure bpi_end_command(variable state : inout bpi_state_t);
end package;

package body bpi is
	function bpi_decode(byte : bpi_byte) return bpi_opcode is
	begin
		for op in bpi_opcode loop
			if bpi_opcode_encoding(op) = byte then
				return op;
			end if;
		end loop;

		return bpi_nop;
	end function;

	--Frontend parser for BPI
	--Receives data and manages parser state. command_valid and command_acknowledge signals
	--are used to communicate with the backend.
	procedure bpi_parse(variable state : inout bpi_state_t; data : bpi_byte) is
	begin
		--Read new command
		if state.current_op = bpi_nop then
			case bpi_decode(data) is
				when bpi_reset_itf =>
					state := bpi_state_init;
					--TODO: reset backend

				when others =>
					--Command has arguments, more data needs to be parsed
					state.current_op := bpi_decode(data);
			end case;
		else
			case state.current_op is
				when bpi_write_data => 
					if state.field_index = 0 then
						--Receive data length
						state.data_count := unsigned(data);
						state.field_index := 1;
						state.push_write_fifo := true;

					elsif state.data_count > 1 then
						--Receive data
						state.data_count := state.data_count - 1;
					else
						--End of command, return to init state
						state := bpi_state_init;
					end if;

				when bpi_read_data => 
					--Receive data length
					state.data_count := unsigned(data);

					--Execute command
					state.pop_read_fifo := true;

				when bpi_execute => 
					--Receive operation type
					state.exec_type := data;

					--Execute command
					state.command_valid := true;
					
				when others =>
					--Execute command (which has no arguments)
					state.command_valid := true;
			end case;
		end if;
	end procedure;

	--Terminate the currently executing command by setting the operation to nop
	--and marking the command as no longer valid
	--TODO: require status to be written
	procedure bpi_end_command(variable state : inout bpi_state_t) is
	begin
		state.current_op := bpi_nop;
		state.command_valid := false;
	end procedure;
end package body;
