----------------------------------------------------------------------
-- Project		:	Invent a Chip
-- Authors		:	Christian Leibold
-- Year  		:	2013
-- Description	:	This example sends a predefined text to the LCD
--					display.
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
	type state_t is (S_WAIT_KEY, S_PRINT_TO_LCD, S_FINISH);
	signal state, state_nxt : state_t;
	
	-- Define a constant array with the hex-codes of every single character to print them on the LC-Display
	constant lcd_commands : lcd_commands_t(0 to 24) := lcd_cmd( asciitext(" Invent A Chip! ") & lcd_cursor_pos(1,4) & asciitext("IMS 2015") );
	
	-- Define a counter to count the printed characters
	signal count, count_nxt : unsigned(4 downto 0);
		
begin	

	-- Sequential process
	process(clock, reset)
	begin
		-- asynchronous reset
		if reset = '1' then
			count <= (others => '0');
			state <= S_WAIT_KEY;
		elsif rising_edge(clock) then
			count <= count_nxt;
			state <= state_nxt;
		end if;
	end process;

	-- Combinational process contains logic only
	process(state, lcd_irq_rdy, key, count)
	begin
		-- Default assignment for the green LEDs (not used in this example)
		led_green <= (others => '0');
		-- Default assignment for all red LEDs (not used in this example)
		led_red <= (others => '0');
		
		-- Set default values for the internal bus -> zero on all signals means, nothing will happen
		lcd_cs 	 	<= '0';
		lcd_wr 	 	<= '0';
		lcd_addr 	<= (others => '0');
		lcd_dout 	<= (others => '0');
		lcd_ack_rdy <= '0';
		-- Hold previous values of all registers
		count_nxt  <= count;
		state_nxt  <= state;
	
		case state is
			-- Wait until KEY0 is triggered
			when S_WAIT_KEY =>
				led_green(0) <= '1';
				if key(0) = '1' then
					state_nxt <= S_PRINT_TO_LCD;
				end if;
			
			-- Read value from ADC and save it into the led_out-register
			when S_PRINT_TO_LCD =>
				led_green(1) <= '1';
				if lcd_irq_rdy = '1' then
					-- Enable the Chip-Select signal for the LCD-Module
					lcd_cs <= '1';
					-- Enable the Write-Select signal
					lcd_wr <= '1';
					-- Take the new data from character array, the position is given by the character counter
					lcd_dout(7 downto 0) <= lcd_commands(to_integer(count));
					-- Set address of the LCD interface to print a character
					lcd_addr <= CV_ADDR_LCD_DATA;
					-- Increment the counter to count the printed characters
					count_nxt <= count + to_unsigned(1, count'length);
					-- The next state depends on the counter or on how many characters got already printed
					if count = to_unsigned(lcd_commands'length-1, count'length) then
						state_nxt <= S_FINISH;
					end if;
				end if;
				
			-- Endless loop -> never leave this state
			when S_FINISH =>
				led_green(2) <= '1';
			
		end case;
	end process;
	
	-- default assignments for unused signals
	gp_ctrl 			<= (others => '0');
	gp_out 	  			<= (others => '0');
	sevenseg_cs 		<= '0';
	sevenseg_wr 		<= '0';
	sevenseg_addr 		<= (others => '0');
	sevenseg_dout 		<= (others => '0');
	adc_dac_cs 	 		<= '0';
	adc_dac_wr 	 		<= '0';
	adc_dac_addr 		<= (others => '0');
	adc_dac_dout 		<= (others => '0');
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