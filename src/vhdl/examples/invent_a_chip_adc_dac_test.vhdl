----------------------------------------------------------------------
-- Project		:	Invent a Chip
-- Authors		:	Christian Leibold
-- Year  		:	2013
-- Description	:	This example reads the adc-value from channel 2
--					and displays the result on red LEDs 0 to 11.
--					Afterwards the binary value set by switches
--					0 to 7 is send to DAC channel 1.
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
	type state_t is (S_INIT, S_ADC_READ, S_DAC_SET, S_WAIT);
	signal state, state_nxt : state_t;
	
	-- register to save a value from the ADC and show it on the first twelve red LEDs
	signal led_out, led_out_nxt : std_ulogic_vector(11 downto 0);
	-- register for a wait counter (counts from 0 to 1000)
	signal count  , count_nxt   : unsigned(9 downto 0);

begin

	-- sequential process
	process(clock, reset)
	begin
		-- asynchronous reset
		if reset = '1' then
			led_out <= (others => '0');
			count   <= (others => '0');
			state   <= S_INIT;
		elsif rising_edge(clock) then
			led_out <= led_out_nxt;
			count   <= count_nxt;
			state   <= state_nxt;
		end if;
	end process;

	-- combinational process contains logic only
	process(state, key, count, led_out, adc_dac_din, switch)
	begin
		-- default assignments
		
		-- set default values for the internal bus -> zero on all signals means, nothing will happen
		adc_dac_cs    <= '0';
		adc_dac_wr    <= '0';
		adc_dac_addr  <= (others => '0');
		adc_dac_dout  <= (others => '0');
		
		-- hold previous values of all registers
		led_out_nxt <= led_out;
		count_nxt	<= count;
		state_nxt   <= state;
	
		case state is
			-- Initial start state
			when S_INIT =>
				-- Wait for a press on KEY0 to start the function 
				if key(0) = '1' then
					-- activate ADC channel 2 and DAC channel 1
					adc_dac_cs		<= '1';
					adc_dac_wr		<= '1';
					adc_dac_addr	<= CV_ADDR_ADC_DAC_CTRL;
					adc_dac_dout(9 downto 0) <= "1000000100";
					-- next state
					state_nxt <= S_ADC_READ;
				end if;
			
			-- Read value from ADC and save it into the led_out-register
			when S_ADC_READ =>
				-- Enable the Chip-Select signal for the ADC/DAC-Module
				adc_dac_cs <= '1';
				-- Set read-address for the value of ADC-Channel 2
				adc_dac_addr		  		  <= CV_ADDR_ADC2;
				-- Set the value of the selected ADC-Channel as next value for the led_out-register
				led_out_nxt 				  <= adc_dac_din(11 downto 0);
				-- next state
				state_nxt 					  <= S_DAC_SET;
				
			-- Set a constant a value to a DAC-Channel in this state
			when S_DAC_SET =>
				-- Set the write to one to write a value into a register
				adc_dac_wr    				  <= '1';
				-- Enable the Chip-Select signal for the ADC/DAC-Module
				adc_dac_cs					  <= '1';
				-- Set read-address for the value of DAC-Channel 1
				adc_dac_addr				  <= CV_ADDR_DAC1;
				-- Set the value which should be written into the selected register the in the selected module
				adc_dac_dout(7 downto 0)	  <= switch(7 downto 0);
				-- next state
				state_nxt 					  <= S_WAIT;
			
			when S_WAIT =>
				-- increment counter by 1 every clock cycle
				count_nxt <= count + to_unsigned(1, count'length);
				-- compare actual counter value with immediate 1000s
				if count = to_unsigned(1000, count'length) then
					-- reset the counter to zero
					count_nxt <= (others => '0');
					-- next state
					state_nxt <= S_ADC_READ;
				end if;
			
		end case;
	end process;
	
	-- Default assignment for all unused red LEDs
	led_red(17 downto 12) <= (others => '0');
	-- Connect the output of the led_out-register to the first twelve red LEDs directly
	-- If the value of the led_out-register, the LEDs will change immediately at the same time
	led_red(11 downto  0) <= led_out;
	
	-- default assignments for unused signals
	gp_ctrl 			<= (others => '0');
	gp_out 	  			<= (others => '0');
	led_green 			<= (others => '0');
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
	lcd_cs 	 	 		<= '0';
	lcd_wr 	 	 		<= '0';
	lcd_addr 	 		<= (others => '0');
	lcd_dout 	 		<= (others => '0');
	lcd_ack_rdy			<= '0';
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