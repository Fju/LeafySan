-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : simple clock generator (e.g. for spi clocks)
-- Author 		: Jan Dürre
-- Last update  : 24.04.2014
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity clock_generator is
	generic(
		GV_CLOCK_DIV	: natural := 50
	);
	port (
		clock   		: in  std_ulogic;
		reset_n 		: in  std_ulogic;
		enable  		: in  std_ulogic;
		clock_out 		: out std_ulogic
	);
end clock_generator;

architecture rtl of clock_generator is
	signal counter, counter_nxt : unsigned(to_log2(GV_CLOCK_DIV)-1 downto 0);
begin
	
	process(clock, reset_n)
	begin
		if reset_n = '0' then
			counter <= (others => '0');
		elsif rising_edge(clock) then
			counter <= counter_nxt;
		end if;	
	end process;
	
	counter_nxt <= (others => '0') when (counter = GV_CLOCK_DIV-1) or (enable  = '0') else
					counter + 1;
	
	clock_out 	<= 	'1' when (counter >= GV_CLOCK_DIV/2) and (enable  = '1') else
					'0';

end architecture rtl;