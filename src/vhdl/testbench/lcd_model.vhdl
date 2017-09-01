-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : LCD-Display Model
-- Last update  : 04.12.2013
-----------------------------------------------------------------

-- Libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity lcd_model is
	generic(
		SYSTEM_CYCLE_TIME 	: time 	  := 20 ns; -- 50 MHz
		FULL_DEBUG 			: natural := 0
	);
	port(
		-- Global Signals
		end_simulation : in  std_ulogic;
		-- LCD Signals
		disp_en 	   : in  std_ulogic;
        disp_rs 	   : in  std_ulogic;
        disp_rw 	   : in  std_ulogic;
        disp_dat	   : in  std_ulogic_vector(7 downto 0)
	);
end entity lcd_model;

architecture sim of lcd_model is

	type lcd_t is array (0 to 1) of string(1 to 16);

begin

	process
		variable lcd : lcd_t;
		variable col, row  : integer;
		variable outLine   : line;
		variable disp_on   : std_ulogic;
		variable cursor_on : std_ulogic;
		variable blink_on  : std_ulogic;
	begin
		lcd 	  := (others => (others => ' '));
		col 	  :=  0;
		row 	  :=  0;
		disp_on   := '0';
		cursor_on := '0';
		blink_on  := '0';
		
		loop
			exit when end_simulation = '1';
			if disp_en = '1' then
				-- Function setting
				if disp_rs = '0' then 
				
					-- Set DDRAM Address (Set Cursor)
					if disp_dat(7) = '1' then
						col := to_integer(unsigned(disp_dat(3 downto 0)));
						row := to_integer(unsigned(disp_dat(6 downto 6)));
						if FULL_DEBUG = 1 then
							write(outLine, "[LCD] Setting cursor to position " & integer'image(col) & " and line " & integer'image(row));
							writeline(output, outLine);
						end if;
						
					-- Set CDRAM Address (can't happen)
					elsif disp_dat(6) = '1' then
						-- not implemented yet
						
					-- Function set
					elsif disp_dat(5) = '1' then
						if FULL_DEBUG = 1 then
							write(outLine, string'("[LCD] Function setting: "));
							writeline(output, outLine);
							if disp_dat(4) = '1' then
								write(outLine, string'("        Data width   -> 8 bit"));
							else
								write(outLine, string'("        Data width   -> 4 bit"));
							end if;
							writeline(output, outLine);
							if disp_dat(3) = '1' then
								write(outLine, string'("        Number lines -> 2"));
							else
								write(outLine, string'("        Number lines -> 1"));
							end if;
							writeline(output, outLine);
							if disp_dat(2) = '1' then
								write(outLine, string'("        Dots format  -> 5x11"));
							else
								write(outLine, string'("        Dots format  -> 5x8"));
							end if;
							writeline(output, outLine);
						end if;
						
					-- Cursor or Display Shift
					elsif disp_dat(4) = '1' then
						if FULL_DEBUG = 1 then
							write(outLine, string'("[LCD] Setting "));
							if disp_dat(3) = '1' then
								write(outLine, string'("shift all the display "));
							else
								write(outLine, string'("shift cursor "));
							end if;
							if disp_dat(2) = '1' then
								write(outLine, string'("to right"));
							else
								write(outLine, string'("to left"));
							end if;
							writeline(output, outLine);
						end if;
						
					-- Display On/Off Control
					elsif disp_dat(3) = '1' then
						-- Display on/off
						if disp_dat(2) /= disp_on then
							disp_on := disp_dat(2);
							if FULL_DEBUG = 1 then
								if disp_dat(2) = '1' then
									write(outLine, string'("[LCD] Setting display on"));
								else
									write(outLine, string'("[LCD] Setting display off"));
								end if;
								writeline(output, outLine);
							end if;
						end if;
						
						-- Cursor on/off
						if disp_dat(1) /= cursor_on then
							cursor_on := disp_dat(1);
							if FULL_DEBUG = 1 then
								if disp_dat(1) = '1' then
									write(outLine, string'("[LCD] Setting cursor on"));
								else
									write(outLine, string'("[LCD] Setting cursor off"));
								end if;
								writeline(output, outLine);
							end if;
						end if;
						
						-- Blink on/off
						if disp_dat(0) /= blink_on then
							blink_on := disp_dat(0);
							if FULL_DEBUG = 1 then
								if disp_dat(0) = '1' then
									write(outLine, string'("[LCD] Setting blink on"));
								else
									write(outLine, string'("[LCD] Setting blink off"));
								end if;
								writeline(output, outLine);
							end if;
						end if;
						
					-- Entry mode set
					elsif disp_dat(2) = '1' then
						if FULL_DEBUG = 1 then
							write(outLine, string'("[LCD] Setting "));
							if disp_dat(1) = '1' then
								write(outLine, string'("DDRAM increment mode, "));
							else
								write(outLine, string'("DDRAM decrement mode, "));
							end if;
							if disp_dat(0) = '1' then
								write(outLine, string'("shift entire display on"));
							else
								write(outLine, string'("shift entire display off"));
							end if;
							writeline(output, outLine);
						end if;
						
					-- Return Home
					elsif disp_dat(1) = '1' then
						col := 0;
						row := 0;
						if FULL_DEBUG = 1 then
							write(outLine, string'("[LCD] Setting cursor to position " & integer'image(col) & " and line " & integer'image(row)));
							writeline(output, outLine);
						end if;
						
					-- Clear Display
					else
						lcd := (others => (others => ' '));
						col := 0;
						row := 0;
						write(outLine, string'("[LCD] Clear Display"));
						writeline(output, outLine);
						write(outLine, string'("[LCD] Actual display:"));
						writeline(output, outLine);
						write(outLine, string'("      Line 0: |" & lcd(0) & "|"));
						writeline(output, outLine);
						write(outLine, string'("      Line 1: |" & lcd(1) & "|"));
						writeline(output, outLine);
						if FULL_DEBUG = 1 then
							write(outLine, string'("[LCD] Setting cursor to position " & integer'image(col) & " and line " & integer'image(row)));
							writeline(output, outLine);
						end if;
					end if;
				
				-- Print charachter
				else 
					lcd(row)(col+1) := character'val(to_integer(unsigned(disp_dat)));
					write(outLine, string'("[LCD] Printing character '" & lcd(row)(col+1) & "' on LCD"));
					writeline(output, outLine);
					write(outLine, string'("[LCD] Actual display:"));
					writeline(output, outLine);
					write(outLine, string'("      Line 0: |" & lcd(0) & "|"));
					writeline(output, outLine);
					write(outLine, string'("      Line 1: |" & lcd(1) & "|"));
					writeline(output, outLine);
				end if;
			
				wait until disp_en = '0';
			else
				wait for SYSTEM_CYCLE_TIME;
			end if;
		end loop;
		wait;
	end process;

end architecture sim;