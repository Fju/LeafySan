----------------------------------------------------------------------
-- Project		:	Invent a Chip
-- Authors		:	Jan D�rre
-- Year  		:	2013
-- Description	:	This example uses adc-channel 0 as gain-control
--					for audio pass-through. Two independent FSMs are
--					required, since the lcd is too slow for 44,1kHz
--					sampling rate.
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity invent_a_chip is
	port (
		-- Global Signals
		clock				: in  std_ulogic;
		reset				: in  std_ulogic;
		-- Interface Signals
		-- 7-Seg
		sevenseg_cs   		: out std_ulogic;
		sevenseg_wr   		: out std_ulogic;
		sevenseg_addr 		: out std_ulogic_vector(CW_ADDR_SEVENSEG-1 downto 0);
		sevenseg_din  		: in  std_ulogic_vector(CW_DATA_SEVENSEG-1 downto 0);
		sevenseg_dout 		: out std_ulogic_vector(CW_DATA_SEVENSEG-1 downto 0);
		-- ADC/DAC
		adc_dac_cs 	 		: out std_ulogic;
		adc_dac_wr 	 		: out std_ulogic;
		adc_dac_addr 		: out std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0);
		adc_dac_din  		: in  std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
		adc_dac_dout 		: out std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
		-- AUDIO
		audio_cs   			: out std_ulogic;
		audio_wr   			: out std_ulogic;
		audio_addr 			: out std_ulogic_vector(CW_ADDR_AUDIO-1 downto 0);
		audio_din  			: in  std_ulogic_vector(CW_DATA_AUDIO-1 downto 0);
		audio_dout 			: out std_ulogic_vector(CW_DATA_AUDIO-1 downto 0);
		audio_irq_left  	: in  std_ulogic;
		audio_irq_right 	: in  std_ulogic;
		audio_ack_left  	: out std_ulogic;
		audio_ack_right 	: out std_ulogic;
		-- Infra-red Receiver
		ir_cs				: out std_ulogic;
		ir_wr				: out std_ulogic;
		ir_addr				: out std_ulogic_vector(CW_ADDR_IR-1 downto 0);
		ir_din				: in  std_ulogic_vector(CW_DATA_IR-1 downto 0);
		ir_dout				: out std_ulogic_vector(CW_DATA_IR-1 downto 0);
		ir_irq_rx			: in  std_ulogic;
		ir_ack_rx			: out std_ulogic;
		-- LCD
		lcd_cs   			: out std_ulogic;
		lcd_wr   			: out std_ulogic;
		lcd_addr 			: out std_ulogic_vector(CW_ADDR_LCD-1 downto 0);
		lcd_din  			: in  std_ulogic_vector(CW_DATA_LCD-1 downto 0);
		lcd_dout 			: out std_ulogic_vector(CW_DATA_LCD-1 downto 0);
		lcd_irq_rdy			: in  std_ulogic;
		lcd_ack_rdy			: out std_ulogic;
		-- SRAM
		sram_cs   			: out std_ulogic;
		sram_wr   			: out std_ulogic;
		sram_addr 			: out std_ulogic_vector(CW_ADDR_SRAM-1 downto 0);
		sram_din  			: in  std_ulogic_vector(CW_DATA_SRAM-1 downto 0);
		sram_dout 			: out std_ulogic_vector(CW_DATA_SRAM-1 downto 0);
		-- UART
		uart_cs   	  		: out std_ulogic;
		uart_wr   	  		: out std_ulogic;
		uart_addr 	  		: out std_ulogic_vector(CW_ADDR_UART-1 downto 0);
		uart_din  	  		: in  std_ulogic_vector(CW_DATA_UART-1 downto 0);
		uart_dout 	  		: out std_ulogic_vector(CW_DATA_UART-1 downto 0);
		uart_irq_rx  		: in  std_ulogic;
		uart_irq_tx  		: in  std_ulogic;
		uart_ack_rx  		: out std_ulogic;
		uart_ack_tx  		: out std_ulogic;
		-- GPIO
		gp_ctrl 			: out std_ulogic_vector(15 downto 0);
		gp_in 				: in  std_ulogic_vector(15 downto 0);
		gp_out				: out std_ulogic_vector(15 downto 0);
		-- LED/Switches/Keys
		led_green			: out std_ulogic_vector(8  downto 0);
		led_red				: out std_ulogic_vector(17 downto 0);
		switch				: in  std_ulogic_vector(17 downto 0);
		key 				: in  std_ulogic_vector(2  downto 0)
	);
end invent_a_chip;

architecture rtl of invent_a_chip is

	-- state register for audio control
	type state_audio_t is (S_INIT, S_WAIT_SAMPLE, S_ADC_READ, S_WRITE_SAMPLE_LEFT, S_WRITE_SAMPLE_RIGHT, S_WRITE_CONFIG);
	signal state_audio, state_audio_nxt : state_audio_t;
	
	-- state register for lcd control
	type state_lcd_t is (S_WAIT_LCD, S_PRINT_CHARACTERS, S_WAIT_FOR_NEW_GAIN);
	signal state_lcd, state_lcd_nxt : state_lcd_t;
	
	-- register to save audio-sample
	signal sample, sample_nxt : std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	
	-- register to save adc-value 
	signal adc_value, adc_value_nxt : std_ulogic_vector(11 downto 0);
	
	-- signals to communicate between fsms
	signal lcd_refresh, lcd_refresh_nxt : std_ulogic;
	signal lcd_refresh_ack : std_ulogic;
	
	-- array of every single character to print out to the lcd
	signal lcd_cmds, lcd_cmds_nxt : lcd_commands_t(0 to 12);
	
	-- counter
	signal char_count, char_count_nxt : unsigned(to_log2(lcd_cmds'length)-1 downto 0);
	
begin

	-- sequential process
	process(clock, reset)
	begin
		-- asynchronous reset
		if reset = '1' then
			state_audio	<= S_INIT;
			sample 		<= (others => '0');
			adc_value 	<= (others => '0');
			lcd_refresh <= '0';
			state_lcd	<= S_WAIT_LCD;
			lcd_cmds 	<= lcd_cmd(lcd_cursor_pos(0, 0) & asciitext("Volume: XXX%"));
			char_count	<= (others => '0');
		elsif rising_edge(clock) then
			state_audio	<= state_audio_nxt;
			sample 		<= sample_nxt;
			adc_value 	<= adc_value_nxt;
			lcd_refresh <= lcd_refresh_nxt;
			state_lcd 	<= state_lcd_nxt;
			lcd_cmds 	<= lcd_cmds_nxt;
			char_count	<= char_count_nxt;
		end if;
	end process;

	-- audio data-path (combinational process contains logic only)
	process(state_audio, state_lcd, key, adc_dac_din, audio_din, audio_irq_left, audio_irq_right, lcd_refresh, lcd_refresh_ack, sample, adc_value, switch)
	begin
		-- default assignment
		-- leds
		led_green		<= (others => '0');
		-- adc/dac interface
		adc_dac_cs		<= '0';
		adc_dac_wr		<= '0';
		adc_dac_addr	<= (others => '0');
		adc_dac_dout	<= (others => '0');
		-- audio interface
		audio_cs 	 	<= '0';
		audio_wr 	 	<= '0';
		audio_addr 	 	<= (others => '0');
		audio_dout 	 	<= (others => '0');
		audio_ack_left  <= '0';
		audio_ack_right <= '0';
		-- communication between fsms
		lcd_refresh_nxt <= lcd_refresh;
		-- hold previous values of all registers
		state_audio_nxt <= state_audio;
		sample_nxt 		<= sample;
		adc_value_nxt 	<= adc_value;
		
		-- reset lcd_refresh if lcd-fsm acks request
		if lcd_refresh_ack = '1' then
			lcd_refresh_nxt <= '0';
		end if;
	
		-- audio data-path
		case state_audio is
			-- initial state
			when S_INIT =>
				led_green(0) <= '1';
				-- wait for key 0 to start work
				if key(0) = '1' then
					-- activate ADC channel 0
					adc_dac_cs		<= '1';
					adc_dac_wr		<= '1';
					adc_dac_addr	<= CV_ADDR_ADC_DAC_CTRL;
					adc_dac_dout(9 downto 0) <= "0000000001";
					-- next state
					state_audio_nxt <= S_WAIT_SAMPLE;
				end if;
			
			-- wait for audio-interrupt signals to indicate new audio-sample
			when S_WAIT_SAMPLE =>
				led_green(1) <= '1';
				-- new audio sample on left or right channel detected
				if (audio_irq_left = '1') or (audio_irq_right = '1') then
					-- start reading adc-value
					state_audio_nxt <= S_ADC_READ;
				end if;
			
			-- read adc value 
			when S_ADC_READ =>
				led_green(2) <= '1';
				-- chip select for adc/dac-interface
				adc_dac_cs <= '1';
				-- read mode
				adc_dac_wr <= '0';
				-- address of adc-channel 0
				adc_dac_addr <= CV_ADDR_ADC0;
				-- if adc-value has changed:
				if adc_dac_din(11 downto 0) /= adc_value then
					-- save adc-value of selected channel to register
					adc_value_nxt <= adc_dac_din(11 downto 0);
					-- initiate rewrite of lcd display
					lcd_refresh_nxt <= '1';
				end if;

				-- choose correct audio channel 
				if audio_irq_left = '1' then
					-- chip select for audio-interface
					audio_cs <= '1';
					-- read mode
					audio_wr <= '0';
					-- acknowledge interrupt
					audio_ack_left <= '1';
					-- set address for left channel 
					audio_addr <= CV_ADDR_AUDIO_LEFT_IN;
					-- save sample to register
					sample_nxt <= audio_din;
					-- next state
					state_audio_nxt <= S_WRITE_SAMPLE_LEFT;
				end if;
				
				if audio_irq_right = '1' then
					-- chip select for audio-interface
					audio_cs <= '1';
					-- read mode
					audio_wr <= '0';
					-- acknowledge interrupt
					audio_ack_right <= '1';
					-- set address for right channel 
					audio_addr <= CV_ADDR_AUDIO_RIGHT_IN;
					-- save sample to register
					sample_nxt <= audio_din;
					-- next state
					state_audio_nxt <= S_WRITE_SAMPLE_RIGHT;
				end if;
			
			-- write new sample to left channel
			when S_WRITE_SAMPLE_LEFT =>
				led_green(5) <= '1';
				-- chip select for audio-interface
				audio_cs <= '1';
				-- write mode
				audio_wr <= '1';
				-- set address for left channel
				audio_addr <= CV_ADDR_AUDIO_LEFT_OUT;
				-- write sample * gain-factor to audio-interface
				audio_dout <= std_ulogic_vector(resize(shift_right(signed(sample) * signed('0' & adc_value(11 downto 4)), 7), audio_dout'length));
				-- write config to acodec
				state_audio_nxt <= S_WRITE_CONFIG;
			
			-- write new sample to right channel
			when S_WRITE_SAMPLE_RIGHT =>
				led_green(6) <= '1';
				-- chip select for audio-interface
				audio_cs <= '1';
				-- write mode
				audio_wr <= '1';
				-- set address for right channel
				audio_addr <= CV_ADDR_AUDIO_RIGHT_OUT;
				-- write sample * gain-factor to audio-interface
				audio_dout <= std_ulogic_vector(resize(shift_right(signed(sample) * signed('0' & adc_value(11 downto 4)), 7), audio_dout'length));
				-- write config to acodec
				state_audio_nxt <= S_WRITE_CONFIG;
				
			when S_WRITE_CONFIG =>
				led_green(7) <= '1';
				-- chip select for audio-interface
				audio_cs <= '1';
				-- write mode
				audio_wr <= '1';
				-- set address for config register
				audio_addr <= CV_ADDR_AUDIO_CONFIG;
				-- set mic boost & in-select
				audio_dout <= "00000000000000" & switch(1) & switch(0);
				-- back to wait-state
				state_audio_nxt <= S_WAIT_SAMPLE;

		end case;
	
	end process;
	
	
	-- lcd control (combinational process contains logic only)
	process(state_lcd, lcd_cmds, char_count, lcd_din, lcd_irq_rdy, lcd_refresh, adc_value)
		variable bcd_value  : unsigned(11 downto 0) := (others => '0');
		variable adc_recalc : std_ulogic_vector(11 downto 0) := (others => '0');
	begin
		-- default assignment
		-- leds
		led_red			<= (others => '0');
		-- lcd interface
		lcd_cs       	<= '0';
		lcd_wr       	<= '0';
		lcd_addr     	<= (others => '0');
		lcd_dout     	<= (others => '0');
		lcd_ack_rdy 	<= '0';
		-- communication between FSMs
		lcd_refresh_ack <= '0';		
		--registers
		state_lcd_nxt 	<= state_lcd;
		lcd_cmds_nxt 	<= lcd_cmds;
		char_count_nxt	<= char_count;
	
		-- second state machine to generate output on lcd-screen
		case state_lcd is
			-- wait for lcd-interface to be 'not busy' / finished writing old commands to lcd
			when S_WAIT_LCD =>
				led_red(0) <= '1';
				-- chip select for lcd-interface
				lcd_cs <= '1';
				-- read mode
				lcd_wr <= '0';
				-- set address for status
				lcd_addr <= CV_ADDR_LCD_STATUS;
				-- start printing characters
				if lcd_din(0) = '0' then
					state_lcd_nxt <= S_PRINT_CHARACTERS;
				end if;
				
			-- send characters to lcd-interface
			when S_PRINT_CHARACTERS =>
				led_red(1) <= '1';
				-- lcd ready for data
				if lcd_irq_rdy = '1' then
					-- chip select for lcd-interface
					lcd_cs <= '1';
					-- write mode
					lcd_wr <= '1';
					-- set address for data register of lcd
					lcd_addr <= CV_ADDR_LCD_DATA;
					-- select character from lcd-commands-array
					lcd_dout(7 downto 0) <= lcd_cmds(to_integer(char_count));
					
					-- decide if every character has been sent
					if char_count = lcd_cmds'length-1 then 
						state_lcd_nxt <= S_WAIT_FOR_NEW_GAIN;
					-- continue sending characters to lcd-interface
					else
						char_count_nxt <= char_count + 1;
					end if;
				end if;
				
			when S_WAIT_FOR_NEW_GAIN =>
				led_red(2) <= '1';
				-- write new value, only when adc value has changed
				if lcd_refresh = '1'  then 
					-- ack refresh request
					lcd_refresh_ack <= '1';
					-- calculate gain-value
					adc_recalc := std_ulogic_vector(resize(shift_right( unsigned(adc_value(11 downto 4)) * 200,8), adc_recalc'length));
					bcd_value := unsigned(to_bcd(adc_recalc, 3));
					-- generate lcd-commands
					lcd_cmds_nxt <= lcd_cmd(lcd_cursor_pos(0, 0) & asciitext("Volume: ") & ascii(bcd_value(11 downto 8)) & ascii(bcd_value(7 downto 4)) & ascii(bcd_value(3 downto 0)) & asciitext("%"));
					-- reset char counter
					char_count_nxt <= (others => '0');
					-- start writing to lcd
					state_lcd_nxt <= S_WAIT_LCD;
				end if;
				
		end case;
	end process;


	-- default assignments for unused signals
	gp_ctrl 			<= (others => '0');
	gp_out 				<= (others => '0');
	sevenseg_cs 		<= '0';
	sevenseg_wr 		<= '0';
	sevenseg_addr 		<= (others => '0');
	sevenseg_dout 		<= (others => '0');
	ir_cs				<= '0';
	ir_wr				<= '0';
	ir_addr				<= (others => '0');
	ir_dout				<= (others => '0');
	ir_ack_rx			<= '0';
	sram_cs 	 		<= '0';
	sram_wr 	 		<= '0';
	sram_addr 	 		<= (others => '0');
	sram_dout 	 		<= (others => '0');
	uart_cs 	 		<= '0';
	uart_wr 	 		<= '0';
	uart_addr 	 		<= (others => '0');
	uart_dout 	 		<= (others => '0');
	uart_ack_rx  		<= '0';
	uart_ack_tx  		<= '0';
	
end rtl;