-------------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : Simulation Model for WM8731
-- Author 		: Jan Duerre
-- Last update  : 02.09.2014
-- Description 	: This module provides samples over I2S-protocol. 
--				  Samples are read from a file. The samples are 
--				  read from file as pairs of integer-numbers, 
--				  alternating for the left and the right channel.
--				  Correct I2C communication is ack'ed but ignored.
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity acodec_model is
	generic (
		SAMPLE_WIDTH 	: natural 	:= 16;
		SAMPLE_RATE 	: natural 	:= 44100;
		SAMPLE_FILE 	: string 	:= "audio_samples.txt"
	);
	port (
		-- acodec signals
		aud_xclk 		: in    std_ulogic;
		aud_bclk		: out   std_ulogic;
		aud_adc_lrck	: out   std_ulogic;
		aud_adc_dat		: out   std_ulogic;
		aud_dac_lrck	: out   std_ulogic;
		aud_dac_dat		: in    std_ulogic;
		i2c_sdat		: inout std_logic;
		i2c_sclk		: in    std_logic
    );
end acodec_model;

architecture rtl of acodec_model is
	
	constant WM8731_SLAVE_ADDR 	: std_ulogic_vector(6 downto 0) := "0011010";
	constant AUDIO_SAMPLE_TIME 	: time := 1 us * 1000000/SAMPLE_RATE;
	
	signal aud_adc_dat_left 	: std_ulogic;
	signal aud_adc_dat_right 	: std_ulogic;
	
	signal aud_adc_lrck_int 	: std_ulogic := '1';
	signal aud_dac_lrck_int 	: std_ulogic := '1';
	
	-- internal data-array for preloaded samples from file
	constant MAX_NUMBER_OF_SAMPLES 	: natural := 256;
	signal number_of_samples 		: natural;

	file sample_f	: text open read_mode is SAMPLE_FILE;
	
	type sample_data_t is array (0 to MAX_NUMBER_OF_SAMPLES-1) of std_ulogic_vector(SAMPLE_WIDTH-1 downto 0);
	signal sample_data_left 	: sample_data_t;
	signal sample_data_right 	: sample_data_t;

begin

	-- preload samples from file
	process
		variable active_line 	: line;
		variable neol 			: boolean := false;
		variable sample_value 	: integer := 0;
		variable cnt 			: natural := 0;
	begin
		-- preset size
		number_of_samples 	<= 0;
	
		-- prefill array with undefined
		sample_data_left 	<= (others => (others => 'U'));
		sample_data_right 	<= (others => (others => 'U'));
		
		-- read preload file
		while ((not endfile(sample_f)) and (cnt /= MAX_NUMBER_OF_SAMPLES)) loop
			-- read line
			readline(sample_f, active_line);
			-- loop until end of line
			loop
				-- left:
				-- read integer from line
				read(active_line, sample_value, neol);
				-- exit when line has ended
				exit when not neol;
				-- write data to array
				sample_data_left(cnt) 	<= std_ulogic_vector(to_signed(sample_value, SAMPLE_WIDTH));
				
				-- right:
				-- read integer from line
				read(active_line, sample_value, neol);
				-- exit when line has ended
				exit when not neol;
				-- write data to array
				sample_data_right(cnt) 	<= std_ulogic_vector(to_signed(sample_value, SAMPLE_WIDTH));
				
				-- increment counter
				cnt := cnt + 1;
				
				-- chancel when sample array is already full
				exit when cnt = MAX_NUMBER_OF_SAMPLES;

			end loop;
			
		end loop;
		
		-- update size
		number_of_samples 	<= cnt;
		
		-- close file and sleep
		file_close(sample_f);
		wait;
		
	end process;
	
	
	
	aud_bclk 	 <= aud_xclk;
	aud_adc_lrck <= aud_adc_lrck_int;
	aud_dac_lrck <= aud_dac_lrck_int;
	
	aud_adc_dat <= aud_adc_dat_left or aud_adc_dat_right;
	
	
	-- generate left / right channel signal
	process
	begin
	
		wait until aud_xclk = '1';
		wait until aud_xclk = '0';
	
		loop
			aud_adc_lrck_int <= '1';
			aud_dac_lrck_int <= '1';
			wait for AUDIO_SAMPLE_TIME/2;
			wait until aud_xclk = '0';
			aud_adc_lrck_int <= '0';
			aud_dac_lrck_int <= '0';
			wait for AUDIO_SAMPLE_TIME/2;
			wait until aud_xclk = '0';
		end loop;
	end process;
	
	
	-- left channel
	process
		variable sample_ptr 	: integer := 0;
	begin
		aud_adc_dat_left <= '0';
		
		wait until aud_xclk = '1';
		wait until aud_xclk = '0';
	
		-- loop forever
		loop
			aud_adc_dat_left <= '0';
			
			-- wait for change of channel and synchronize with audio-clock (left channel)
			wait until (aud_adc_lrck_int = '0') and (aud_xclk = '0');
			-- pass first aud_xclk
			wait until rising_edge(aud_xclk);
			wait until falling_edge(aud_xclk);
			
			for i in SAMPLE_WIDTH-1 downto 0 loop
				aud_adc_dat_left	<= std_ulogic(sample_data_left(sample_ptr)(i));
				wait until rising_edge(aud_xclk);
				wait until falling_edge(aud_xclk);
			end loop;
			
			aud_adc_dat_left <= '0';
			
			-- inc data pointer
			if sample_ptr = number_of_samples - 1 then
				sample_ptr := 0;
			else
				sample_ptr := sample_ptr + 1;
			end if;
			
			-- wait for change of channel (if still in left channel)
			if aud_adc_lrck_int = '0' then
				wait until (aud_adc_lrck_int = '1');
			end if;
			
		end loop;
		
	end process;
	
	
	-- right channel
	process
		variable sample_ptr 	: integer := 0;
	begin
		aud_adc_dat_right <= '0';
		
		wait until aud_xclk = '1';
		wait until aud_xclk = '0';
		
		-- start with left channel: wait for that to finish
		wait until (aud_adc_lrck_int = '0');
		
		-- loop forever
		loop
			aud_adc_dat_right <= '0';
			
			-- wait for change of channel and synchronize with audio-clock (right channel)
			wait until (aud_adc_lrck_int = '1') and (aud_xclk = '0');
			-- pass first aud_xclk
			wait until rising_edge(aud_xclk);
			wait until falling_edge(aud_xclk);
			
			for i in SAMPLE_WIDTH-1 downto 0 loop
				aud_adc_dat_right	<= std_ulogic(sample_data_right(sample_ptr)(i));
				wait until rising_edge(aud_xclk);
				wait until falling_edge(aud_xclk);
			end loop;
			
			aud_adc_dat_right <= '0';
			
			-- inc data pointer
			if sample_ptr = number_of_samples - 1 then
				sample_ptr := 0;
			else
				sample_ptr := sample_ptr + 1;
			end if;
			
			-- wait for change of channel (if still in right channel)
			if aud_adc_lrck_int = '1' then
				wait until (aud_adc_lrck_int = '0');
			end if;

		end loop;
    
	end process;
	
	
	-- i2c slave: registers can only be written / reading is not supported
	process
		variable slave_addr : std_ulogic_vector(6 downto 0) := (others => '0');
	begin
		i2c_sdat <= 'Z';
	
		-- loop forever
		loop
			-- start condition
			wait until (falling_edge(i2c_sdat) and (i2c_sclk = '1'));
			-- slave addr
			for i in 6 downto 0 loop
				wait until rising_edge(i2c_sclk);
				slave_addr(i) := i2c_sdat;
				wait for 1 ns;
			end loop;
			-- r/w bit
			wait until rising_edge(i2c_sclk);
			-- correct slave address
			if slave_addr = WM8731_SLAVE_ADDR then
				-- write
				if i2c_sdat = '0' then
					-- ack
					wait until falling_edge(i2c_sclk);
					i2c_sdat <= '0';
					-- wait one i2c-cycle
					wait until rising_edge(i2c_sclk);
					wait until falling_edge(i2c_sclk);
					i2c_sdat <= 'Z';
					
					-- expecting 16 bit (2 byte)
					-- first byte
					for i in 0 to 7 loop
						wait until rising_edge(i2c_sclk);
						wait for 1 ns;
					end loop;
					-- ack
					wait until falling_edge(i2c_sclk);
					i2c_sdat <= '0';
					-- wait one i2c-cycle
					wait until rising_edge(i2c_sclk);
					wait until falling_edge(i2c_sclk);
					i2c_sdat <= 'Z';
					
					-- second byte
					for i in 0 to 7 loop
						wait until rising_edge(i2c_sclk);
						wait for 1 ns;
					end loop;
					-- ack
					wait until falling_edge(i2c_sclk);
					i2c_sdat <= '0';
					-- wait one i2c-cycle
					wait until rising_edge(i2c_sclk);
					wait until falling_edge(i2c_sclk);
					i2c_sdat <= 'Z';
					
					-- stop condition
					wait until (rising_edge(i2c_sdat) and (i2c_sclk = '1'));
					
				-- read
				else
					-- don't ack
					wait until falling_edge(i2c_sclk);
					i2c_sdat <= 'Z';
					-- wait one i2c-cycle
					wait until rising_edge(i2c_sclk);
					wait until falling_edge(i2c_sclk);
					i2c_sdat <= 'Z';
					-- stop condition
					wait until (rising_edge(i2c_sdat) and (i2c_sclk = '1'));
				end if;
			end if;

		end loop;
	
	end process;
	

end architecture rtl;
