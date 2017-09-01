-----------------------------------------------------------------------
-- Project		:	Invent a Chip
-- Authors		:	Christian Leibold
-- Year  		:	2013
-- Description	:	This is an really awesome example. The module waits
--					until an audio sample on the left or right channel
--					has been sampled. The current sample will be taken
--					and copied into the corresponding out register of 
--					the audio interface.
-----------------------------------------------------------------------

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
	type state_t is (S_INIT, S_WAIT_SAMPLE, S_WRITE_SAMPLE_LEFT, S_WRITE_SAMPLE_RIGHT);
	signal state, state_nxt : state_t;
	
	signal sample, sample_nxt : std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	
begin

	-- sequential process
	process(clock, reset)
	begin
		-- asynchronous reset
		if reset = '1' then
			sample <= (others => '0');
			state  <= S_INIT;
		elsif rising_edge(clock) then
			sample <= sample_nxt;
			state  <= state_nxt;
		end if;
	end process;

	-- combinational process contains logic only
	process(state, key, audio_din, audio_irq_left, audio_irq_right, sample)
	begin
		-- default assignments
		
		-- set default values for the internal bus -> zero on all signals means, nothing will happen
		audio_cs   		<= '0';
		audio_wr   		<= '0';
		audio_addr 		<= (others => '0');
		audio_dout 		<= (others => '0');
		audio_ack_left  <= '0';
		audio_ack_right <= '0';
		led_green  		<= (others => '0');
		-- hold previous values of all registers
		sample_nxt <= sample;
		state_nxt  <= state;
	
		case state is
			-- Initial start state
			when S_INIT =>
				led_green(0) <= '1';
				-- Wait for a press on KEY0 to start the function 
				if key(0) = '1' then
					-- next state
					state_nxt <= S_WAIT_SAMPLE;
				end if;
			
			when S_WAIT_SAMPLE =>
				led_green(1) <= '1';
				if audio_irq_right = '1' then
					audio_cs		<= '1';
					audio_ack_right <= '1';
					audio_addr 		<= CV_ADDR_AUDIO_RIGHT_IN;
					sample_nxt 		<= audio_din;
					state_nxt  		<= S_WRITE_SAMPLE_RIGHT;
				end if;
				
				if audio_irq_left = '1' then
					audio_cs 	   <= '1';
					audio_ack_left <= '1';
					audio_addr 	   <= CV_ADDR_AUDIO_LEFT_IN;
					sample_nxt 	   <= audio_din;
					state_nxt  	   <= S_WRITE_SAMPLE_LEFT;
				end if;
						
			when S_WRITE_SAMPLE_LEFT =>
				led_green(4) <= '1';
				audio_cs     <= '1';
				audio_wr   	 <= '1';
				audio_addr 	 <= CV_ADDR_AUDIO_LEFT_OUT;
				audio_dout 	 <= sample;
				state_nxt  	 <= S_WAIT_SAMPLE;
						
			when S_WRITE_SAMPLE_RIGHT =>
				led_green(5) <= '1';
				audio_cs	 <= '1';
				audio_wr   	 <= '1';
				audio_addr 	 <= CV_ADDR_AUDIO_RIGHT_OUT;
				audio_dout 	 <= sample;
				state_nxt  	 <= S_WAIT_SAMPLE;
				
		end case;
	end process;
	
	-- Default assignment for the general-purpose-outs (not used in the example)
	gp_ctrl 			<= (others => '0');
	gp_out 	  			<= (others => '0');
	led_red   			<= (others => '0');
	sevenseg_cs 		<= '0';
	sevenseg_wr 		<= '0';
	sevenseg_addr 		<= (others => '0');
	sevenseg_dout 		<= (others => '0');
	adc_dac_cs 	 		<= '0';
	adc_dac_wr 	 		<= '0';
	adc_dac_addr 		<= (others => '0');
	adc_dac_dout 		<= (others => '0');
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