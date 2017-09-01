----------------------------------------------------------------------
-- Project		:	Invent a Chip
-- Authors		:	Jan Dürre
-- Year  		:	2013
-- Description	:	This example waits for a specific trigger word to
--					receive over UART. After the trigger-command is
--					detected some predefined datawords are send to
--					the PC.
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

	-- number of words to send after start command
	constant CV_NO_DATA			: natural := 5;

	-- state register
	type state_t is (WAIT_FOR_COMMAND, SEND_DATA);
	signal state, state_nxt : state_t;
	
	-- counter register
	signal cnt, cnt_nxt 		: unsigned(to_log2(CV_NO_DATA)-1 downto 0);
	
	-- start-command
	constant CV_START_COMMAND	: std_ulogic_vector(7 downto 0) := "00000011";
	
	-- data to be send after command
	type data_t is array (0 to CV_NO_DATA-1) of std_ulogic_vector(7 downto 0);
	constant data : data_t := ("10101010", "01010101", "11110000", "00001111", "11001100");
	
begin

	-- sequential process
	process (clock, reset)
	begin
		-- async reset
		if reset = '1' then
			state <= WAIT_FOR_COMMAND;
			cnt <= (others => '0');
		elsif rising_edge(clock) then
			state <= state_nxt;
			cnt <= cnt_nxt;
		end if;
	end process;
	
	-- logic
	process (state, cnt, uart_irq_rx, uart_irq_tx, uart_din)
	begin
		-- standard assignments
		
		-- hold values of registers
		state_nxt 	  	<= state;
		cnt_nxt 	  	<= cnt;
		
		-- set bus signals to standard values (not in use)
		uart_cs		  	<= '0';
		uart_wr		  	<= '0';
		uart_addr	  	<= (others => '0');
		uart_dout	  	<= (others => '0');
		uart_ack_rx  	<= '0';
		uart_ack_tx  	<= '0';
		
		-- turn of leds
		led_green	<= (others => '0');
		led_red 	<= (others => '0');
		
		-- state machine
		case state is
			-- wait for interrupt from UART
			when WAIT_FOR_COMMAND =>
				-- indicate state WAIT_FOR_COMMAND
				led_green(0) <= '1';
				
				-- data is ready in receive-register
				if uart_irq_rx = '1' then 
					-- select uart-interface
					uart_cs <= '1';
					-- address of send/receive-register
					uart_addr <= CV_ADDR_UART_DATA_RX;
					-- read-mode
					uart_wr	<= '0';
					
					-- check if received data is = start-command
					if uart_din(7 downto 0) = CV_START_COMMAND then
						-- next state
						state_nxt <= SEND_DATA;
						-- reset counter
						cnt_nxt <= (others => '0');
					end if;
				end if;
			
			-- send data from data-array
			when SEND_DATA =>
				-- indicate state SEND_DATA
				led_green(1) <= '1';
				
				-- check if send-register is empty
				if uart_irq_tx = '1' then
					-- select uart-interface
					uart_cs <= '1';
					-- address of send/receive-register
					uart_addr <= CV_ADDR_UART_DATA_TX;
					-- write-mode
					uart_wr	<= '1';
					-- select data from array
					uart_dout(7 downto 0) <= data(to_integer(cnt));
					
					-- IS NOT last word
					if cnt /= to_unsigned(CV_NO_DATA-1, cnt'length) then 
						-- inc counter
						cnt_nxt <= cnt + to_unsigned(1, cnt'length);
					-- IS last word
					else
						-- next state
						state_nxt <= WAIT_FOR_COMMAND;
					end if;
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
	sram_cs 	 		<= '0';
	sram_wr 	 		<= '0';
	sram_addr 	 		<= (others => '0');
	sram_dout 	 		<= (others => '0');

end rtl;