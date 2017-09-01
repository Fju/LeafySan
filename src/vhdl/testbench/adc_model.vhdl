-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : ADC Model
-- Last update  : 27.04.2015
-----------------------------------------------------------------

-- Libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity adc_model is
	generic(
		SYSTEM_CYCLE_TIME 	: time := 20 ns; -- 50 MHz
		FULL_DEBUG 			: natural := 0;
		FILE_NAME_PRELOAD 	: string := "adc_preload.txt"
	);
	port(
		-- Global Signals
		end_simulation : in  std_ulogic;
		-- SPI Signals
		spi_clk 	   : in  std_ulogic;
		spi_miso 	   : out std_logic;
		spi_cs_n 	   : in  std_ulogic;
		-- Switch Signals
		swt_select	   : in  std_ulogic_vector(2 downto 0);
		swt_enable_n   : in  std_ulogic
	);
end entity adc_model;

architecture sim of adc_model is
	
	file file_preload 	: text open read_mode is FILE_NAME_PRELOAD;
	
	type   adc_reg_t is array (0 to 7) of std_ulogic_vector(15 downto 0);
	
	signal tx : std_ulogic_vector(15 downto 0);
	
	signal swt_sel_lut : std_ulogic_vector(2 downto 0);
	
begin

	process
		variable adc_reg     			: adc_reg_t;
		variable active_line, out_line	: line;
		variable cnt 		 			: natural := 0;
		variable neol 		 			: boolean := false;
		variable adc_val 	 			: real := 0.000;
	begin
	
		adc_reg := (others => (others => 'U'));
		tx 		<= (others => 'U');
		
		-- force wait for 1 ps to display full-debug messages after library warnings
		if FULL_DEBUG = 1 then 
			wait for 1 ps;
		end if;
		
		-- preload data from adc file here...
		while not endfile(file_preload) loop
			readline(file_preload, active_line);
			loop
				read(active_line, adc_val, neol);
				exit when not neol;
				exit when cnt = 8;
				adc_reg(cnt) := std_ulogic_vector(to_unsigned(integer(adc_val*real(4096)/real(3.3)), tx'length));
				-- display read values from file
				if FULL_DEBUG = 1 then 
					write(out_line, "[ADC] Preloading channel " & integer'image(cnt) & " with ");
					write(out_line, adc_val, right, 3, 3);
					write(out_line, 'V');
					writeline(output, out_line);
				end if;
				cnt := cnt + 1;
			end loop;
			exit when cnt = 8;
		end loop;
		
		file_close(file_preload);
	
		-- display unassigned channels
		if FULL_DEBUG = 1 then 
			if cnt < 8 then 
				for i in cnt to 7 loop
					write(out_line, "[ADC] Channel " & integer'image(i) & " is unassigned!");
					writeline(output, out_line);
				end loop;
			end if;
		end if;
		
		-- do real work (send adc-values by request)
		loop
			exit when end_simulation = '1';
			if spi_cs_n = '0' then
				if swt_enable_n = '0' then
					-- data has to be sent out shifted one bit to the left (as in actual chip)
					tx <= adc_reg(to_integer(unsigned(swt_sel_lut)))(14 downto 0) & '0';
				else
					tx <= (others => 'U');
				end if;
				
				for i in 0 to 15 loop
					wait until spi_clk = '1';
					wait until spi_clk = '0';
					tx <= tx(14 downto 0) & '0';
				end loop;	
				wait until spi_cs_n = '1';
			else
				wait for SYSTEM_CYCLE_TIME;
			end if;
		end loop;
		wait;
	end process;

	spi_miso <= '0' when tx(15) = '0' AND spi_cs_n = '0' else 'Z';
	
	-- lut to map swt_select to correct register content (inverse to interface)
	process(swt_select)
		variable sel : natural;
	begin
		sel := to_integer(unsigned(swt_select));
		case sel is
			when 0 => swt_sel_lut <= std_ulogic_vector(to_unsigned(5, swt_sel_lut'length));
			when 1 => swt_sel_lut <= std_ulogic_vector(to_unsigned(3, swt_sel_lut'length));
			when 2 => swt_sel_lut <= std_ulogic_vector(to_unsigned(1, swt_sel_lut'length));
			when 3 => swt_sel_lut <= std_ulogic_vector(to_unsigned(7, swt_sel_lut'length));
			when 4 => swt_sel_lut <= std_ulogic_vector(to_unsigned(6, swt_sel_lut'length));
			when 5 => swt_sel_lut <= std_ulogic_vector(to_unsigned(2, swt_sel_lut'length));
			when 6 => swt_sel_lut <= std_ulogic_vector(to_unsigned(4, swt_sel_lut'length));
			when 7 => swt_sel_lut <= std_ulogic_vector(to_unsigned(0, swt_sel_lut'length));
			when others => swt_sel_lut <= std_ulogic_vector(to_unsigned(5, swt_sel_lut'length));
		end case;
	end process;

end architecture sim;