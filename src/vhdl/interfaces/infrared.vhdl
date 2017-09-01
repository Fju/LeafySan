-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : Infra-red Receiver for NEC TX Format
-- Author 		: Jan Dürre
-- Last update  : 12.08.2014
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity infrared is
	generic (
		SIMULATION 		: boolean := false
	);
	port (
		-- global
		clock 			: in    std_ulogic;
		reset_n  		: in    std_ulogic;
		-- bus interface
		iobus_cs		: in  	std_ulogic;
		iobus_wr		: in  	std_ulogic;
		iobus_addr		: in  	std_ulogic_vector(CW_ADDR_IR-1 downto 0);
		iobus_din		: in  	std_ulogic_vector(CW_DATA_IR-1 downto 0);
		iobus_dout		: out 	std_ulogic_vector(CW_DATA_IR-1 downto 0);
		-- IRQ handling
		iobus_irq_rx	: out 	std_ulogic;
		iobus_ack_rx	: in  	std_ulogic;
		-- connection to ir-receiver
		irda_rxd 		: in	std_ulogic
    );
end infrared;

architecture rtl of infrared is

	constant C_IR_CUSTOM_CODE : std_ulogic_vector(15 downto 0) := x"6B86";

	--------------------------------------------
	-- NEC Transmission Format: Remote Output --
	--------------------------------------------
	-- Start Sequence -> 16 Bit Custom Code -> 8 Bit Data -> 8 Bit NOT(Data)
	--
	-- Timinig:
	-- Start Sequence: 9 ms HIGH -> 4.5 ms LOW
	-- 0-Bit: 0.6 ms HIGH -> 0.52 ms LOW
	-- 1-Bit: 0.6 ms HIGH -> 1.66 ms LOW
	--
	-- ATTENTION: Since the receiver inverts the incoming signal (irda_rxd is inverted to the remote output signal) the timings for LOW and HIGH parts are swapped in the following!

	
	-- factor for min / max values of time measurement
	constant TOLERANCE_FACTOR 		: real 	:= 0.5;
	
	-- startbit LOW time: 9.0 ms
	constant CV_STARTBIT_LOW_SYN		: natural := (CV_SYS_CLOCK_RATE / 1000000) * 9000;
	constant CV_STARTBIT_LOW_MIN_SYN 	: natural := (CV_STARTBIT_LOW_SYN - natural(real(CV_STARTBIT_LOW_SYN) * TOLERANCE_FACTOR));
	constant CV_STARTBIT_LOW_MAX_SYN 	: natural := (CV_STARTBIT_LOW_SYN + natural(real(CV_STARTBIT_LOW_SYN) * TOLERANCE_FACTOR));
	
	constant CV_STARTBIT_LOW_SIM		: natural := 90;
	constant CV_STARTBIT_LOW_MIN_SIM 	: natural := (CV_STARTBIT_LOW_SIM - natural(real(CV_STARTBIT_LOW_SIM) * TOLERANCE_FACTOR));
	constant CV_STARTBIT_LOW_MAX_SIM 	: natural := (CV_STARTBIT_LOW_SIM + natural(real(CV_STARTBIT_LOW_SIM) * TOLERANCE_FACTOR));
	
	signal 	 CV_STARTBIT_LOW_MIN 		: natural;
	signal 	 CV_STARTBIT_LOW_MAX 		: natural;
	
	-- startbit HIGH time: 4.5 ms
	constant CV_STARTBIT_HIGH_SYN 		: natural := (CV_SYS_CLOCK_RATE / 1000000) * 4500;
	constant CV_STARTBIT_HIGH_MIN_SYN 	: natural := (CV_STARTBIT_HIGH_SYN - natural(real(CV_STARTBIT_HIGH_SYN) * TOLERANCE_FACTOR));
	constant CV_STARTBIT_HIGH_MAX_SYN 	: natural := (CV_STARTBIT_HIGH_SYN + natural(real(CV_STARTBIT_HIGH_SYN) * TOLERANCE_FACTOR));
	
	constant CV_STARTBIT_HIGH_SIM 		: natural := 45;
	constant CV_STARTBIT_HIGH_MIN_SIM 	: natural := (CV_STARTBIT_HIGH_SIM - natural(real(CV_STARTBIT_HIGH_SIM) * TOLERANCE_FACTOR));
	constant CV_STARTBIT_HIGH_MAX_SIM 	: natural := (CV_STARTBIT_HIGH_SIM + natural(real(CV_STARTBIT_HIGH_SIM) * TOLERANCE_FACTOR));
	
	signal   CV_STARTBIT_HIGH_MIN 		: natural;
	signal   CV_STARTBIT_HIGH_MAX	 	: natural;
	
	-- databit LOW time: 0.6 ms
	constant CV_DATA_LOW_SYN 			: natural := (CV_SYS_CLOCK_RATE / 1000000) * 600;
	constant CV_DATA_LOW_MIN_SYN 		: natural := (CV_DATA_LOW_SYN - natural(real(CV_DATA_LOW_SYN) * TOLERANCE_FACTOR));
	constant CV_DATA_LOW_MAX_SYN 		: natural := (CV_DATA_LOW_SYN + natural(real(CV_DATA_LOW_SYN) * TOLERANCE_FACTOR));
	
	constant CV_DATA_LOW_SIM 			: natural := 6;
	constant CV_DATA_LOW_MIN_SIM 		: natural := (CV_DATA_LOW_SIM - natural(real(CV_DATA_LOW_SIM) * TOLERANCE_FACTOR));
	constant CV_DATA_LOW_MAX_SIM 		: natural := (CV_DATA_LOW_SIM + natural(real(CV_DATA_LOW_SIM) * TOLERANCE_FACTOR));	
	
	signal   CV_DATA_LOW_MIN 			: natural;
	signal   CV_DATA_LOW_MAX 			: natural;	
	
	-- databit '0' HIGH time: 0.52 ms
	constant CV_DATA0_HIGH_SYN 		: natural := (CV_SYS_CLOCK_RATE / 1000000) * 520;
	constant CV_DATA0_HIGH_MIN_SYN 	: natural := (CV_DATA0_HIGH_SYN - natural(real(CV_DATA0_HIGH_SYN) * TOLERANCE_FACTOR));
	constant CV_DATA0_HIGH_MAX_SYN 	: natural := (CV_DATA0_HIGH_SYN + natural(real(CV_DATA0_HIGH_SYN) * TOLERANCE_FACTOR));
	
	constant CV_DATA0_HIGH_SIM 			: natural := 5;
	constant CV_DATA0_HIGH_MIN_SIM 		: natural := (CV_DATA0_HIGH_SIM - natural(real(CV_DATA0_HIGH_SIM) * TOLERANCE_FACTOR));
	constant CV_DATA0_HIGH_MAX_SIM 		: natural := (CV_DATA0_HIGH_SIM + natural(real(CV_DATA0_HIGH_SIM) * TOLERANCE_FACTOR));
	
	signal   CV_DATA0_HIGH_MIN 			: natural;
	signal   CV_DATA0_HIGH_MAX 			: natural;
	
	-- databit '1' HIGH time: 1.66 ms
	constant CV_DATA1_HIGH_SYN 		: natural := (CV_SYS_CLOCK_RATE / 1000000) * 1660;
	constant CV_DATA1_HIGH_MIN_SYN 	: natural := (CV_DATA1_HIGH_SYN - natural(real(CV_DATA1_HIGH_SYN) * TOLERANCE_FACTOR));
	constant CV_DATA1_HIGH_MAX_SYN 	: natural := (CV_DATA1_HIGH_SYN + natural(real(CV_DATA1_HIGH_SYN) * TOLERANCE_FACTOR));
	
	constant CV_DATA1_HIGH_SIM 			: natural := 16;
	constant CV_DATA1_HIGH_MIN_SIM 		: natural := (CV_DATA1_HIGH_SIM - natural(real(CV_DATA1_HIGH_SIM) * TOLERANCE_FACTOR));
	constant CV_DATA1_HIGH_MAX_SIM 		: natural := (CV_DATA1_HIGH_SIM + natural(real(CV_DATA1_HIGH_SIM) * TOLERANCE_FACTOR));
	
	signal   CV_DATA1_HIGH_MIN 			: natural;
	signal   CV_DATA1_HIGH_MAX 			: natural;
	
	-- fsm
	type state_t IS (S_IDLE, S_START_LOW, S_START_HIGH, S_DATA_LOW, S_DATA_HIGH, S_FINISH);
	signal state, state_nxt 	: state_t;
	
	-- counters
	signal bit_cnt, bit_cnt_nxt 	: unsigned(to_log2(32)-1 downto 0);
	signal time_cnt, time_cnt_nxt 	: unsigned(19 downto 0);	-- max ~20 ms
	
	-- control register
	signal control_reg, control_reg_nxt  	: std_ulogic_vector(0 downto 0);	-- 0: filter on custom code on/off
	-- register for custom code
	signal custom_code, custom_code_nxt 	: std_ulogic_vector(15 downto 0);
	
	-- shift reg for incoming ir data
	signal ir_data, ir_data_nxt 			: std_ulogic_vector(31 downto 0);
	-- output data register
	signal data_out_reg, data_out_reg_nxt 	: std_ulogic_vector(31 downto 0);
	
	-- simple ff to stabilize ir-data signal
	signal irda_rxd_dly, irda_rxd_dly_nxt 	: std_ulogic;
	
	-- interrupt register
	signal irq_rx, irq_rx_nxt 				: std_ulogic;

begin

	-- select correct constant
	CV_STARTBIT_LOW_MIN 	<= CV_STARTBIT_LOW_MIN_SYN		when SIMULATION = false else CV_STARTBIT_LOW_MIN_SIM;
	CV_STARTBIT_LOW_MAX 	<= CV_STARTBIT_LOW_MAX_SYN		when SIMULATION = false else CV_STARTBIT_LOW_MAX_SIM;

	CV_STARTBIT_HIGH_MIN 	<= CV_STARTBIT_HIGH_MIN_SYN	when SIMULATION = false else CV_STARTBIT_HIGH_MIN_SIM;
	CV_STARTBIT_HIGH_MAX 	<= CV_STARTBIT_HIGH_MAX_SYN	when SIMULATION = false else CV_STARTBIT_HIGH_MAX_SIM;

	CV_DATA_LOW_MIN 		<= CV_DATA_LOW_MIN_SYN			when SIMULATION = false else CV_DATA_LOW_MIN_SIM;
	CV_DATA_LOW_MAX 		<= CV_DATA_LOW_MAX_SYN			when SIMULATION = false else CV_DATA_LOW_MAX_SIM;
	
	CV_DATA0_HIGH_MIN 		<= CV_DATA0_HIGH_MIN_SYN		when SIMULATION = false else CV_DATA0_HIGH_MIN_SIM;
	CV_DATA0_HIGH_MAX 		<= CV_DATA0_HIGH_MAX_SYN		when SIMULATION = false else CV_DATA0_HIGH_MAX_SIM;
	
	CV_DATA1_HIGH_MIN 		<= CV_DATA1_HIGH_MIN_SYN		when SIMULATION = false else CV_DATA1_HIGH_MIN_SIM;
	CV_DATA1_HIGH_MAX 		<= CV_DATA1_HIGH_MAX_SYN		when SIMULATION = false else CV_DATA1_HIGH_MAX_SIM;
	
	-- ffs
	process(reset_n, clock)
	begin
		if reset_n = '0' then
			state 	  		<= S_IDLE;
			bit_cnt			<= (others => '0');
			time_cnt 		<= (others => '0');
			control_reg 	<= "1";
			custom_code		<= C_IR_CUSTOM_CODE;
			ir_data 		<= (others => '0');
			data_out_reg 	<= (others => '0');
			irda_rxd_dly 	<= '0';
			irq_rx 			<= '0';
		elsif rising_edge(clock) then
			state 	  		<= state_nxt;
			bit_cnt			<= bit_cnt_nxt;
			time_cnt 		<= time_cnt_nxt;
			control_reg 	<= control_reg_nxt;
			custom_code		<= custom_code_nxt;
			ir_data 		<= ir_data_nxt;
			data_out_reg 	<= data_out_reg_nxt;
			irda_rxd_dly 	<= irda_rxd_dly_nxt;
			irq_rx 			<= irq_rx_nxt;
		end if;
	end process;

	
	-- connect ir-data signal to register
	irda_rxd_dly_nxt	<= irda_rxd;
	-- connect irq-register to iobus
	iobus_irq_rx 		<= irq_rx;
	
	
	-- receive logic
	process(state, bit_cnt, time_cnt, control_reg, custom_code, ir_data, data_out_reg, irda_rxd_dly, irda_rxd, irq_rx, iobus_ack_rx, CV_STARTBIT_LOW_MIN, CV_STARTBIT_LOW_MAX, CV_STARTBIT_HIGH_MIN, CV_STARTBIT_HIGH_MAX, CV_DATA_LOW_MIN, CV_DATA_LOW_MAX, CV_DATA0_HIGH_MIN, CV_DATA0_HIGH_MAX, CV_DATA1_HIGH_MIN, CV_DATA1_HIGH_MAX)
	begin
		-- hold registers
		state_nxt 			<= state;
		bit_cnt_nxt			<= bit_cnt;
		time_cnt_nxt 		<= time_cnt;
		ir_data_nxt 		<= ir_data;
		data_out_reg_nxt 	<= data_out_reg;
		
		-- ack handling
		if iobus_ack_rx = '1' then
			irq_rx_nxt 	<= '0';
		else
			irq_rx_nxt 	<= irq_rx;
		end if;
		
		-- fsm
		case state is
			when S_IDLE =>
				-- start of transmission
				if irda_rxd_dly = '0' then
					-- reset time counter
					time_cnt_nxt 	<= (others => '0');
					-- continue: next LOW of start bit
					state_nxt 		<= S_START_LOW;
				end if;
			
			when S_START_LOW =>
				-- measure LOW time 
				time_cnt_nxt <= time_cnt + 1;
				
				-- on timeout
				if time_cnt = unsigned(to_signed(-1, time_cnt'length)) then
					state_nxt 	<= S_IDLE;
				
				-- ir-data signals goes HIGH
				elsif irda_rxd_dly = '1' then
					-- time measurement not within limits
					if ((time_cnt < CV_STARTBIT_LOW_MIN) or (time_cnt > CV_STARTBIT_LOW_MAX)) then
						state_nxt 	<= S_IDLE;
						
					else
						-- reset counter
						time_cnt_nxt 	<= (others => '0');
						-- continue: next HIGH of start bit
						state_nxt 		<= S_START_HIGH;
					end if;
				end if;
			
			when S_START_HIGH =>
				-- measure HIGH time 
				time_cnt_nxt <= time_cnt + 1;
				
				-- on timeout
				if time_cnt = unsigned(to_signed(-1, time_cnt'length)) then
					state_nxt 	<= S_IDLE;
					
				-- ir-data signals goes LOW
				elsif irda_rxd_dly = '0' then
					-- time measurement not within limits
					if ((time_cnt < CV_STARTBIT_HIGH_MIN) or (time_cnt > CV_STARTBIT_HIGH_MAX)) then
						state_nxt 	<= S_IDLE;
						
					else
						-- reset counters
						time_cnt_nxt 	<= (others => '0');
						bit_cnt_nxt 	<= (others => '0');
						-- continue: next 16 data bits
						state_nxt 		<= S_DATA_LOW;
					end if;
				end if;
			
			when S_DATA_LOW =>
				-- measure LOW time 
				time_cnt_nxt <= time_cnt + 1;
				
				-- on timeout
				if time_cnt = unsigned(to_signed(-1, time_cnt'length)) then
					state_nxt 	<= S_IDLE;
					
				-- ir-data signals goes HIGH
				elsif irda_rxd_dly = '1' then
					-- time measurement not within limits
					if ((time_cnt < CV_DATA_LOW_MIN) or (time_cnt > CV_DATA_LOW_MAX)) then
						state_nxt 	<= S_IDLE;
						
					else
						-- reset counter
						time_cnt_nxt 	<= (others => '0');
						-- continue: next HIGH of data bit
						state_nxt 		<= S_DATA_HIGH;
					end if;
				end if;
			
			when S_DATA_HIGH =>
				-- measure HIGH time 
				time_cnt_nxt <= time_cnt + 1;
				
				-- on timeout
				if time_cnt = unsigned(to_signed(-1, time_cnt'length)) then
					state_nxt 	<= S_IDLE;
					
				-- ir-data signals goes LOW
				elsif irda_rxd_dly = '0' then
					-- time measurement in-between limits of '0' bit 
					if 	((time_cnt > CV_DATA0_HIGH_MIN) and (time_cnt < CV_DATA0_HIGH_MAX)) then
						-- shift in '0'
						ir_data_nxt 	<= '0' & ir_data(31 downto 1);
						-- reset counter
						time_cnt_nxt 	<= (others => '0');
						-- while more data bits expected
						if bit_cnt < 31 then
							-- increase bit counter
							bit_cnt_nxt 	<= bit_cnt + 1;
							-- continue: next LOW of data bit
							state_nxt 		<= S_DATA_LOW;
						else 
							-- stop recording data
							state_nxt 		<= S_FINISH;
						end if;
					
					-- time measurement in-between limits of '1' bit
					elsif ((time_cnt > CV_DATA1_HIGH_MIN) and (time_cnt < CV_DATA1_HIGH_MAX)) then
						-- shift in '1'
						ir_data_nxt 	<= '1' & ir_data(31 downto 1);
						-- reset counter
						time_cnt_nxt 	<= (others => '0');
						-- while more data bits expected
						if bit_cnt < 31 then
							-- increase bit counter
							bit_cnt_nxt 	<= bit_cnt + 1;
							-- continue: next LOW of data bit
							state_nxt 		<= S_DATA_LOW;
						else 
							-- stop recording data
							state_nxt 		<= S_FINISH;
						end if;
						
					-- time measurement not within any limits
					else
						state_nxt 	<= S_IDLE;
					end if;
					
				end if;
			
			when S_FINISH =>
				-- check custom code (if control_reg(0) = '1')
				if ((ir_data(15 downto 0) = custom_code) or (control_reg(0) = '0')) then
					-- check if data is valid
					if ir_data(23 downto 16) = not(ir_data(31 downto 24)) then
						-- set interrupt
						irq_rx_nxt 			<= '1';
						-- save received data in register
						data_out_reg_nxt	<= ir_data;
					end if;
				end if;
				
				-- back to idle
				state_nxt 	<= S_IDLE;
				
		end case; 
		
	end process;
	
	
	-- iobus interface
	process(iobus_cs, iobus_wr, iobus_addr, iobus_din, data_out_reg, control_reg, custom_code)
	begin
		-- hold registers
		control_reg_nxt 	<= control_reg;
		custom_code_nxt		<= custom_code;
		
		iobus_dout			<= (others => '0');
		
		-- chip select
		if iobus_cs = '1' then
			-- read
			if iobus_wr = '0' then
				-- read received data
				if 	iobus_addr = CV_ADDR_IR_DATA then
					iobus_dout(7 downto 0) 	<= data_out_reg(23 downto 16);
				end if;
			end if;
		end if;
		
	end process;

end architecture rtl;