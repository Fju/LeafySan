----------------------------------------------------------------------
-- Project		:	Invent a Chip
-- Authors		:	Christian Leibold
-- Year  		:	2013
-- Description	:	With this example it is possible to generate
--					control-commands for the LCD-Display by using
--					switch 0 to 7. The command is send by pressing
--					key 0.
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
	type state_t is (S_WAIT_KEY_PRESS, S_SEND_DATA, S_WAIT_KEY_RELEASE);
	signal state, state_nxt : state_t;
	
begin

	-- sequential process
	process(clock, reset)
	begin
		-- asynchronous reset
		if reset = '1' then
			state <= S_WAIT_KEY_PRESS;
		elsif rising_edge(clock) then
			state <= state_nxt;
		end if;
	end process;

	-- combinational process contains logic only
	process(state, lcd_irq_rdy, key, switch)
	begin
		-- set default values for the internal bus -> zero on all signals means, nothing will happen
		lcd_cs    	<= '0';
		lcd_wr    	<= '0';
		lcd_dout  	<= (others => '0');
		lcd_addr  	<= (others => '0');
		lcd_ack_rdy <= '0';
		-- hold previous values of all registers
		state_nxt <= state;
	
		case state is
			-- Wait until KEY0 is triggered
			when S_WAIT_KEY_PRESS =>
				if key(0) = '1' then
					-- next state
					state_nxt <= S_SEND_DATA;
				end if;
			
			-- Read value from ADC and save it into the led_out-register
			when S_SEND_DATA =>
				if lcd_irq_rdy = '1' then
					-- Enable the Chip-Select signal for the LCD-Module
					lcd_cs <= '1';
					-- Enable the Write-Select signal
					lcd_wr <= '1';
					-- Set address of the LCD interface to print a character
					lcd_addr <= CV_ADDR_LCD_DATA;
					-- Take the new data from the first eight switches (SW0 to SW7)
					lcd_dout(7 downto 0) <= switch(7 downto 0);
					-- next state
					state_nxt <= S_WAIT_KEY_RELEASE;
				end if;
				
			-- Wait until KEY0 is released
			when S_WAIT_KEY_RELEASE =>
				if key(0) = '0' then
					-- next state
					state_nxt <= S_WAIT_KEY_PRESS;
				end if;
			
		end case;
	end process;
	
	-- default assignments for unused signals
	gp_ctrl 			<= (others => '0');
	gp_out				<= (others => '0');
	led_green 			<= (others => '0');
	led_red 			<= (others => '0');
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