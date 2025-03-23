library work;
	use work.
--pasteme package+\
.all;

entity unit_tests is
end entity;

--snippet unit_test
report "
--pasteme tests\
" severity note;
--
if not (
--pasteme tests\
) then 
	report "FAIL" severity error;
	exit; 
end if;
--endsnippet foreach tests

architecture sim of unit_tests is
begin
	process
	begin
		loop
			--pasteme unit_test+

			assert false report "Tests !PASS!" severity failure;
		end loop;
		
		assert false report "Tests !FAIL!" severity failure;
	end process;
end architecture sim;