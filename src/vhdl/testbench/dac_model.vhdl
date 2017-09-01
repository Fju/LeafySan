-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : DAC Model
-- Last update  : 02.12.2013
-----------------------------------------------------------------

-- Libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity dac_model is
	generic(
		SYSTEM_CYCLE_TIME 	: time := 20 ns; -- 50 MHz
		FILE_NAME_DUMP 		: string := "dac_dump.txt"
	);
	port(
		-- Global Signals
		end_simulation : in  std_ulogic;
		-- SPI Signals
		spi_clk 	   : in std_ulogic;
		spi_mosi 	   : in std_ulogic;
		spi_cs_n 	   : in std_ulogic;
		-- DAC Signals
		dac_ldac_n	   : in std_ulogic
	);
end entity dac_model;

architecture sim of dac_model is
	
	type   dac_reg_t is array (0 to 1) of real;
	signal rx : std_ulogic_vector(15 downto 0);
	
	file file_dump 		: text open write_mode is FILE_NAME_DUMP;
	
begin

	process
		variable vref 	 : real := 2.048;
		variable dac_out : dac_reg_t;
		variable dac_pre : dac_reg_t;
		variable v_out   : string(1 to 4);
		variable outLine : line;
	begin
		dac_out := (others => (real(0)));
		dac_pre := (others => (real(0)));
		rx		<= (others => '0');
		
		loop
			exit when end_simulation = '1';
			if spi_cs_n = '0' then
				for i in 0 to 15 loop
					wait until spi_clk = '1';
					rx <= rx(14 downto 0) & spi_mosi;
					wait until spi_clk = '0';
				end loop;	
				wait until spi_cs_n = '1';
				if rx(13) = '1' then
					dac_pre(to_integer(unsigned(rx(15 downto 15)))) := vref * real(to_integer(unsigned(rx(11 downto 4)))) / real(256);
				else
					dac_pre(to_integer(unsigned(rx(15 downto 15)))) := real(2) * vref * real(to_integer(unsigned(rx(11 downto 4)))) / real(256);
				end if;
				if dac_pre(to_integer(unsigned(rx(15 downto 15)))) > real(3.3) then
					dac_pre(to_integer(unsigned(rx(15 downto 15)))) := real(3.3);
				end if;
			else
				wait for SYSTEM_CYCLE_TIME;
			end if;
			if dac_ldac_n = '0' then
				for i in 0 to 1 loop
					if dac_pre(i) /= dac_out(i) then
						dac_out(i) := dac_pre(i);
						v_out := integer'image(integer(dac_out(i)*real(1000)));
						write(outLine, "DAC" & integer'image(i) & " = " & v_out(1) & "." & v_out(2 to 4) & "V");
						writeline(file_dump, outLine);
						write(outLine, "[DAC] Setting output voltage of DAC" & integer'image(i) & " to " & v_out(1) & "." & v_out(2 to 4) & "V");
						writeline(output, outLine);
					end if;
				end loop;
			end if;
		end loop;
		
		file_close(file_dump);
		
		wait;
	end process;
	
end architecture sim;