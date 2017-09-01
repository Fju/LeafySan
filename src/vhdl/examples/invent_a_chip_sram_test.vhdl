----------------------------------------------------------------------
-- Project		:	Invent a Chip
-- Authors		:	Jan Dürre
-- Year  		:	2013
-- Description	:	This example fills the SRAM with some generated 
--					data (cnt(15 downto 0)). Afterwards the data is
--					read and compared to the written data. The number
--					of errors is displayed on red LEDs.
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
	type state_t is (IDLE, WRITE_TO_SRAM, READ_FROM_SRAM, DO_NOTHING, ERROR_DETECTED);
	signal state, state_nxt : state_t;
	
	-- counter register
	signal cnt, cnt_nxt 			: unsigned(CW_ADDR_SRAM-1 downto 0);
	-- error counter register
	signal error_cnt, error_cnt_nxt : unsigned(CW_ADDR_SRAM-1 downto 0);

begin

	-- sequential process
	process (clock, reset)
	begin
		-- async reset
		if reset = '1' then
			state <= IDLE;
			cnt <= (others => '0');
			error_cnt <= (others => '0');
		elsif rising_edge(clock) then
			state <= state_nxt;
			cnt <= cnt_nxt;
			error_cnt <= error_cnt_nxt;
		end if;
	end process;
	
	-- logic
	process (state, cnt, error_cnt, sram_din)
	begin
		-- standard assignments
		
		-- hold values of registers
		state_nxt 	  <= state;
		cnt_nxt 	  <= cnt;
		error_cnt_nxt <= error_cnt;
		
		-- set bus signals to standard values (not in use)
		sram_cs	  <= '0';
		sram_wr	  <= '0';
		sram_addr <= (others => '0');
		sram_dout <= (others => '0');
				
		-- turn of green leds
		led_green	<= (others => '0');
		
		-- view error count on red leds
		led_red		<= std_ulogic_vector(error_cnt(17 downto 0));
		
		-- state machine
		case state is
			-- starting state
			when IDLE =>
				-- reset counters
				cnt_nxt <= (others => '0');
				error_cnt_nxt <= (others => '0');
				-- next state
				state_nxt <= WRITE_TO_SRAM;
			
			-- fill sram with content of cnt
			when WRITE_TO_SRAM => 
				-- indicate state WRITE_TO_SRAM
				led_green(0) <= '1';
				
				-- while cnt < max value
				if cnt /= unsigned(to_signed(-1, cnt'length)) then
					-- activate chipselect
					sram_cs <= '1';
					-- write mode
					sram_wr <= '1';
					-- set address
					sram_addr <= std_ulogic_vector(cnt);
					-- set write-data to cnt-value
					sram_dout <= std_ulogic_vector(cnt(sram_dout'length-1 downto 0));
					-- inc counter
					cnt_nxt <= cnt + to_unsigned(1, cnt'length);
					
				--	cnt = max value
				else
					-- next state
					state_nxt <= READ_FROM_SRAM;
					-- reset counter
					cnt_nxt <= (others => '0');
					
				end if;
			
			-- read all data from sram
			when READ_FROM_SRAM =>
				-- indicate state READ_FROM_SRAM
				led_green(1) <= '1';
				
				-- while cnt < max value
				if cnt /= unsigned(to_signed(-1, cnt'length)) then
					-- activate chipselect
					sram_cs <= '1';
					-- read mode
					sram_wr <= '0';
					-- set address
					sram_addr <= std_ulogic_vector(cnt);
				
					-- if returned data (iobus_din) is not equal counter
					if unsigned(sram_din) /= cnt(sram_din'length-1 downto 0) then
						-- inc error counter
						error_cnt_nxt <= error_cnt + 1;
						state_nxt <= ERROR_DETECTED;
					end if;
					
					-- inc counter
					cnt_nxt <= cnt + 1;
				
				--	cnt = max value
				else
				
					-- next state
					state_nxt <= DO_NOTHING;
					
				end if;				
			
			-- wait forever
			when DO_NOTHING =>
				-- indicate state DO_NOTHING
				led_green(2) <= '1';
			
			-- wait forever on error
			when ERROR_DETECTED =>
				-- indicate state ERROR_DETECTED
				led_green(3) <= '1';
				
			
		end case;
	end process;
	
	-- default assignments for unused signals
	gp_ctrl 			<= (others => '0');
	gp_out 				<= (others => '0');
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
	lcd_cs 	 			<= '0';
	lcd_wr 	 			<= '0';
	lcd_addr 			<= (others => '0');
	lcd_dout 			<= (others => '0');
	lcd_ack_rdy			<= '0';
	uart_cs 	 		<= '0';
	uart_wr 	 		<= '0';
	uart_addr 	 		<= (others => '0');
	uart_dout 	 		<= (others => '0');
	uart_ack_rx  		<= '0';
	uart_ack_tx  		<= '0';

end rtl;