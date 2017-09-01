-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : UART-Model for Simulation
-- Last update  : 28.11.2013
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity infrared_model is
	generic (
		SYSTEM_CYCLE_TIME 	: time := 20 ns; -- 50 MHz
		-- file with bytes to be send to fpga
		FILE_NAME_COMMAND 	: string := "ir_command.txt";
		-- custom code of ir-sender
		CUSTOM_CODE 		: std_ulogic_vector(15 downto 0) := x"6B86";
		SIMULATION 			: boolean := true
	);
	port (
		-- global signals
		end_simulation	: in  std_ulogic;
		-- ir-pin
		irda_txd 		: out std_ulogic
    );
end infrared_model;

architecture sim of infrared_model is

	constant MAX_NO_OF_BYTES : natural := 128;
	
	-- startbit LOW time: 9.0 ms
	constant CV_STARTBIT_LOW_REAL	: time := 1 us * 9000;
	constant CV_STARTBIT_LOW_SIM	: time := SYSTEM_CYCLE_TIME * 90;
	-- startbit HIGH time: 4.5 ms
	constant CV_STARTBIT_HIGH_REAL 	: time := 1 us * 4500;
	constant CV_STARTBIT_HIGH_SIM 	: time := SYSTEM_CYCLE_TIME * 45;
	-- databit LOW time: 0.6 ms
	constant CV_DATA_LOW_REAL 		: time := 1 us * 600;
	constant CV_DATA_LOW_SIM 		: time := SYSTEM_CYCLE_TIME * 6;
	-- databit '0' HIGH time: 0.52 ms
	constant CV_DATA0_HIGH_REAL 	: time := 1 us * 520;
	constant CV_DATA0_HIGH_SIM 		: time := SYSTEM_CYCLE_TIME * 5;
	-- databit '1' HIGH time: 1.66 ms
	constant CV_DATA1_HIGH_REAL 	: time := 1 us * 1660;
	constant CV_DATA1_HIGH_SIM 		: time := SYSTEM_CYCLE_TIME * 16;
	

	file file_command	: text open read_mode is FILE_NAME_COMMAND;
	
	type bytelist_t is array (0 to MAX_NO_OF_BYTES-1) of std_ulogic_vector(7 downto 0);
	
begin 
	-- send data to fpga
	ir_send : process
		variable commandlist : bytelist_t;
		variable active_line : line;
		variable neol : boolean := false;
		variable data_value : integer;
		variable cnt : natural := 0;
	begin
		-- set line to "no data"
		irda_txd <= '1';
	
		-- preload list with undefined
		commandlist := (others => (others => 'U'));
		
		-- read preload file
		while not endfile(file_command) loop
			-- read line
			readline(file_command, active_line);
			-- loop until end of line
			loop
				read(active_line, data_value, neol);
				exit when not neol;
				-- write command to array
				commandlist(cnt) := std_ulogic_vector(to_signed(data_value, 8));
				-- increment counter
				cnt := cnt + 1;
			end loop;
		end loop;
		
		file_close(file_command);
	
		-- send data to fpga
		for i in 0 to MAX_NO_OF_BYTES-1 loop
			-- check if byte is valid, else stop
			if commandlist(i)(0) /= 'U' then 
				
				-- wait some cycles before start
				wait for 10*SYSTEM_CYCLE_TIME;
				
				-- ir send procedure				
				-- start sequence
				irda_txd <= '0';
				if SIMULATION = false then 	wait for CV_STARTBIT_LOW_REAL;
				else						wait for CV_STARTBIT_LOW_SIM;
				end if;
				irda_txd <= '1';
				if SIMULATION = false then 	wait for CV_STARTBIT_HIGH_REAL;
				else						wait for CV_STARTBIT_HIGH_SIM;
				end if;
				
				-- loop over custom code
				for j in 0 to 15 loop
					irda_txd <= '0';
					if SIMULATION = false then 	wait for CV_DATA_LOW_REAL;
					else						wait for CV_DATA_LOW_SIM;
					end if;
					
					irda_txd <= '1';
					if CUSTOM_CODE(j) = '1' then
						if SIMULATION = false then 	wait for CV_DATA1_HIGH_REAL;
						else						wait for CV_DATA1_HIGH_SIM;
						end if;
					else
						if SIMULATION = false then 	wait for CV_DATA0_HIGH_REAL;
						else						wait for CV_DATA0_HIGH_SIM;
						end if;
					end if;
					
				end loop;
				
				-- loop over data
				for j in 0 to 7 loop
					irda_txd <= '0';
					if SIMULATION = false then 	wait for CV_DATA_LOW_REAL;
					else						wait for CV_DATA_LOW_SIM;
					end if;
					
					irda_txd <= '1';
					if commandlist(i)(j) = '1' then
						if SIMULATION = false then 	wait for CV_DATA1_HIGH_REAL;
						else						wait for CV_DATA1_HIGH_SIM;
						end if;
					else
						if SIMULATION = false then 	wait for CV_DATA0_HIGH_REAL;
						else						wait for CV_DATA0_HIGH_SIM;
						end if;
					end if;
					
				end loop;
				
				-- loop over not(data)
				for j in 0 to 7 loop
					irda_txd <= '0';
					if SIMULATION = false then 	wait for CV_DATA_LOW_REAL;
					else						wait for CV_DATA_LOW_SIM;
					end if;
					
					irda_txd <= '1';
					if not(commandlist(i)(j)) = '1' then
						if SIMULATION = false then 	wait for CV_DATA1_HIGH_REAL;
						else						wait for CV_DATA1_HIGH_SIM;
						end if;
					else
						if SIMULATION = false then 	wait for CV_DATA0_HIGH_REAL;
						else						wait for CV_DATA0_HIGH_SIM;
						end if;
					end if;
				end loop;
				
				-- stop bit
				irda_txd <= '0';
				if SIMULATION = false then 	wait for CV_DATA_LOW_REAL;
				else						wait for CV_DATA_LOW_SIM;
				end if;
				
				-- idle
				irda_txd <= '1';
				
				write(active_line, string'("[IR] Sent "));
				write(active_line, to_integer(unsigned(commandlist(i))));
				write(active_line, string'(" ("));
				write(active_line, to_bitvector(commandlist(i)));
				write(active_line, string'(") to FPGA."));
				writeline(output, active_line);
				
				-- wait for some cycles before continuing
				wait for 20*SYSTEM_CYCLE_TIME;

			end if;
		end loop;
		
		-- wait forever
		wait;
	end process ir_send;

end sim;