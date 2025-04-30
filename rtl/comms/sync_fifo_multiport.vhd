--Sync (Non-CDC) FIFO with capability to push/pop multiple data at a time
--For ready/valid signals, the LSB is for the element pushed first, and is
--the lowest order word in the associated data signal.

--Partial writes are not accepted. write_data_ready is thus combinationally 
--dependent on write_data_valid. Partial reads are accepted, and the result
--is right justified into the read_data signal.

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity sync_fifo_multiport is
	generic (
		--Smallest read/write width
		WIDTH : positive := 8;

		--Max read/write size in multiples of WIDTH
		READ_PORTS : positive := 4;
		WRITE_PORTS : positive := 4;

		--Depth in number of WIDTH words
		DEPTH : positive := 256);
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--Write side
		write_data : std_ulogic_vector(WIDTH * WRITE_PORTS - 1 downto 0);
		write_data_valid : std_ulogic_vector(WRITE_PORTS - 1 downto 0);
		write_data_ready : buffer std_ulogic;

		--Read side
		read_data : out std_ulogic_vector(WIDTH * READ_PORTS - 1 downto 0);
		read_data_valid : buffer std_ulogic_vector(READ_PORTS - 1 downto 0);
		read_data_ready_count : natural range 0 to READ_PORTS;

		--Other
		count : out natural range 0 to DEPTH - 1);
end entity;

architecture rtl of sync_fifo_multiport is
	subtype ptr_t is natural range 0 to DEPTH - 1;

	signal write_ptr : ptr_t := 0;
	signal read_ptr : ptr_t := 0;

	signal write_full : boolean;
	signal read_empty : boolean;

	subtype data_t is std_ulogic_vector(WIDTH - 1 downto 0);
	type mem_t is array (0 to DEPTH - 1) of data_t;

	signal mem : mem_t;
begin
	write_full <= (write_ptr + 1) mod DEPTH = read_ptr;
	read_empty <= read_ptr = write_ptr;

	write_data_ready <= '1' when not write_full else '0';

	count <= (write_ptr - read_ptr) mod DEPTH;

	process (clk)
		variable write_ptr : ptr_t;
		variable read_ptr : ptr_t;

		variable write_count : natural range 0 to 4;
		variable read_position : natural range 0 to 3;

		variable write : boolean;
	begin
		if rising_edge(clk) then
			if rst = '1' then
				write_ptr := 0;
				read_ptr := 0;

				read_data_valid <= (others => '0');
			else
				--Fix this
				--if read_data_valid = '1' and read_data_ready = '1' then
				--	read_data_valid <= '0';
				--end if;

				read_position := 0;

				for i in 0 to READ_PORTS - 1 loop
					--Slot already has data?
					if read_data_valid(i) /= '1' then
						read_data(WIDTH * read_position + 7 downto WIDTH * read_position) <= 
							mem(read_ptr);

						read_data_valid(read_position) <= '1';
						read_ptr := (read_ptr + 1) mod DEPTH;

						read_position := read_position + 1;
					end if;
				end loop;

				--Count number of writes attempted
				write_count := 0;
				
				for i in 0 to WRITE_PORTS - 1 loop
					if write_data_valid(i) = '1' then
						write_count := write_count + 1;
					end if;
				end loop; 

				--Can fit this write?
				write := (read_ptr - write_ptr - 1) mod DEPTH >= write_count and write_count > 0;

				if write then
					for i in 0 to WRITE_PORTS - 1 loop
						if write_data_valid(i) = '1' then
							mem(write_ptr) <= 
								write_data(WIDTH * i + 7 downto WIDTH * i);

							write_ptr := (write_ptr + 1) mod DEPTH;
						end if;
					end loop;
				end if;
			end if;
		end if;
	end process;
end architecture;