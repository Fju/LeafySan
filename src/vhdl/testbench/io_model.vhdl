---------------------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : simple filebased model for GP-In, Switches & Pushbuttons
-- Last update  : 27.04.2015
---------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity io_model is
	generic(
		-- file containing static bit-settings for io's
		FILE_NAME_SET 		: string := "io.txt"
	);
	port(
		-- io's
		gpio 				: inout	std_logic_vector(15 downto 0);
		switch				: out	std_ulogic_vector(17 downto 0);
		key 				: out	std_ulogic_vector(2  downto 0)
	);
end io_model;


architecture sim of io_model is

	-- file containing static bit-settings for io's
	-- order of bits: gp_in(0) ... gp_in(15), switch(0) ... switch(17), key_n(0) ... key_n(2)
	file file_set 	: text open read_mode is FILE_NAME_SET;

begin 
	
	process
		variable active_line 	: line;
		variable neol 			: boolean := false;
		variable char_value 	: character := '0';
		variable cnt 			: natural := 0;
	begin
	
		-- preset io's
		switch	<= (others => 'U');
		key		<= (others => 'U');
		
		-- read bit-settings file
		while not endfile(file_set) loop
			-- read line
			readline(file_set, active_line);
			-- loop until end of line
			loop
				-- read integer from line
				read(active_line, char_value, neol);
				-- exit when line has ended
				exit when not neol;
				-- chancel when enough data is read
				exit when cnt = 16 + 18 + 3;
				
				-- write data to output
				if cnt < 16 then
					-- gpio
					if char_value = '1' then
						gpio(cnt) <= '1';
					elsif char_value = '0' then
						gpio(cnt) <= '0';
					elsif char_value = 'Z' then
						gpio(cnt) <= 'Z';
					else
						gpio(cnt) <= 'U';
					end if;
					
				elsif cnt < 16 + 18 then
					-- switch
					if char_value = '1' then
						switch(cnt-16) <= '1';
					elsif char_value = '0' then
						switch(cnt-16) <= '0';
					else
						switch(cnt-16) <= 'U';
					end if;
					
				else
					-- key
					if char_value = '1' then
						key(cnt-16-18) <= '1';
					elsif char_value = '0' then
						key(cnt-16-18) <= '0';
					else
						key(cnt-16-18) <= 'U';
					end if;
					
				end if;
				
				-- increment counter
				cnt := cnt + 1;
			end loop;
		end loop;
		
		file_close(file_set);
		
		wait;
	end process;

end sim;
