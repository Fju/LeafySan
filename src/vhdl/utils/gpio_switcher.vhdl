-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : GPIO Switcher
-- Last update  : 22.07.2014
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gpio_switcher is
	port (		
		gpio 		: inout std_logic_vector(15 downto 0);
		gp_ctrl 	: in 	std_ulogic_vector(15 downto 0);
		gp_in 		: out 	std_ulogic_vector(15 downto 0);
		gp_out 		: in	std_ulogic_vector(15 downto 0)
    );
end gpio_switcher;

architecture rtl of gpio_switcher is

begin

	process (gpio, gp_ctrl, gp_out)
	begin
		
		for i in 0 to 15 loop
		
			-- read / in
			if gp_ctrl(i) = '0' then	
				gpio(i) 	<= 'Z';
				gp_in(i) 	<= gpio(i);
				
 			-- write / out				
			else
				gpio(i) 	<= gp_out(i);
				gp_in(i) 	<= '0';
			end if;
			
		end loop;
  
	end process;

end architecture rtl;