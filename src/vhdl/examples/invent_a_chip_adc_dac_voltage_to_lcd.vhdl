----------------------------------------------------------------------
-- Project		:	Invent a Chip
-- Authors		:	Christian Leibold
-- Year  		:	2013
-- Description	:	The code in this file reads the measured voltage
--					from the ADC-Channel selected by the first three
--					switches and prints it on the LCD.
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

	-- state register
	type state_t is (S_INIT, S_WAIT_TIME, S_ADC_READ, S_PRINT_CHARACTERS);
	signal state, state_nxt : state_t;
	
	-- Define a constant array with the hex-codes of every single character to print them on the LC-Display
	signal lcd_cmds, lcd_cmds_nxt : lcd_commands_t(0 to 12); -- 06
	
	-- register to save a value from the ADC and show it on the first twelve red LEDs
	signal adc_value, adc_value_nxt : std_ulogic_vector(11 downto 0);
	
	signal char_count, char_count_nxt : unsigned(to_log2(lcd_cmds'length)-1 downto 0);
	signal count     , count_nxt 	  : unsigned(31 downto 0);

begin

	-- sequential process
	process(clock, reset)
	begin
		-- asynchronous reset
		if reset = '1' then
			adc_value  <= (others => '0');
			char_count <= (others => '0');
			lcd_cmds   <= (others => (others => '0'));
			count	   <= (others => '0');
			state      <= S_INIT;
		elsif rising_edge(clock) then
			adc_value  <= adc_value_nxt;
			char_count <= char_count_nxt;
			lcd_cmds   <= lcd_cmds_nxt;
			count	   <= count_nxt;
			state      <= state_nxt;
		end if;
	end process;

	-- combinational process contains logic only
	process(state, key, adc_dac_din, lcd_din, lcd_irq_rdy, switch, char_count, lcd_cmds, adc_value, count)
		variable bcd_value  : unsigned(15 downto 0) := (others => '0');
		variable adc_recalc : std_ulogic_vector(11 downto 0) := (others => '0');
	begin
		-- default assignments
		
		-- set default values for the internal bus -> zero on all signals means, nothing will happen
		adc_dac_cs       <= '0';
		adc_dac_wr       <= '0';
		adc_dac_addr     <= (others => '0');
		adc_dac_dout     <= (others => '0');
		
		lcd_cs       	<= '0';
		lcd_wr       	<= '0';
		lcd_addr     	<= (others => '0');
		lcd_dout     	<= (others => '0');
		lcd_ack_rdy 	<= '0';
		-- hold previous values of all registers
		adc_value_nxt  <= adc_value;
		char_count_nxt <= char_count;
		lcd_cmds_nxt   <= lcd_cmds;
		state_nxt      <= state;
		count_nxt	   <= count;
	
		case state is
			-- Initial start state
			when S_INIT =>
				-- Wait for a press on KEY0 to start the function 
				if key(0) = '1' then
					-- activate ADC channels
					adc_dac_cs		<= '1';
					adc_dac_wr		<= '1';
					adc_dac_addr	<= CV_ADDR_ADC_DAC_CTRL;
					adc_dac_dout(9 downto 0) <= "0011111111";
					-- next state
					state_nxt <= S_WAIT_TIME;
				end if;
			
			when S_WAIT_TIME =>
				count_nxt <= count + 1;
				if count = 5000000 then
					count_nxt <= (others => '0');
					state_nxt <= S_ADC_READ;
				end if;
			
			-- Read value from ADC and save it into the led_out-register
			when S_ADC_READ =>
				-- Enable the Chip-Select signal for the ADC/DAC-Module
				adc_dac_cs <= '1';
				-- Set read-address for the value of the selected ADC-Channel
				adc_dac_addr(2 downto 0)	  <= switch(2 downto 0);
				-- Set the value of the selected ADC-Channel as next value for the led_out-register
				adc_value_nxt 				  <= adc_dac_din(11 downto 0);
				
				adc_recalc := std_ulogic_vector(resize(shift_right( unsigned(adc_dac_din(11 downto 0)) * 3300 ,12), adc_recalc'length));
				bcd_value := unsigned(to_bcd(adc_recalc, 4));
				
				lcd_cmds_nxt				  <= lcd_cmd(lcd_cursor_pos(0, 0) & asciitext("ADC") & ascii(unsigned('0' & switch(2 downto 0))) & asciitext(": ") & ascii(bcd_value(15 downto 12)) & ascii('.') & ascii(bcd_value(11 downto 8)) & ascii(bcd_value(7 downto 4)) & ascii(bcd_value(3 downto 0)) & ascii('V'));
				char_count_nxt				  <= (others => '0');
				-- next state
				state_nxt 					  <= S_PRINT_CHARACTERS;
			
			-- Set a constant a value to a DAC-Channel in this state
			when S_PRINT_CHARACTERS =>
				if lcd_irq_rdy = '1' then
					-- Enable the Chip-Select signal for the LCD-Module
					lcd_cs		<= '1';
					-- Set the write to one to write a value into a register
					lcd_wr  	<= '1';
					-- Set address of the LCD interface to print a character
					lcd_addr	<= CV_ADDR_LCD_DATA;
					
					-- Set the value which should be written into the selected register the in the selected module
					lcd_dout(7 downto 0) <= lcd_cmds(to_integer(char_count));
					
					if char_count = lcd_cmds'length-1 then 
						-- next state
						state_nxt <= S_WAIT_TIME;
					else 
						char_count_nxt <= char_count + 1;
					end if;
				end if;
			
		end case;
	end process;
	
	-- Default assignment for the 8th green LED 
	led_green(8) <= '0';

	led_green_gen : for i in 0 to 7 generate
		led_green(i) <= '1' when unsigned(adc_value) >= (i+1)*(4096/26) else '0';
	end generate led_green_gen;
	
	led_red_gen : for i in 0 to 17 generate
		led_red(i) <= '1' when unsigned(adc_value) >= ((i+1)*(4096/26))+8*(4096/26) else '0';
	end generate led_red_gen;
	
	
	-- default assignments for unused signals
	gp_ctrl 			<= (others => '0');
	gp_out 	  			<= (others => '0');
	sevenseg_cs 		<= '0';
	sevenseg_wr 		<= '0';
	sevenseg_addr 		<= (others => '0');
	sevenseg_dout 		<= (others => '0');
	audio_cs 	 		<= '0';
	audio_wr 	 		<= '0';
	audio_addr 	 		<= (others => '0');
	audio_dout 	 		<= (others => '0');
	audio_ack_left  	<= '0';
	audio_ack_right 	<= '0';
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