-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : SRAM-Model (a very very very simple model) for Simulation
-- Last update  : 02.12.2013
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.iac_pkg.all;

entity sram_model is
	generic(
		SYSTEM_CYCLE_TIME 	: time := 20 ns; -- 50 MHz
		FULL_DEBUG 			: natural := 0;
		-- file for preload of sram
		FILE_NAME_PRELOAD 	: string := "preload.txt";
		-- file for dump at end of simulation
		FILE_NAME_DUMP 		: string := "dump.txt";
		-- number of addressable words in sram (size of sram)
		GV_SRAM_SIZE 		: natural := 2**20
	);
	port(
		-- global signals
		end_simulation 	: in 	std_ulogic;
		-- sram connections
		sram_ce_n		: in	std_ulogic;
		sram_oe_n		: in	std_ulogic;
		sram_we_n		: in	std_ulogic;
		sram_ub_n		: in	std_ulogic;
		sram_lb_n		: in	std_ulogic;
		sram_addr		: in	std_ulogic_vector(19 downto 0);
		sram_dq			: inout	std_logic_vector(15 downto 0)
	);
end sram_model;


architecture sim of sram_model is

	constant DUMP_WORDS_PER_LINE : natural := 8;

	-- files
	file file_preload 	: text open read_mode is FILE_NAME_PRELOAD;
	file file_dump 		: text open write_mode is FILE_NAME_DUMP;
	
	-- internal representation of sram (data-array)
	type sram_data_t is array (0 to GV_SRAM_SIZE-1) of std_ulogic_vector(sram_dq'length-1 downto 0);
	signal sram_data : sram_data_t;
	
begin 
	
	-- set outgoing signals
	sram_dq <= 	std_logic_vector(sram_data(to_integer(unsigned(sram_addr)))) when (sram_ce_n = '0' and sram_we_n = '1') else 
				(others => 'Z');
	
	
	process
		variable active_line 	: line;
		variable neol 			: boolean := false;
		variable data_value 	: integer := 0;
		variable cnt 			: natural := 0;
	begin
		-- preload data from file
		-- prefill array with undefined
		sram_data <= (others => (others => 'U'));
		
		-- read preload file
		while not endfile(file_preload) loop
			-- read line
			readline(file_preload, active_line);
			-- loop until end of line
			loop
				-- read integer from line
				read(active_line, data_value, neol);
				-- exit when line has ended
				exit when not neol;
				-- chancel when sram is already full
				exit when cnt = GV_SRAM_SIZE-1;
				-- write data to array
				sram_data(cnt) <= std_ulogic_vector(to_signed(data_value, sram_dq'length));
				-- increment counter
				cnt := cnt + 1;
			end loop;
		end loop;
		
		file_close(file_preload);
		
		
		loop
			-- stop when simulation has ended
			exit when end_simulation = '1';
			
			-- chip enable detected
			if sram_ce_n = '0' then
				-- write (read outside the process)			
				if sram_we_n = '0' then
					-- write data to array
					sram_data(to_integer(unsigned(sram_addr))) <= std_ulogic_vector(sram_dq);
					
					if FULL_DEBUG = 1 then 
						write(active_line, string'("[SRAM] Write "));
						write(active_line, to_integer(unsigned(sram_dq)));
						write(active_line, string'(" ("));
						write(active_line, to_bitvector(sram_dq));
						write(active_line, string'(") to Addr "));
						write(active_line, to_integer(unsigned(sram_addr)));
						write(active_line, string'("."));
						writeline(output, active_line);
					end if;
				-- read
				else
					if FULL_DEBUG = 1 then
						write(active_line, string'("[SRAM] Read "));
						write(active_line, to_integer(unsigned(sram_data(to_integer(unsigned(sram_addr))))));
						write(active_line, string'(" ("));
						write(active_line, to_bitvector(sram_data(to_integer(unsigned(sram_addr)))));
						write(active_line, string'(") from Addr "));
						write(active_line, to_integer(unsigned(sram_addr)));
						write(active_line, string'("."));
						writeline(output, active_line);
					end if;
				end if;
			end if;
			
			-- wait for one cycle
			wait for SYSTEM_CYCLE_TIME;
			
		end loop;
		
	
		-- dump data to file after simulation was ended		
		-- loop over sram-size, with 4 words per line
		for i in 0 to (GV_SRAM_SIZE/DUMP_WORDS_PER_LINE)-1 loop
			--write(active_line, hex(std_ulogic_vector(to_unsigned(i*DUMP_WORDS_PER_LINE,to_log16(GV_SRAM_SIZE)*4))) & ":   ");

			for j in 0 to DUMP_WORDS_PER_LINE-1 loop
				--write(active_line, hex(sram_data(i*DUMP_WORDS_PER_LINE+j)));
				
				if j /= DUMP_WORDS_PER_LINE-1 then 
					if (((j+1) mod 4) = 0) then 
						write(active_line, string'("   "));
					else 
						write(active_line, string'(" "));
					end if;
				end if;
				
			end loop;

			writeline(file_dump, active_line);
		end loop;
		
		file_close(file_dump);
		-- wait forever
		wait;
	end process;

end sim;
