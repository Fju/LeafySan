-----------------------------------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : I2C Master
-- Author 		: Jan Dürre
-- Last update  : 13.01.2016
-- Description	: This I2C-Master supports 4 modes:
-- 				  mode = 00: Only Read Bytes
--				  mode = 01: Only Write Bytes
--				  mode = 10: Read Bytes, Repeated Start, Write Bytes
--				  mode = 11: Write Bytes, Repeated Start, Read Bytes
-- 				  Clock Stretching is supported.
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity i2c_master is
	generic (
		GV_SYS_CLOCK_RATE		: natural := 50000000;
		GV_I2C_CLOCK_RATE		: natural := 400000; 	-- standard mode: (100000) 100 kHz; fast mode: 400000 Hz (400 kHz)
		GW_SLAVE_ADDR 			: natural := 7;
		GV_MAX_BYTES 			: natural := 16;
		GB_USE_INOUT 			: boolean := true;
		GB_TIMEOUT 				: boolean := false
	);
	port (
		clock 					: in  	std_ulogic;
		reset_n					: in  	std_ulogic;
		-- i2c master
		i2c_clk 				: inout std_logic;
		-- separated in / out
		i2c_clk_ctrl 			: out 	std_ulogic;
		i2c_clk_in 				: in 	std_ulogic;
		i2c_clk_out 			: out 	std_ulogic;
		-- inout
		i2c_dat 				: inout	std_logic;
		-- separated in / out
		i2c_dat_ctrl 			: out 	std_ulogic;
		i2c_dat_in 				: in 	std_ulogic;
		i2c_dat_out 			: out 	std_ulogic;
		-- interface
		busy 					: out	std_ulogic;
		cs 						: in 	std_ulogic;
		mode 					: in 	std_ulogic_vector(1 downto 0);
		slave_addr 				: in 	std_ulogic_vector(GW_SLAVE_ADDR-1 downto 0);
		bytes_tx				: in 	unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
		bytes_rx				: in 	unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
		tx_data					: in 	std_ulogic_vector(7 downto 0);
		tx_data_valid			: in 	std_ulogic;
		rx_data					: out	std_ulogic_vector(7 downto 0);
		rx_data_valid			: out 	std_ulogic;
		rx_data_en				: in 	std_ulogic;
		error 					: out 	std_ulogic
	);
end i2c_master;

architecture rtl of i2c_master is

	constant BIT_PERIOD 				: natural := GV_SYS_CLOCK_RATE / GV_I2C_CLOCK_RATE;
	constant BIT_HALFPERIOD 			: natural := GV_SYS_CLOCK_RATE / (2 * GV_I2C_CLOCK_RATE);
	constant BIT_QUARTERPERIOD 			: natural := GV_SYS_CLOCK_RATE / (4 * GV_I2C_CLOCK_RATE);
	constant BIT_PAUSE 					: natural := BIT_PERIOD * 3;
	constant BIT_TIMEOUT				: natural := (GV_SYS_CLOCK_RATE / 1000) * 35; -- 35ms
	
	-- fifos
	component fifo is
		generic (
			DEPTH 		: natural;
			WORDWIDTH 	: natural
		);
		port (
			clock 			: in    std_ulogic;
			reset_n  		: in    std_ulogic;
			write_en		: in 	std_ulogic;
			data_in			: in	std_ulogic_vector(WORDWIDTH-1 downto 0);
			read_en			: in 	std_ulogic;
			data_out		: out	std_ulogic_vector(WORDWIDTH-1 downto 0);
			empty 			: out 	std_ulogic;
			full			: out 	std_ulogic;
			fill_cnt 		: out 	unsigned(to_log2(DEPTH+1)-1 downto 0)
		);
	end component fifo;
	
	signal rx_fifo_write_en		: std_ulogic;
	signal rx_fifo_data_in		: std_ulogic_vector(7 downto 0);
	signal rx_fifo_read_en		: std_ulogic;
	signal rx_fifo_data_out		: std_ulogic_vector(7 downto 0);
	signal rx_fifo_empty 		: std_ulogic;
	
	signal tx_fifo_write_en		: std_ulogic;
	signal tx_fifo_data_in		: std_ulogic_vector(7 downto 0);
	signal tx_fifo_read_en		: std_ulogic;
	signal tx_fifo_data_out		: std_ulogic_vector(7 downto 0);
	signal tx_fifo_empty		: std_ulogic;
	
	
	-- register to save requests
	signal mode_reg, mode_reg_nxt 				: std_ulogic_vector(1 downto 0);
	signal slave_addr_reg, slave_addr_reg_nxt 	: std_ulogic_vector(GW_SLAVE_ADDR-1 downto 0);
	signal bytes_tx_reg, bytes_tx_reg_nxt		: unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
	signal bytes_rx_reg, bytes_rx_reg_nxt		: unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
	
	
	-- control fsm
	type state_t is (	S_IDLE,
						S_START,
						S_START_PAUSE,
						S_TX_SLAVE_ADDR_LF, S_TX_SLAVE_ADDR_H, S_TX_SLAVE_ADDR_LB, 
						S_TX_BYTE_LF, S_TX_BYTE_H, S_TX_BYTE_LB, 
						S_REPEAT_START_L, S_REPEAT_START_H,
						S_RX_BYTE_L, S_RX_BYTE_H,
						S_PAUSE,
						S_RX_ACK_L, S_RX_ACK_H,
						S_TX_ACK_LF, S_TX_ACK_H, S_TX_ACK_LB,
						S_STOP_L, S_STOP_H,
						S_CLEANUP
					);
	
	signal state, state_nxt 				: state_t;
	signal follow_state, follow_state_nxt 	: state_t;
	
	-- data shift register
	signal i2c_tx_shift_reg, i2c_tx_shift_reg_nxt 		: std_logic_vector(max(8, GW_SLAVE_ADDR + 1)-1 downto 0);
	signal i2c_rx_shift_reg, i2c_rx_shift_reg_nxt 		: std_logic_vector(7 downto 0);
	
	-- counter
	signal tx_byte_cnt, tx_byte_cnt_nxt 	: unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
	signal rx_byte_cnt, rx_byte_cnt_nxt 	: unsigned(to_log2(GV_MAX_BYTES+1)-1 downto 0);
	signal bit_cnt, bit_cnt_nxt				: unsigned(to_log2(max(8, GW_SLAVE_ADDR + 1))-1 downto 0);
	
	signal time_cnt, time_cnt_nxt 			: unsigned(to_log2(10 * BIT_PERIOD)-1 downto 0);
	signal time_cnt_reset 					: std_ulogic;
	signal time_cnt_period 					: std_ulogic;
	signal time_cnt_period_tick				: std_ulogic;
	signal time_cnt_halfperiod 				: std_ulogic;
	signal time_cnt_halfperiod_tick 		: std_ulogic;
	signal time_cnt_quarterperiod			: std_ulogic;
	signal time_cnt_quarterperiod_tick		: std_ulogic;
	signal time_cnt_pause_timeout 			: std_ulogic;
	
	signal timeout_cnt, timeout_cnt_nxt 	: unsigned(31 downto 0);
	signal timeout_reset 					: std_ulogic;
	signal timeout 							: std_ulogic;
	
	-- error flag
	signal error_int, error_int_nxt : std_ulogic;
	
	-- i2c wires
	signal i2c_clk_wire 		: std_logic;
	signal i2c_clk_in_wire 		: std_ulogic;
	signal i2c_dat_wire 		: std_logic;
	signal i2c_dat_in_wire 		: std_ulogic;
	
begin

	-- check if slave-address-width is 7 or 10 (as in nxp reference definition)
	assert ((GW_SLAVE_ADDR = 7) or (GW_SLAVE_ADDR = 10)) 	report "Warning: Most I2C-Interfaces only support 7 or 10 Bit Slave-Addresses!" severity warning;

	-- fifos
	rx_buf_inst : fifo
		generic map (
			DEPTH 		=> GV_MAX_BYTES,
			WORDWIDTH 	=> 8
		)
		port map (
			clock 		=> clock,
			reset_n  	=> reset_n,
			write_en	=> rx_fifo_write_en,
			data_in		=> rx_fifo_data_in,
			read_en		=> rx_fifo_read_en,
			data_out	=> rx_fifo_data_out,
			empty 		=> rx_fifo_empty,
			full		=> open,
			fill_cnt 	=> open
		);
		
	tx_buf_inst : fifo
		generic map (
			DEPTH 		=> GV_MAX_BYTES,
			WORDWIDTH 	=> 8
		)
		port map (
			clock 		=> clock,
			reset_n  	=> reset_n,
			write_en	=> tx_fifo_write_en,
			data_in		=> tx_fifo_data_in,
			read_en		=> tx_fifo_read_en,
			data_out	=> tx_fifo_data_out,
			empty 		=> tx_fifo_empty,
			full		=> open,
			fill_cnt 	=> open
		);
	
		
	-- ff
	process(clock, reset_n)
	begin
		if reset_n = '0' then
			state 				<= S_IDLE;
			follow_state 		<= S_IDLE;
			i2c_tx_shift_reg	<= (others => '0');
			i2c_rx_shift_reg	<= (others => '0');
			mode_reg			<= (others => '0');
			slave_addr_reg		<= (others => '0');
			bytes_tx_reg		<= (others => '0');
			bytes_rx_reg		<= (others => '0');
			tx_byte_cnt			<= (others => '0');
			rx_byte_cnt			<= (others => '0');
			bit_cnt 			<= (others => '0');
			time_cnt 			<= (others => '0');
			timeout_cnt 		<= (others => '0');
			error_int 			<= '0';
			
		elsif rising_edge(clock) then 
			state 				<= state_nxt;
			follow_state 		<= follow_state_nxt;
			i2c_tx_shift_reg	<= i2c_tx_shift_reg_nxt;
			i2c_rx_shift_reg	<= i2c_rx_shift_reg_nxt;
			mode_reg			<= mode_reg_nxt;
			slave_addr_reg		<= slave_addr_reg_nxt;
			bytes_tx_reg		<= bytes_tx_reg_nxt;
			bytes_rx_reg		<= bytes_rx_reg_nxt;
			tx_byte_cnt 		<= tx_byte_cnt_nxt;
			rx_byte_cnt 		<= rx_byte_cnt_nxt;
			bit_cnt 			<= bit_cnt_nxt;
			time_cnt 			<= time_cnt_nxt;
			timeout_cnt 		<= timeout_cnt_nxt;
			error_int 			<= error_int_nxt;
			
		end if;
	end process;
	
	-- connect entity to fifos
	tx_fifo_data_in 	<= tx_data;
	tx_fifo_write_en 	<= tx_data_valid;
	rx_data				<= rx_fifo_data_out;
	rx_data_valid		<= not rx_fifo_empty;
	rx_fifo_read_en 	<= rx_data_en;
	
	
	-- time counter
	process(time_cnt, time_cnt_reset)
	begin
		time_cnt_period 					<= '0';
		time_cnt_period_tick 				<= '0';
		time_cnt_halfperiod 				<= '0';
		time_cnt_halfperiod_tick 			<= '0';
		time_cnt_quarterperiod 				<= '0';
		time_cnt_quarterperiod_tick 		<= '0';
		time_cnt_pause_timeout 				<= '0';
	
		if time_cnt_reset = '1' then
			time_cnt_nxt <= (others => '0');
		else
			time_cnt_nxt <= time_cnt + 1;
		end if;
		
		if time_cnt >= BIT_PERIOD then
			time_cnt_period <= '1';
		end if;
		
		if time_cnt = BIT_PERIOD then
			time_cnt_period_tick <= '1';
		end if;
		
		if time_cnt >= BIT_HALFPERIOD then
			time_cnt_halfperiod <= '1';
		end if;
		
		if time_cnt = BIT_HALFPERIOD then
			time_cnt_halfperiod_tick <= '1';
		end if;
		
		if time_cnt >= BIT_QUARTERPERIOD then
			time_cnt_quarterperiod <= '1';
		end if;
		
		if time_cnt = BIT_QUARTERPERIOD then
			time_cnt_quarterperiod_tick <= '1';
		end if;
		
		if time_cnt >= BIT_PAUSE then
			time_cnt_pause_timeout <= '1';
		end if;
	end process;
	
	-- timeout counter
	process(timeout_cnt, timeout_reset)
	begin
		timeout <= '0';
	
		if timeout_reset = '1' then
			timeout_cnt_nxt <= (others => '0');
		else
			timeout_cnt_nxt <= timeout_cnt + 1;
		end if;
		
		if GB_TIMEOUT = true then
			if timeout_cnt = BIT_TIMEOUT then
				timeout <= '1';
			end if;
		end if;
	
	end process;
	
	
	-- i2c lines can only be driven with '0', a logical one is implemented via pull-up -> 'Z'
	inout_gen : if GB_USE_INOUT = true generate
		i2c_clk	<= 	'0' when i2c_clk_wire = '0' else
					'Z';
					
		i2c_clk_ctrl 		<= '0';
		i2c_clk_out 		<= 'Z';
		i2c_clk_in_wire 	<= i2c_clk;
	
	
		i2c_dat <= 	'0' when i2c_dat_wire = '0' else
					'Z';

		i2c_dat_ctrl 	<= '0';
		i2c_dat_out 	<= 'Z';
		i2c_dat_in_wire <= i2c_dat;
		
	end generate inout_gen;


	sep_inout_gen : if GB_USE_INOUT = false generate

		i2c_clk 		<= 'Z';
		i2c_clk_in_wire <= i2c_clk_in;
		i2c_dat 		<= 'Z';
		i2c_dat_in_wire <= i2c_dat_in;
		
		process(i2c_clk_wire)
		begin
			if i2c_clk_wire = '0' then
				i2c_clk_ctrl <= '1';
				i2c_clk_out <= '0';
			else
				i2c_clk_ctrl <= '0';
				i2c_clk_out <= 'Z';
			end if;
		end process;

		process(i2c_dat_wire)
		begin
			if i2c_dat_wire = '0' then
				i2c_dat_ctrl <= '1';
				i2c_dat_out <= '0';
			else
				i2c_dat_ctrl <= '0';
				i2c_dat_out <= 'Z';
			end if;
		end process;

	end generate sep_inout_gen;

	
	-- logic
	process(state, follow_state, i2c_tx_shift_reg, i2c_rx_shift_reg, mode_reg, slave_addr_reg, bytes_tx_reg, bytes_rx_reg, tx_byte_cnt, rx_byte_cnt, bit_cnt, time_cnt_period, time_cnt_period_tick, time_cnt_halfperiod, time_cnt_halfperiod_tick, time_cnt_quarterperiod, time_cnt_quarterperiod_tick, time_cnt_pause_timeout, timeout, error_int, cs, mode, slave_addr, bytes_tx, bytes_rx, tx_fifo_empty, tx_fifo_data_out, i2c_clk_in_wire, i2c_dat_in_wire)
	begin
		-- regs
		state_nxt				<= state;
		follow_state_nxt 		<= follow_state;
		i2c_tx_shift_reg_nxt	<= i2c_tx_shift_reg;
		i2c_rx_shift_reg_nxt	<= i2c_rx_shift_reg;
		mode_reg_nxt			<= mode_reg;
		slave_addr_reg_nxt		<= slave_addr_reg;
		bytes_tx_reg_nxt		<= bytes_tx_reg;
		bytes_rx_reg_nxt		<= bytes_rx_reg;
		tx_byte_cnt_nxt 		<= tx_byte_cnt;
		rx_byte_cnt_nxt 		<= rx_byte_cnt;
		bit_cnt_nxt 			<= bit_cnt;
		
		-- busy signal
		busy 					<= '1';
		
		-- count control
		time_cnt_reset 			<= '0';
		timeout_reset 			<= '0';

	
		-- i2c
		i2c_dat_wire 			<= '1';
		i2c_clk_wire 			<= '1';
		
		-- error
		error_int_nxt 			<= error_int;
		error 					<= error_int;
		
		-- fifo
		rx_fifo_write_en 	<= '0';
		rx_fifo_data_in		<= (others => '0');
		tx_fifo_read_en 	<= '0';
		

		-- fsm
		case state is
			----------
			-- Idle --
			----------
			when S_IDLE =>
				busy <= '0';
				
				-- work request
				if cs = '1' then
					--if i2c_clk_in_wire = '1' and i2c_dat_in_wire = '1' then
					if i2c_clk_in_wire = '1' then
						-- save relevant information to registers
						mode_reg_nxt		<= mode;
						slave_addr_reg_nxt	<= slave_addr;
						bytes_tx_reg_nxt	<= bytes_tx;
						bytes_rx_reg_nxt	<= bytes_rx;
						
						-- reset error-flag
						error_int_nxt 		<= '0';
						
						-- begin with start-condition
						state_nxt 			<= S_START;
						time_cnt_reset 		<= '1';
						timeout_reset 		<= '1';
					else
						-- something is going on!
						-- set error-flag
						error_int_nxt <= '1';
					end if;
				end if;
				
				
			-----------
			-- Start --
			-----------
			when S_START =>
				-- generate start condition
				i2c_clk_wire	<= '1';
				i2c_dat_wire 	<= '0';
				
				if time_cnt_halfperiod = '1' then
					state_nxt 				<= S_START_PAUSE;--S_TX_SLAVE_ADDR_LF;
					time_cnt_reset 			<= '1';
					timeout_reset 			<= '1';
					
					bit_cnt_nxt 			<= (others => '0');
					tx_byte_cnt_nxt 		<= (others => '0');
					rx_byte_cnt_nxt 		<= (others => '0');
					
					-- next follows RX
					if 		mode_reg = "00" or mode_reg = "10" then
						
						i2c_tx_shift_reg_nxt  	<= std_logic_vector(slave_addr_reg) & '1';
						follow_state_nxt 		<= S_RX_BYTE_L;
						
					-- next follows TX
					elsif 	mode_reg = "01" or mode_reg = "11" then
						
						i2c_tx_shift_reg_nxt  	<= std_logic_vector(slave_addr_reg) & '0';
						follow_state_nxt 		<= S_TX_BYTE_LF;
						
					end if;
					
				end if;
				

			when S_START_PAUSE =>
				-- pull down clk
				i2c_clk_wire <= '0';
				-- pull down dat
				i2c_dat_wire <= '0';
				
				if time_cnt_pause_timeout = '1' then
					state_nxt 		<= S_TX_SLAVE_ADDR_LF;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				
				
			----------------
			-- Slave Addr --
			----------------
			when S_TX_SLAVE_ADDR_LF =>
				-- pull clk low
				i2c_clk_wire <= '0';
				-- set data
				i2c_dat_wire <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-1);
				
				-- wait for quarter-period
				if time_cnt_quarterperiod = '1' then
					state_nxt 		<= S_TX_SLAVE_ADDR_H;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				
			when S_TX_SLAVE_ADDR_H =>
				-- let clk float
				i2c_clk_wire <= '1';
				-- hold data
				i2c_dat_wire <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-1);
			
				-- wait for clk to pull up, reset counter while low
				if i2c_clk_in_wire = '0' then
					time_cnt_reset <= '1';
				end if;
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					state_nxt <= S_TX_SLAVE_ADDR_LB;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				-- reset
				if timeout = '1' then
					state_nxt <= S_STOP_L;
					timeout_reset <= '1';
					error_int_nxt <= '1';
				end if;
				
				
			when S_TX_SLAVE_ADDR_LB =>
				-- pull clk low again
				i2c_clk_wire <= '0';
				-- set data
				i2c_dat_wire <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-1);
				
				if time_cnt_quarterperiod = '1' then
					-- shift tx data
					i2c_tx_shift_reg_nxt <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-2 downto 0) & '0';
					
					-- size of slave address reached
					if bit_cnt = GW_SLAVE_ADDR then
						-- reset counter
						bit_cnt_nxt <= (others => '0');
						
						state_nxt 		<= S_RX_ACK_L;
						time_cnt_reset 	<= '1';
						timeout_reset 	<= '1';
						
						-- fetch byte from fifo when TX is following
						if follow_state = S_TX_BYTE_LF then
							if tx_fifo_empty = '0' then
								tx_fifo_read_en <= '1';
							end if;
							i2c_tx_shift_reg_nxt(i2c_tx_shift_reg'length-1 downto i2c_tx_shift_reg'length-8) <= std_logic_vector(tx_fifo_data_out);
						end if;
						
					else
						-- addr-bits missing
						bit_cnt_nxt 	<= bit_cnt + 1;
						state_nxt 		<= S_TX_SLAVE_ADDR_LF;
						time_cnt_reset 	<= '1';
						timeout_reset 	<= '1';
						
					end if;
				end if;
				
				
			-------------
			-- TX Byte --
			-------------
			when S_TX_BYTE_LF =>
				-- pull clk low
				i2c_clk_wire <= '0';
				-- set data
				i2c_dat_wire <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-1);
				
				-- wait for a quarter-period
				if time_cnt_halfperiod = '1' then
					state_nxt 		<= S_TX_BYTE_H;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				
			when S_TX_BYTE_H =>
				-- let clk float
				i2c_clk_wire <= '1';
				-- hold data
				i2c_dat_wire <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-1);
			
				-- wait for clk to pull up, reset counter while low
				if i2c_clk_in_wire = '0' then
					time_cnt_reset <= '1';
				end if;
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					state_nxt <= S_TX_BYTE_LB;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				-- reset
				if timeout = '1' then
					state_nxt <= S_STOP_L;
					timeout_reset <= '1';
					error_int_nxt <= '1';
				end if;
				
				
			when S_TX_BYTE_LB =>
				-- pull clk low again
				i2c_clk_wire <= '0';
				-- set data
				i2c_dat_wire <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-1);
				
				if time_cnt_quarterperiod = '1' then
					-- shift tx data
					i2c_tx_shift_reg_nxt <= i2c_tx_shift_reg(i2c_tx_shift_reg'length-2 downto 0) & '0';
					
					-- byte complete
					if bit_cnt = 7 then
						-- next byte
						tx_byte_cnt_nxt <= tx_byte_cnt + 1;
						-- reset counter
						bit_cnt_nxt 	<= (others => '0');
						-- await ack
						state_nxt 		<= S_RX_ACK_L;
						time_cnt_reset 	<= '1';
						timeout_reset 	<= '1';
						
						-- all bytes transferred
						if tx_byte_cnt = bytes_tx_reg - 1 then
							if mode_reg = "01" or mode_reg = "10" then
								-- end transfer after ack
								follow_state_nxt <= S_STOP_L;
							elsif mode_reg = "11" then
								-- turn to rx
								follow_state_nxt <= S_REPEAT_START_L;
							end if;
						-- not all bytes transferred
						else
							-- fetch new byte from fifo
							if tx_fifo_empty = '0' then
								tx_fifo_read_en <= '1';
							end if;
							i2c_tx_shift_reg_nxt(i2c_tx_shift_reg'length-1 downto i2c_tx_shift_reg'length-8) <= std_logic_vector(tx_fifo_data_out);
							-- continue after ack
							follow_state_nxt <= S_TX_BYTE_LF;
						end if;
						
					else
						-- continue byte
						bit_cnt_nxt 	<= bit_cnt + 1;
						state_nxt 		<= S_TX_BYTE_LF;
						time_cnt_reset 	<= '1';
						timeout_reset 	<= '1';
					end if;
					
				end if;
				

			--------------------
			-- Repeated Start --
			--------------------
			when S_REPEAT_START_L =>
				-- pull clk low
				i2c_clk_wire <= '0';
				-- let dat float
				i2c_dat_wire <= '1';
				
				-- wait for data to pull up, reset counter while low
				if i2c_dat_in_wire = '0' then
					time_cnt_reset <= '1';
				end if;
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					state_nxt 		<= S_REPEAT_START_H;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				-- reset
				if timeout = '1' then
					state_nxt <= S_STOP_L;
					timeout_reset <= '1';
					error_int_nxt <= '1';
				end if;
			
			
			when S_REPEAT_START_H =>
				-- let clk float
				i2c_clk_wire <= '1';
				-- let dat float
				i2c_dat_wire <= '1';
			
				-- wait for clk to pull up, reset counter while low
				if i2c_clk_in_wire = '0' then
					time_cnt_reset <= '1';
				end if;
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					-- pull dat down for repeated start condition
					i2c_dat_wire <= '0';
				end if;
				
				-- wait for one period
				if time_cnt_period = '1' then
					state_nxt 		<= S_START_PAUSE;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
					
					-- next follows TX
					if mode_reg = "10" then
						i2c_tx_shift_reg_nxt  	<= std_logic_vector(slave_addr_reg) & '0';
						follow_state_nxt 		<= S_TX_BYTE_LF;
					
					-- next follows RX
					elsif mode_reg = "11" then
						i2c_tx_shift_reg_nxt  	<= std_logic_vector(slave_addr_reg) & '1';
						follow_state_nxt 		<= S_RX_BYTE_L;
						
					end if;
					
				end if;
				
				-- reset
				if timeout = '1' then
					state_nxt <= S_STOP_L;
					timeout_reset <= '1';
					error_int_nxt <= '1';
				end if;
				

			-------------
			-- RX Byte --
			-------------
			when S_RX_BYTE_L =>
				-- pull clk down
				i2c_clk_wire <= '0';
				-- let dat float
				i2c_dat_wire <= '1';
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					state_nxt 		<= S_RX_BYTE_H;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
			
			
			when S_RX_BYTE_H =>
				-- let clk float
				i2c_clk_wire <= '1';
				-- let dat float
				i2c_dat_wire <= '1';
				
				-- wait for clk to pull up, reset counter while low
				if i2c_clk_in_wire = '0' then
					time_cnt_reset <= '1';
				end if;
				
				-- wait for a quarter-period
				if time_cnt_quarterperiod_tick = '1' then
					-- shift in data bit
					i2c_rx_shift_reg_nxt <= i2c_rx_shift_reg(i2c_rx_shift_reg'length-2 downto 0) & i2c_dat_in_wire;
				end if;
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					-- byte complete
					if bit_cnt = 7 then
						-- next byte
						rx_byte_cnt_nxt <= rx_byte_cnt + 1;
						-- reset counter
						bit_cnt_nxt 	<= (others => '0');
						-- send ack
						state_nxt 		<= S_TX_ACK_LF;
						time_cnt_reset 	<= '1';
						timeout_reset 	<= '1';
						
						-- all bytes transferred (register data)
						if rx_byte_cnt = bytes_rx_reg - 1 then
							if mode_reg = "00" or mode_reg = "11" then
								-- stop start after ack-transfer
								follow_state_nxt <= S_STOP_L;
							elsif mode_reg = "10" then
								-- or turn to TX
								follow_state_nxt <= S_REPEAT_START_L;
							end if;
							
						-- not all bytes transferred
						else
							-- continue receiving register data after ack-transfer
							follow_state_nxt <= S_RX_BYTE_L;
						end if;
					else
						-- continue byte
						bit_cnt_nxt 	<= bit_cnt + 1;
						state_nxt 		<= S_RX_BYTE_L;
						time_cnt_reset 	<= '1';
						timeout_reset 	<= '1';
					end if;
				end if;
			
				
				-- reset
				if timeout = '1' then
					state_nxt <= S_STOP_L;
					timeout_reset <= '1';
					error_int_nxt <= '1';
				end if;
				
			
			------------
			-- RX Ack --
			------------
			when S_RX_ACK_L =>
				-- pull clk down
				i2c_clk_wire <= '0';
				-- let dat float
				i2c_dat_wire <= '1';
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					state_nxt 		<= S_RX_ACK_H;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;

				
			when S_RX_ACK_H =>
				-- let clk float
				i2c_clk_wire <= '1';
				-- let dat float
				i2c_dat_wire <= '1';
				
				-- wait for clk to pull up, reset counter while low
				if i2c_clk_in_wire = '0' then
					time_cnt_reset <= '1';
				end if;
				
				-- wait for a quarter-period
				if time_cnt_quarterperiod_tick = '1' then
					-- check for nack
					if i2c_dat_in_wire = '1' then
						error_int_nxt <= '1';
					end if;
				end if;
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					if error_int = '0' then
						-- continue
						state_nxt 		<= S_PAUSE;
						time_cnt_reset 	<= '1';
						timeout_reset 	<= '1';
						
					-- negative ack
					else
						-- abort
						state_nxt 		<= S_STOP_L;
						time_cnt_reset 	<= '1';
						timeout_reset 	<= '1';
						
					end if;
				end if;
				
				
				-- reset
				if timeout = '1' then
					state_nxt <= S_STOP_L;
					timeout_reset <= '1';
					error_int_nxt <= '1';
				end if;
				
			
			------------
			-- TX Ack --
			------------
			when S_TX_ACK_LF =>
				-- pull clk down
				i2c_clk_wire <= '0';
				-- let dat flow
				i2c_dat_wire <= '1';
			
				-- wait for quarter-period
				if time_cnt_quarterperiod = '1' then
					-- only ack when not last rx-byte!
					if rx_byte_cnt /= bytes_rx_reg then
						-- pull down dat (ack)
						i2c_dat_wire <= '0';
					end if;
				end if;
				
				-- wait for half-period
				if time_cnt_halfperiod = '1' then
					state_nxt 		<= S_TX_ACK_H;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				
			when S_TX_ACK_H =>
				-- let clk float
				i2c_clk_wire <= '1';				
				-- only ack when not last rx-byte!
				if rx_byte_cnt /= bytes_rx_reg then
					-- pull down dat (ack)
					i2c_dat_wire <= '0';
				else
					-- let dat float (nack)
					i2c_dat_wire <= '1';
				end if;
			
				-- wait for clk to pull up, reset counter while low
				if i2c_clk_in_wire = '0' then
					time_cnt_reset <= '1';
				end if;
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					state_nxt <= S_TX_ACK_LB;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				-- reset
				if timeout = '1' then
					state_nxt <= S_STOP_L;
					timeout_reset <= '1';
					error_int_nxt <= '1';
				end if;
				
				
			when S_TX_ACK_LB =>
				-- pull clk down
				i2c_clk_wire <= '0';
				-- only ack when not last rx-byte!
				if rx_byte_cnt /= bytes_rx_reg then
					-- pull down dat (ack)
					i2c_dat_wire <= '0';
				else
					-- let dat float (nack)
					i2c_dat_wire <= '1';
				end if;
			
				-- wait for quarter-period
				if time_cnt_quarterperiod = '1' then
					-- save byte to fifo
					rx_fifo_write_en 	<= '1';
					rx_fifo_data_in		<= std_ulogic_vector(i2c_rx_shift_reg);
					-- continue
					state_nxt 		<= S_PAUSE;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				
			-----------
			-- Pause --
			-----------
			when S_PAUSE =>
				-- let clk float
				i2c_clk_wire <= '0';
				-- let dat float
				i2c_dat_wire <= '1';
				
				if time_cnt_pause_timeout = '1' then
					state_nxt 		<= follow_state;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
				
			----------
			-- Stop --
			----------
			when S_STOP_L =>
				-- pull clk down
				i2c_clk_wire <= '0';
				-- pull clk down
				i2c_dat_wire <= '0';
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					state_nxt 		<= S_STOP_H;
					time_cnt_reset 	<= '1';
					timeout_reset 	<= '1';
				end if;
				
			when S_STOP_H =>
				-- let clk float
				i2c_clk_wire <= '1';
				-- pull clk down
				i2c_dat_wire <= '0';
				
				-- wait for clk to pull up, reset counter while low
				if i2c_clk_in_wire = '0' then
					time_cnt_reset <= '1';
				end if;
				
				-- wait for a half-period
				if time_cnt_halfperiod = '1' then
					-- let dat float for stop condition
					i2c_dat_wire <= '1';
				end if;

				-- clean exit
				if time_cnt_period = '1' then
					state_nxt <= S_CLEANUP;
				end if;
				
				
				-- error
				if timeout = '1' then
					state_nxt <= S_CLEANUP;
					error_int_nxt <= '1';
				end if;
			
			
			--------------
			-- Clean-Up --
			--------------
			when S_CLEANUP =>
				-- not all bytes transferred, empty tx-fifo
				if tx_byte_cnt /= bytes_tx_reg then
					if tx_fifo_empty = '0' then
						tx_fifo_read_en <= '1';
					end if;
					-- next byte
					tx_byte_cnt_nxt <= tx_byte_cnt + 1;
				else
					state_nxt <= S_IDLE;
				end if;
			
		end case;
	
	end process;
	

end rtl;




