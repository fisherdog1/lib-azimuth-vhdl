--Multi-size FIFO
--When a write of size N is executed, that many ranks are written, starting
--from the lowest indexed rank and proceeding up. I.e. a write larger than
--1 may be "unaligned". This is only a problem if the same order of sizes is
--not popped as pushed. Popping operates the same way.
--The number of ranks is the max of READ_PORTS and WRITE_PORTS.

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library lib_azimuth;
	use lib_azimuth.address_math.all;

library xpm;
	use xpm.vcomponents.all;

entity sync_fifo_multiport is
	generic (
		--Smallest read/write width
		WIDTH : positive := 8;

		--Max read/write size in multiples of WIDTH
		READ_PORTS : positive := 4;
		WRITE_PORTS : positive := 1;

		--Depth in number of WIDTH words
		DEPTH : positive := 32);
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--Write side
		write_data : std_ulogic_vector(WIDTH * WRITE_PORTS - 1 downto 0);
		write_size : unsigned(bits_required(WRITE_PORTS) - 1 downto 0);
		write_ready : buffer std_ulogic;

		--Read side
		read_data : out std_ulogic_vector(WIDTH * READ_PORTS - 1 downto 0);
		read_size : unsigned(bits_required(READ_PORTS) - 1 downto 0);
		read_valid : out std_ulogic; 

		--Other
		count : out natural range 0 to DEPTH - 1);
end entity;

architecture rtl of sync_fifo_multiport is
	constant rank : natural := 4;
	constant depth_per_rank : natural := DEPTH / rank;

	subtype ptr_t is natural range 0 to DEPTH - 1;

	signal read_ptr, write_ptr : ptr_t := 0;
	signal next_read_ptr, next_write_ptr : ptr_t;

	type fifo_ctrl_t is array (0 to rank - 1) of std_ulogic;

	signal wstrb, rstrb : fifo_ctrl_t;
	signal read_data_r : std_logic_vector(read_data'range);
begin
	read_data <= std_ulogic_vector(read_data_r);

	gen_ranks: for i in 0 to rank - 1 generate
		fifo: xpm_fifo_sync
		generic map (
			WRITE_DATA_WIDTH => WIDTH,
			READ_DATA_WIDTH => WIDTH,
			WR_DATA_COUNT_WIDTH => bits_required(DEPTH),
			RD_DATA_COUNT_WIDTH => bits_required(DEPTH),
			FIFO_WRITE_DEPTH => DEPTH,
			FIFO_MEMORY_TYPE => "distributed")
		port map (
			wr_clk => clk,
			rst => rst,

			din => std_logic_vector(write_data), --Temp
			dout => read_data_r(i * 8 + 7 downto i * 8), --Temp, Scrambled if unaligned
			
			wr_en => wstrb(i),
			rd_en => rstrb(i),

			sleep => '0',
			injectsbiterr => '0',
			injectdbiterr => '0');
	end generate;

	process (read_ptr, write_ptr, read_size, write_size)
		variable var_write_size : natural range 0 to WRITE_PORTS;
		variable var_read_size : natural range 0 to READ_PORTS;
		variable read, write : boolean;
		variable count : natural range 0 to rank;
	begin
		var_write_size := to_integer(write_size);
		var_read_size := to_integer(read_size);

		next_write_ptr <= write_ptr;
		next_read_ptr <= read_ptr;

		write := var_write_size > 0 
			and not (
				(write_ptr - read_ptr) mod DEPTH < 0 and 
				(write_ptr + var_write_size - read_ptr) mod DEPTH >= 0);

		read := var_read_size > 0 
			and not (
				(read_ptr - write_ptr) mod DEPTH <= 0 and 
				(read_ptr + var_read_size - write_ptr) mod DEPTH > 0);

		--Calculate which FIFOs to write to
		for i in 0 to rank - 1 loop
			wstrb(i) <= '0';
		end loop;

		if write then
			count := 0;

			for i in 0 to rank - 1 loop
				if count < var_write_size then
					wstrb((write_ptr + count) mod rank) <= '1';
					count := count + 1;
				end if;
			end loop;

			next_write_ptr <= write_ptr + count;
		end if;

		--Calculate which FIFOs to read from
		for i in 0 to rank - 1 loop
			rstrb(i) <= '0';
		end loop;

		if read then
			count := 0;

			for i in 0 to rank - 1 loop
				if count < var_read_size then
					rstrb((read_ptr + count) mod rank) <= '1';
					count := count + 1;
				end if;
			end loop;

			next_read_ptr <= read_ptr + count;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				read_ptr <= 0;
				write_ptr <= 0;
			else
				read_ptr <= next_read_ptr;
				write_ptr <= next_write_ptr;
			end if;
		end if;
	end process;
end architecture;