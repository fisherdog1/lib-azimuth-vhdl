library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity clock_enable_divider is
	generic (
		--Whether the enable is active on the first cycle
		--otherwise, the first enable happens at the first overflow
		FIRST_CYCLE : boolean := true;

		--Whether to change the divider value on the next clock cycle
		--Otherwise, waits for the current cycle to end
		CHANGE_DIVIDER_IMMEDIATELY : boolean := true);
	port (
		clk, rst : in std_ulogic;
		clkdiv_en : out std_ulogic;

		divider : in unsigned);
end entity;

architecture rtl of clock_enable_divider is
	subtype divider_t is unsigned(divider'length - 1 downto 0);

	signal counter, divider_buf : divider_t;
	signal load_value : divider_t;
begin
	clkdiv_en <= '1' when counter >= divider_buf and rst = '0' else '0';

	enable_first_cycle: if FIRST_CYCLE generate
		load_value <= divider;
	end generate;

	disable_first_cycle: if not FIRST_CYCLE generate
		load_value <= to_unsigned(1, divider_t'length);
	end generate;

	process (clk, divider)
	begin
		if CHANGE_DIVIDER_IMMEDIATELY then
			divider_buf <= divider;
		end if;	

		if rising_edge(clk) then
			if rst = '1' then
				counter <= load_value;

				if not CHANGE_DIVIDER_IMMEDIATELY then
					divider_buf <= divider;
				end if;
			elsif counter >= divider_buf then
				counter <= to_unsigned(1, divider_t'length);

				if not CHANGE_DIVIDER_IMMEDIATELY then
					divider_buf <= divider;
				end if;
			else
				counter <= counter + 1;
			end if;
		end if;
	end process;
end architecture;