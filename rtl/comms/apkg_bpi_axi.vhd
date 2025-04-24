--AXI backend for Byte Procedure Interface
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

package bpi_axi is
	subtype bpix_byte is std_ulogic_vector(7 downto 0);

	type bpxi_fs is (
		bpxi_shift_raddr, 
		bpxi_wait_rresp, 
		bpxi_shift_rdata,

		bpxi_shift_waddr,
		bpxi_shift_wdata,
		bpxi_wait_wresp,
		bpxi_wait_bresp,
		bpxi_shift_bresp);

	type bpxi_operation is (
		bpxi_nop,
		bpxi_write_word,
		bpxi_read_word);

	type bpxi_operation_encoding_t is 
		array (bpxi_operation) of bpix_byte;

	constant bpxi_operation_encoding : bpxi_operation_encoding_t := (
		bpxi_write_word => X"00",
		bpxi_read_word => X"01",
		bpxi_nop => X"FF");

	type bpxi_state_t is record
		state : bpxi_fs;
		shift_byte_count : natural range 0 to 7;
	end record;

	constant bpxi_state_init : bpxi_state_t := (
		state => bpxi_shift_raddr,
		shift_byte_count => 0);

	function bpxi_decode(byte : bpix_byte) return bpxi_operation;

	procedure shift_in_byte(
		variable s : inout std_ulogic_vector;
		signal data : std_ulogic_vector;
		signal ready : inout std_ulogic; 
		signal valid : in std_ulogic;
		variable counter : inout natural;
		count : natural;
		variable done : out boolean);

	procedure shift_out_byte(
		variable s : inout std_ulogic_vector;
		signal data : out std_ulogic_vector;
		signal ready : in std_ulogic; 
		signal valid : inout std_ulogic;
		variable counter : inout natural;
		count : natural;
		variable done : out boolean);

	procedure axi_wait_handshake(
		signal mgr : inout std_ulogic;
		signal sub : std_ulogic;
		variable done : inout boolean);
end package;

package body bpi_axi is
	function bpxi_decode(byte : bpix_byte) return bpxi_operation is
	begin
		for op in bpxi_operation loop
			if bpxi_operation_encoding(op) = byte then
				return op;
			end if;
		end loop;

		return bpxi_nop;
	end function;

	--Shift bytes from write fifo into signal
	procedure shift_in_byte(
		variable s : inout std_ulogic_vector;
		signal data : std_ulogic_vector;
		signal ready : inout std_ulogic; 
		signal valid : in std_ulogic;
		variable counter : inout natural;
		count : natural;
		variable done : out boolean)
	is
		variable counter_next : natural;
	begin
		counter_next := counter;

		--Start counter
		if ready = '0' then
			--Request data
			ready <= '1';

			counter_next := count;
		end if;

		if ready = '1' and valid = '1' then
			--Accept data and Shift
			s := data & s(s'left downto 8);
			counter_next := counter - 1;
		end if;

		--Done shifting?
		if counter_next = 0 then
			done := true;
			ready <= '0';
		else
			done := false;
		end if;

		counter := counter_next;
	end procedure;

	--Shift bytes from signal into read fifo
	procedure shift_out_byte(
		variable s : inout std_ulogic_vector;
		signal data : out std_ulogic_vector;
		signal ready : in std_ulogic; 
		signal valid : inout std_ulogic;
		variable counter : inout natural;
		count : natural;
		variable done : out boolean) 
	is
		variable counter_next : natural;
		variable s_next : std_ulogic_vector(s'range);
	begin
		counter_next := counter;
		s_next := s;

		--Start counter
		if valid = '0' then
			--Request data
			valid <= '1';

			counter_next := count;
		end if;

		if ready = '1' and valid = '1' then
			--Accept data and Shift
			s_next := X"00" & s(s'left downto 8);

			counter_next := counter - 1;
		end if;

		data <= s_next(7 downto 0);

		--Done shifting?
		if counter_next = 0 then
			done := true;
			valid <= '0';
		else
			done := false;
		end if;

		counter := counter_next;
		s := s_next;
	end procedure;

	procedure axi_wait_handshake(
		signal mgr : inout std_ulogic; 	--Ready for mgr->sub channels
		signal sub : std_ulogic; 		--Valid for mgr->sub channels
		variable done : inout boolean) is
	begin
		--Transaction outstanding?
		if mgr = '1' then
			if sub = '1' then
				--Completed
				mgr <= '0';
			else
				--Still ongoing
				done := false;
			end if;
		end if;
	end procedure;
end package body;
