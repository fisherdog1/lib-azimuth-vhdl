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
		DEPTH : positive := 256);
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
	constant max_ports : natural := 4;
	constant depth_per_rank : natural := DEPTH / max_ports;

	subtype ptr_t is natural range 0 to DEPTH - 1;
	subtype rank_ptr_t is natural range 0 to DEPTH / max_ports - 1;
	subtype data_t is std_ulogic_vector(WIDTH - 1 downto 0);
	subtype length_t is unsigned(bits_required(READ_PORTS) - 1 downto 0);
	
	type mem_rank_t is array (0 to DEPTH / max_ports - 1) of data_t;
	type rank_ptr_array_t is array (0 to max_ports - 1) of rank_ptr_t;
	type mem_t Is array (0 to max_ports - 1) of mem_rank_t;

	signal mem : mem_t;
	signal read_rank_ptr : rank_ptr_array_t;
	signal write_rank_ptr : rank_ptr_array_t;

	signal write_ptr_sig : ptr_t := 0;
	signal read_ptr_sig : ptr_t := 0;

	impure function distribute(ptr : ptr_t) return rank_ptr_array_t is
		variable result : rank_ptr_array_t;

		constant bits : natural := bits_required(DEPTH - 1);
		variable temp : unsigned(bits - 1 downto 0);

		constant rank_bits : natural := bits_required(max_ports - 1);
		variable top_bits : unsigned(bits - 1 downto rank_bits);
		variable bottom_bits : unsigned(rank_bits - 1 downto 0);
	begin
		temp := to_unsigned(ptr, bits);
		top_bits := temp(top_bits'range);
		bottom_bits := temp(bottom_bits'range);

		for i in 0 to max_ports - 1 loop
			if i >= to_integer(bottom_bits) then
				result(i) := to_integer(top_bits);
			else
				result(i) := to_integer(top_bits + 1);
			end if;
		end loop;

		return result;
	end function;
begin
	read_rank_ptr <= distribute(write_ptr_sig);
	write_rank_ptr <= distribute(read_ptr_sig);

	gen_ranks: for i in 0 to max_ports - 1 generate
		fifo: xpm.xpm_fifo_sync
		generic map (
			WRITE_DATA_WIDTH => WIDTH,
			READ_DATA_WIDTH => WIDTH,
			WR_DATA_COUNT_WIDTH => 8,
			RD_DATA_COUNT_WIDTH => 8)
		port map (
			din => write_data,
			dout => read_data(i * 8 + 7 downto i * 8),

			wr_clk => clk,
			wr_en => ,
			rd_en => ,
			
			);
	end generate;

	process (clk)
		variable write_ptr : ptr_t;
		variable read_ptr : ptr_t;

		variable var_write_size : natural range 0 to WRITE_PORTS;
		variable var_read_size : natural range 0 to READ_PORTS;

		variable write : boolean;
		variable read : boolean;

		variable var_rank : natural range 0 to max_ports - 1;
		variable rank_ptr : rank_ptr_array_t;
	begin
		if rising_edge(clk) then
			if rst = '1' then
				write_ptr_sig <= 0;
				read_ptr_sig <= 0;
			else
				var_write_size := to_integer(write_size);
				var_read_size := to_integer(read_size);

				read_ptr := read_ptr_sig;
				write_ptr := write_ptr_sig;

				write := var_write_size > 0 
					and not (
						(write_ptr - read_ptr) mod DEPTH < 0 and 
						(write_ptr + var_write_size - read_ptr) mod DEPTH >= 0);

				read := var_read_size > 0 
					and not (
						(read_ptr - write_ptr) mod DEPTH <= 0 and 
						(read_ptr + var_read_size - write_ptr) mod DEPTH > 0);

				if write then
					for i in 0 to WRITE_PORTS - 1 loop
						if i < var_write_size then
							var_rank := write_ptr mod max_ports;

							mem(var_rank)(read_rank_ptr(var_rank)) <= 
								write_data(8 * i + 7 downto 8 * i);

							write_ptr := write_ptr + 1;
						end if;
					end loop;
				end if;

				if read then
					for i in 0 to READ_PORTS - 1 loop
						if i < var_read_size then
							
							var_rank := read_ptr mod max_ports;

							read_data(i * 8 + 7 downto i * 8) <= 
								mem(var_rank)(write_rank_ptr(var_rank));

							read_ptr := read_ptr + 1;
						end if;
					end loop;

					read_valid <= '1';
				end if;

				read_ptr_sig <= read_ptr;
				write_ptr_sig <= write_ptr;
			end if;
		end if;
	end process;
end architecture;