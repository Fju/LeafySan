-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : 7-Segment-Display Model
-- Last update  : 04.12.2013
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.standard.all;
use std.textio.all;

entity seven_seg_model is
	generic (
		SYSTEM_CYCLE_TIME 	: time := 20 ns -- 50 MHz
	);
	port (
		-- global signals
		end_simulation 	: in std_ulogic;
		-- 7-seg connections
		hex0_n			: in std_ulogic_vector(6 downto 0);
		hex1_n			: in std_ulogic_vector(6 downto 0);
		hex2_n			: in std_ulogic_vector(6 downto 0);
		hex3_n			: in std_ulogic_vector(6 downto 0);
		hex4_n			: in std_ulogic_vector(6 downto 0);
		hex5_n			: in std_ulogic_vector(6 downto 0);
		hex6_n			: in std_ulogic_vector(6 downto 0);
		hex7_n			: in std_ulogic_vector(6 downto 0)
	);
	
end seven_seg_model;


architecture sim of seven_seg_model is

	-- model can only be used with the iac-seven_seg-interface, only 0,1,2,3,4,5,6,7,8,9,0,A,b,C,d,E,F, ,-,X are possible values
	
	-- convert 7-seg to character
	function seg_to_char(segments : std_ulogic_vector(6 downto 0)) return character is
		variable tmp : character;
	begin
	
		-- decode 7-segment (inverted!)
		case segments is 
			when "1000000" 	=> tmp := '0'; -- 0
			when "1111001" 	=> tmp := '1'; -- 1
			when "0100100" 	=> tmp := '2'; -- 2
			when "0110000" 	=> tmp := '3'; -- 3
			when "0011001" 	=> tmp := '4'; -- 4
			when "0010010" 	=> tmp := '5'; -- 5
			when "0000010" 	=> tmp := '6'; -- 6
			when "1111000" 	=> tmp := '7'; -- 7
			when "0000000" 	=> tmp := '8'; -- 8
			when "0010000" 	=> tmp := '9'; -- 9
			when "0001000" 	=> tmp := 'A'; -- A
			when "0000011" 	=> tmp := 'b'; -- b
			when "1000110" 	=> tmp := 'C'; -- C
			when "0100001" 	=> tmp := 'd'; -- d
			when "0000110" 	=> tmp := 'E'; -- E
			when "0001110" 	=> tmp := 'F'; -- F
			when "1111111"	=> tmp := ' '; -- off
			when "0111111"	=> tmp := '-'; -- - (minus)
			when others 	=> tmp := 'X'; -- unexpected value: X
		end case;
		
		return tmp;
	
	end function seg_to_char;
	
begin 
		
	process
		-- line for textio
		variable active_line 		: line;
		-- internal vars for display-content, initialize empty
		variable seg0				: character := ' ';
		variable seg1				: character := ' ';
		variable seg2				: character := ' ';
		variable seg3				: character := ' ';
		variable seg4				: character := ' ';
		variable seg5				: character := ' ';
		variable seg6				: character := ' ';
		variable seg7				: character := ' ';
		variable display_changed 	: boolean 	:= false;
	begin
	
		loop
			-- stop when simulation has ended
			exit when end_simulation = '1';
			
			
			-- check if display should change (any display not turned off, and value differs from active display)
			--if (hex0_n /= "1111111") and (seg0 /= seg_to_char(hex0_n)) and hex0_n /= "UUUUUUU" then
			if (seg0 /= seg_to_char(hex0_n)) and hex0_n /= "UUUUUUU" then
				seg0 			:= seg_to_char(hex0_n);
				display_changed := true;
			end if;
			if (seg1 /= seg_to_char(hex1_n)) and hex1_n /= "UUUUUUU"  then
				seg1 			:= seg_to_char(hex1_n);
				display_changed := true;
			end if;
			if (seg2 /= seg_to_char(hex2_n)) and hex2_n /= "UUUUUUU"  then
				seg2 			:= seg_to_char(hex2_n);
				display_changed := true;
			end if;
			if (seg3 /= seg_to_char(hex3_n)) and hex3_n /= "UUUUUUU"  then
				seg3 			:= seg_to_char(hex3_n);
				display_changed := true;
			end if;
			if (seg4 /= seg_to_char(hex4_n)) and hex4_n /= "UUUUUUU"  then
				seg4 			:= seg_to_char(hex4_n);
				display_changed := true;
			end if;
			if (seg5 /= seg_to_char(hex5_n)) and hex5_n /= "UUUUUUU"  then
				seg5 			:= seg_to_char(hex5_n);
				display_changed := true;
			end if;
			if (seg6 /= seg_to_char(hex6_n)) and hex6_n /= "UUUUUUU"  then
				seg6 			:= seg_to_char(hex6_n);
				display_changed := true;
			end if;
			if (seg7 /= seg_to_char(hex7_n)) and hex7_n /= "UUUUUUU"  then
				seg7 			:= seg_to_char(hex7_n);
				display_changed := true;
			end if;
						
			
			-- display change -> printout
			if display_changed = true then
			
				-- generate printout
				write(active_line, string'("[7-SEG] ["));
				write(active_line, seg7);
				write(active_line, string'("]["));
				write(active_line, seg6);
				write(active_line, string'("] ["));
				write(active_line, seg5);
				write(active_line, string'("]["));
				write(active_line, seg4);
				write(active_line, string'("]  ["));
				write(active_line, seg3);
				write(active_line, string'("]["));
				write(active_line, seg2);
				write(active_line, string'("]["));
				write(active_line, seg1);
				write(active_line, string'("]["));
				write(active_line, seg0);
				write(active_line, string'("]"));
				
				writeline(output, active_line);
			
				-- reset display_changed
				display_changed := false;
			end if;
			
			-- wait for one cycle
			wait for SYSTEM_CYCLE_TIME;
			
		end loop;
		
		-- wait forever
		wait;
	end process;

end sim;
