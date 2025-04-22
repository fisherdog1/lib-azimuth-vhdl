library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity sync_fifo is
	generic (
		WIDTH : positive;
		DEPTH : positive);
	port (
		--System
		clk : std_ulogic;
		rst : std_ulogic;

		--Write side
		write_data : std_ulogic_vector(WIDTH - 1 downto 0);
		write_data_valid : std_ulogic;
		write_data_ready : out std_ulogic;

		--Read side
		read_data : out std_ulogic_vector(WIDTH - 1 downto 0);
		read_data_valid : buffer std_ulogic := '0';
		read_data_ready : std_ulogic;

		--Other
		count : out natural range 0 to DEPTH - 1);
end entity;

architecture rtl of sync_fifo is
	subtype ptr_t is natural range 0 to DEPTH - 1;

	signal write_ptr : ptr_t := 0;
	signal read_ptr : ptr_t := 0;

	signal write : boolean;
	signal read : boolean;

	signal write_full : boolean;
	signal read_empty : boolean;

	subtype data_t is std_ulogic_vector(WIDTH - 1 downto 0);
	type mem_t is array (0 to DEPTH - 1) of data_t;

	signal mem : mem_t;
begin
	write_full <= (write_ptr + 1) mod DEPTH = read_ptr;
	read_empty <= read_ptr = write_ptr;

	write <= write_data_valid = '1' and not write_full;
	read <= read_data_ready = '1' and not read_empty;

	write_data_ready <= '1' when not write_full else '0';

	count <= (write_ptr - read_ptr) mod DEPTH;

	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				write_ptr <= 0;
				read_ptr <= 0;

				read_data_valid <= '0';
			else
				if read_data_valid = '1' and read_data_ready = '1' then
					read_data_valid <= '0';
				end if;

				if read then
					read_data <= mem(read_ptr);
					read_data_valid <= '1';

					read_ptr <= (read_ptr + 1) mod DEPTH;
				end if;

				if write then
					mem(write_ptr) <= write_data;

					write_ptr <= (write_ptr + 1) mod DEPTH;
				end if;
			end if;
		end if;
	end process;
end architecture;