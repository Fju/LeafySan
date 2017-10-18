----------------------------------------------------------------------
-- Project		:	LeafySan
-- Module		:	Moisture Sensor Module
-- Authors		:	Florian Winkler
-- Lust update	:	01.09.2017
-- Description	:	Reads a digital soil moisture sensor through an I2C bus
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity moisture_sensor is
	generic (
		CYCLE_TICKS			: natural	:= 50000000
	);
	port(
		clock				: in  std_ulogic;
		reset				: in  std_ulogic;
		-- i2c bus
		i2c_clk_ctrl 		: out std_ulogic;
		i2c_clk_in 			: in  std_ulogic;
		i2c_clk_out 		: out std_ulogic;
		i2c_dat_ctrl 		: out std_ulogic;
		i2c_dat_in 			: in  std_ulogic;
		i2c_dat_out 		: out std_ulogic;
		moisture			: out unsigned(15 downto 0);
		temperature			: out unsigned(15 downto 0);
		address				: out unsigned(6 downto 0);
		enabled				: in  std_ulogic
	);
end moisture_sensor;

architecture rtl of moisture_sensor is

	component i2c_master is
		generic (
			GV_SYS_CLOCK_RATE	: natural := 50000000;
			GV_I2C_CLOCK_RATE 	: natural := 400000; 	-- fast mode: 400000 Hz (400 kHz)
			GW_SLAVE_ADDR 		: natural := 7;
			GV_MAX_BYTES 		: natural := 16;
			GB_USE_INOUT 		: boolean := false;		-- seperated io signals (ctrl, out, in)
			GB_TIMEOUT 			: boolean := false
		);
		port (
			clock 				: in  std_ulogic;
			reset_n				: in  std_ulogic;
			-- separated in / out
			i2c_clk_ctrl 		: out std_ulogic;
			i2c_clk_in 			: in  std_ulogic;
			i2c_clk_out 		: out std_ulogic;
			-- separated in / out
			i2c_dat_ctrl 		: out std_ulogic;
			i2c_dat_in 			: in  std_ulogic;
			i2c_dat_out 		: out std_ulogic;
			-- interface
			busy 				: out std_ulogic;
			cs 					: in  std_ulogic;
			mode 				: in  std_ulogic_vector(1 downto 0);	-- 00: only read; 01: only write; 10: first read, second write; 11: first write, second read
			slave_addr 			: in  std_ulogic_vector(GW_SLAVE_ADDR - 1 downto 0);
			bytes_tx			: in  unsigned(to_log2(GV_MAX_BYTES + 1) - 1 downto 0);
			bytes_rx			: in  unsigned(to_log2(GV_MAX_BYTES + 1) - 1 downto 0);
			tx_data				: in  std_ulogic_vector(7 downto 0);
			tx_data_valid		: in  std_ulogic;
			rx_data_en			: in  std_ulogic;
			rx_data				: out std_ulogic_vector(7 downto 0);
			rx_data_valid		: out std_ulogic;
			error 				: out std_ulogic
		);
	end component i2c_master;
	

	type moist_state_t is (S_ADDR_SCAN, S_ADDR_REGISTER_BYTE0, S_ADDR_REGISTER_BYTE1, S_ADDR_REGISTER_SEND, S_ADDR_CHECK,
							S_ADDR_RESET_BYTE0, S_ADDR_RESET_SEND, S_MST_BOOT_DELAY, S_MST_IDLE, S_MST_REGISTER_BYTE0, S_MST_REGISTER_SEND_BYTE0,
							S_MST_READ_DELAY, S_MST_READ_START, S_MST_READ_WAIT, S_MST_READ_BYTES, S_MST_CHECK, S_TMP_REGISTER_BYTE0,
							S_TMP_REGISTER_SEND_BYTE0, S_TMP_READ_DELAY, S_TMP_READ_START, S_TMP_READ_WAIT, S_TMP_READ_BYTES, S_TMP_CHECK);
	signal moist_state, moist_state_nxt	: moist_state_t;
	
	constant MOIST_SLAVE_ADDR		: std_ulogic_vector(6 downto 0) := "0100000"; -- 0x20 (default address)
	constant SCAN_ADDR_START		: unsigned(6 downto 0)	:= "0001000"; -- 0x08 (lowest available i2c address)
	constant SCAN_ADDR_END			: unsigned(6 downto 0)	:= "1110111"; -- 0x77 (highest available i2c address)
	
	-- moisture register addresses
	constant MOIST_REG_RESET		: std_ulogic_vector(7 downto 0) := "00000110"; -- 0x06
	constant MOIST_REG_SLEEP		: std_ulogic_vector(7 downto 0) := "00001000"; -- 0x08
	constant MOIST_REG_MOISTURE		: std_ulogic_vector(7 downto 0) := "00000000"; -- 0x00
	constant MOIST_REG_SET_ADDR		: std_ulogic_vector(7 downto 0) := "00000001"; -- 0x01
	constant MOIST_REG_TEMP			: std_ulogic_vector(7 downto 0) := "00000101"; -- 0x05

	constant MOIST_VALUES_WIDTH : natural := 2; -- 2 bytes
	signal moist_received_cnt, moist_received_cnt_nxt	: unsigned(to_log2(MOIST_VALUES_WIDTH + 1) - 1 downto 0);
	signal moist_valid, moist_valid_nxt					: std_ulogic;
	type moist_vals_array is array (natural range <>) of std_ulogic_vector(7 downto 0);
	signal moist_vals, moist_vals_nxt 	: moist_vals_array(0 to MOIST_VALUES_WIDTH - 1);
	signal moist_busy 					: std_ulogic;
	
	constant MOIST_BOOT_DELAY_TICKS		: natural := 50000000;	-- 1s
	constant MOIST_READ_DELAY_TICKS		: natural := 1000000;	-- 20ms

	signal moist_boot_delay_cnt, moist_boot_delay_cnt_nxt	: unsigned(to_log2(MOIST_BOOT_DELAY_TICKS) - 1 downto 0);
	signal moist_read_delay_cnt, moist_read_delay_cnt_nxt	: unsigned(to_log2(MOIST_READ_DELAY_TICKS) - 1 downto 0);
	
	signal scan_addr, scan_addr_nxt		: unsigned(6 downto 0);
	
	-- signals of `i2c_master` component
	signal i2c_reset_n			: std_ulogic;
	signal i2c_busy 			: std_ulogic;
	signal i2c_cs 				: std_ulogic;
	signal i2c_mode 			: std_ulogic_vector(1 downto 0);
	signal i2c_slave_addr 		: std_ulogic_vector(6 downto 0);
	signal i2c_bytes_tx			: unsigned(4 downto 0);
	signal i2c_bytes_rx			: unsigned(4 downto 0);
	signal i2c_tx_data			: std_ulogic_vector(7 downto 0);
	signal i2c_tx_data_valid	: std_ulogic;
	signal i2c_rx_data_en		: std_ulogic;
	signal i2c_rx_data			: std_ulogic_vector(7 downto 0);
	signal i2c_rx_data_valid	: std_ulogic;
	signal i2c_error 			: std_ulogic;
	
	-- output registers
	signal moisture_reg, moisture_reg_nxt		: unsigned(15 downto 0);
	signal temp_reg, temp_reg_nxt				: unsigned(15 downto 0);
	
	-- cycle registers
	signal cycle_cnt, cycle_cnt_nxt	: unsigned(to_log2(CYCLE_TICKS) - 1 downto 0);
	signal cycle_pulse				: std_ulogic;
begin
	-- configure `i2c_master` signal assignments
	i2c_master_inst : i2c_master
		generic map (
			GV_SYS_CLOCK_RATE	=> CV_SYS_CLOCK_RATE,
			GV_I2C_CLOCK_RATE 	=> 400000, -- fast mode 400kHz
			GW_SLAVE_ADDR 		=> 7,
			GV_MAX_BYTES 		=> 16,
			GB_USE_INOUT 		=> false,
			GB_TIMEOUT 			=> false
		)
		port map (
			clock 				=> clock,
			reset_n				=> i2c_reset_n,
			i2c_clk_ctrl 		=> i2c_clk_ctrl,
			i2c_clk_in 			=> i2c_clk_in,
			i2c_clk_out 		=> i2c_clk_out,
			i2c_dat_ctrl 		=> i2c_dat_ctrl,
			i2c_dat_in 			=> i2c_dat_in,
			i2c_dat_out 		=> i2c_dat_out,
			busy 				=> i2c_busy,
			cs 					=> i2c_cs,
			mode 				=> i2c_mode,
			slave_addr 			=> i2c_slave_addr,
			bytes_tx			=> i2c_bytes_tx,
			bytes_rx			=> i2c_bytes_rx,
			tx_data				=> i2c_tx_data,
			tx_data_valid		=> i2c_tx_data_valid,
			rx_data				=> i2c_rx_data,
			rx_data_valid		=> i2c_rx_data_valid,
			rx_data_en			=> i2c_rx_data_en,
			error 				=> i2c_error 					
		);

	-- sequential process
	process(clock, reset)
	begin
		-- "manually" connect i2c_reset_n with the inverse of the reset signal
		i2c_reset_n	<= not(reset);		
		if reset = '1' then
			moist_state				<= S_ADDR_SCAN;	
			moist_received_cnt		<= (others => '0');
			moist_valid				<= '0';
			moist_vals				<= (others => (others => '0'));
			
			moist_read_delay_cnt	<= (others => '0');
			moist_boot_delay_cnt	<= (others => '0');
			moisture_reg			<= (others => '0');
			temp_reg				<= (others => '0');
			cycle_cnt				<= (others => '0');
			
			scan_addr				<= (others => '0');
		elsif rising_edge(clock) then
			moist_state				<= moist_state_nxt;
			moist_received_cnt		<= moist_received_cnt_nxt;
			moist_valid				<= moist_valid_nxt;
			moist_vals				<= moist_vals_nxt;
			
			moist_read_delay_cnt	<= moist_read_delay_cnt_nxt;
			moist_boot_delay_cnt	<= moist_boot_delay_cnt_nxt;
			moisture_reg			<= moisture_reg_nxt;
			temp_reg				<= temp_reg_nxt;
			cycle_cnt				<= cycle_cnt_nxt;
			
			scan_addr				<= scan_addr_nxt;
		end if;
	end process;
	
	-- generate cycle pulse every second
	process(enabled, moist_busy, cycle_cnt)
	begin
		cycle_pulse		<= '0';
		cycle_cnt_nxt	<= cycle_cnt;
		if cycle_cnt = to_unsigned(CYCLE_TICKS - 1, cycle_cnt'length) then
			-- reset clock only if sensor isn't busy anymore and main entity enabled the reading process (enabled = '1')
			if enabled = '1' and moist_busy = '0' then
				-- set pulse to HIGH when the sensor isn't busy anymore
				cycle_pulse		<= '1';
				cycle_cnt_nxt	<= (others => '0');
			end if;
		else
			-- increment counter
			cycle_cnt_nxt	<= cycle_cnt + to_unsigned(1, cycle_cnt'length);
		end if;
	end process;
	
	process(cycle_pulse, i2c_error, i2c_busy, i2c_rx_data, i2c_rx_data_valid, moist_state, moist_received_cnt, moist_busy, moist_valid, moist_vals, moist_read_delay_cnt, moist_boot_delay_cnt, moisture_reg, temp_reg, scan_addr)
		-- variable is used to store the read value temporally
		-- it allows us to compare the value to certain constants more easily
		variable temp_value	: unsigned(23 downto 0) := (others => '0');
	begin	
		-- output values
		moisture		<= moisture_reg;
		temperature		<= temp_reg;
		address			<= scan_addr;
		
		-- hold value by default
		moist_state_nxt				<= moist_state;
		moist_received_cnt_nxt		<= moist_received_cnt;
		moist_valid_nxt				<= moist_valid;
		moist_vals_nxt				<= moist_vals;
		moist_read_delay_cnt_nxt	<= moist_read_delay_cnt;
		moist_boot_delay_cnt_nxt	<= moist_boot_delay_cnt;
		scan_addr_nxt				<= scan_addr;
		moisture_reg_nxt			<= moisture_reg;
		temp_reg_nxt				<= temp_reg;
	
		-- default assignments of `i2c_master` component
		i2c_cs 				<= '0';
		i2c_mode			<= "00";
		i2c_slave_addr 		<= MOIST_SLAVE_ADDR;
		i2c_bytes_rx		<= (others => '0');
		i2c_bytes_tx		<= (others => '0');
		i2c_rx_data_en		<= '0';
		i2c_tx_data_valid	<= '0';
		i2c_tx_data			<= (others => '0');

		-- always busy by default
		moist_busy <= '1';
		case moist_state is
			when S_ADDR_SCAN =>
				-- wait for cycle pulse to start the scan process
				moist_busy	<= i2c_busy;
				if cycle_pulse = '1' then
					-- start with the lowest possible i2c address
					scan_addr_nxt	<= SCAN_ADDR_START;
					moist_state_nxt	<= S_ADDR_REGISTER_BYTE0;
				end if;
			when S_ADDR_REGISTER_BYTE0 =>
				-- write "SET_ADDRESS" register address to tx fifo
				i2c_tx_data			<= MOIST_REG_SET_ADDR;
				i2c_tx_data_valid	<= '1';
				moist_state_nxt	<= S_ADDR_REGISTER_BYTE1;
			when S_ADDR_REGISTER_BYTE1 =>
				-- write new address (0x20) to tx fifo
				i2c_tx_data			<= "0" & MOIST_SLAVE_ADDR; -- add "0" because slave address has a bit width of 7 elements only
				i2c_tx_data_valid	<= '1';
				moist_state_nxt		<= S_ADDR_REGISTER_SEND;
			when S_ADDR_REGISTER_SEND =>
				if i2c_busy = '0' then
					-- start transmission
					i2c_cs			<= '1';
					i2c_mode		<= "01"; -- write only
					i2c_slave_addr	<= std_ulogic_vector(scan_addr); -- write to current slave address
					i2c_bytes_tx	<= to_unsigned(2, i2c_bytes_tx'length); -- write two bytes
					moist_state_nxt	<= S_ADDR_CHECK;
				end if;
			when S_ADDR_CHECK =>
				if i2c_busy = '0' then
					if i2c_error = '0' then
						-- no error occured because the slave acked, thus found correct address
						moist_state_nxt <= S_ADDR_RESET_BYTE0;
					else
						-- slave didn't acked, thus found incorrect address
						if scan_addr = SCAN_ADDR_END then
							-- reached end of possible i2c addresses, restart with lowest address
							moist_state_nxt	<= S_ADDR_SCAN;
						else
							-- increment address value to try the next possible
							scan_addr_nxt	<= scan_addr + to_unsigned(1, scan_addr'length);
							moist_state_nxt	<= S_ADDR_REGISTER_BYTE0;
						end if;
					end if;
				end if;
			when S_ADDR_RESET_BYTE0 =>
				-- write reset command to tx fifo
				i2c_tx_data			<= MOIST_REG_RESET;
				i2c_tx_data_valid	<= '1';
				moist_state_nxt		<= S_ADDR_RESET_SEND;
			when S_ADDR_RESET_SEND =>
				-- send reset command
				if i2c_busy = '0' then
					i2c_cs 			<= '1';
					i2c_mode		<= "01"; -- write only
					i2c_slave_addr	<= std_ulogic_vector(scan_addr);
					i2c_bytes_tx	<= to_unsigned(1, i2c_bytes_tx'length); -- write one byte
					moist_state_nxt	<= S_MST_BOOT_DELAY;
				end if;			
			when S_MST_BOOT_DELAY =>
				-- wait 1s to boot up moisture sensor
				if moist_boot_delay_cnt = to_unsigned(MOIST_BOOT_DELAY_TICKS - 1, moist_boot_delay_cnt'length) then
					moist_boot_delay_cnt_nxt	<= (others => '0');
					moist_state_nxt				<= S_MST_IDLE;
				else
					moist_boot_delay_cnt_nxt	<= moist_boot_delay_cnt + to_unsigned(1, moist_boot_delay_cnt'length);
				end if;
			when S_MST_IDLE =>
				-- wait for cycle_pulse
				moist_busy <= i2c_busy;
				if cycle_pulse = '1' then
					moist_state_nxt <= S_MST_REGISTER_BYTE0;
				end if;
			when S_MST_REGISTER_BYTE0 =>
				-- write register address to tx fifo
				i2c_tx_data 		<= MOIST_REG_MOISTURE;
				i2c_tx_data_valid	<= '1';
				moist_state_nxt		<= S_MST_REGISTER_SEND_BYTE0;
			when S_MST_REGISTER_SEND_BYTE0 =>
				if i2c_busy = '0' then
					-- start transmission
					i2c_cs			<= '1';
					i2c_mode		<= "01"; -- write only
					i2c_bytes_tx	<= to_unsigned(1, i2c_bytes_tx'length); -- write one byte	
					moist_state_nxt	<= S_MST_READ_DELAY;
				end if;
			when S_MST_READ_DELAY =>
				-- wait 20ms as recommended
				if moist_read_delay_cnt = to_unsigned(MOIST_READ_DELAY_TICKS - 1, moist_read_delay_cnt'length) then
					moist_read_delay_cnt_nxt	<= (others => '0');
					moist_state_nxt				<= S_MST_READ_START;
				else
					moist_read_delay_cnt_nxt	<= moist_read_delay_cnt + to_unsigned(1, moist_read_delay_cnt'length);
				end if;
			when S_MST_READ_START =>
				if i2c_busy = '0' then
					-- start transmission
					i2c_cs			<= '1';
					i2c_mode 		<= "00";	-- read only
					i2c_bytes_rx	<= to_unsigned(MOIST_VALUES_WIDTH, i2c_bytes_rx'length); -- read two bytes
					moist_state_nxt	<= S_MST_READ_WAIT;
				end if;
			when S_MST_READ_WAIT =>
				-- wait for i2c_master to finish communication
				if i2c_busy = '0' then
					moist_state_nxt	<= S_MST_READ_BYTES;
					moist_valid_nxt	<= '1'; -- valid by default
				end if;
			when S_MST_READ_BYTES =>
				if i2c_rx_data_valid = '1' then
					-- read two bytes from rx fifo
					i2c_rx_data_en <= '1';
					-- increment amount of received bytes
					moist_received_cnt_nxt <= moist_received_cnt + to_unsigned(1, moist_received_cnt'length);						
					if moist_received_cnt < to_unsigned(MOIST_VALUES_WIDTH, moist_received_cnt'length) then
						-- assign byte to vals register
						moist_vals_nxt(to_integer(moist_received_cnt)) <= i2c_rx_data;
					end if;
					if i2c_error = '1' then
						-- an error occured, data isn't valid anymore
						moist_valid_nxt	<= '0';
					end if;
				else
					-- rx fifo empty
					moist_state_nxt	<= S_MST_CHECK;
				end if;
			when S_MST_CHECK =>			
				-- clean up for next cycle, independent from `data_valid`
				moist_received_cnt_nxt	<= (others => '0');
				if moist_valid = '1' then
					-- data is valid
					temp_value := resize(unsigned(std_ulogic_vector'(moist_vals(0) & moist_vals(1))), temp_value'length); -- reverse byte order
					-- check if received value is in a reasonable range
					if temp_value < to_unsigned(400, temp_value'length) then
						-- too low, clip to 0%
						moisture_reg_nxt	<= (others => '0');
					elsif temp_value > to_unsigned(580, temp_value'length) then
						-- too damn high, clip to 99.9%
						moisture_reg_nxt	<= to_unsigned(999, moisture_reg'length);
					else
						-- in bounds, update moisture register
						moisture_reg_nxt <= resize(shift_right((temp_value - 400) * 45511, 13), moisture_reg'length);
					end if;
				end if;
				moist_state_nxt		<= S_TMP_REGISTER_BYTE0;
			when S_TMP_REGISTER_BYTE0 =>
				-- fill tx fifo with register address of temperature register
				i2c_tx_data 			<= MOIST_REG_TEMP;
				i2c_tx_data_valid		<= '1';
				moist_state_nxt			<= S_TMP_REGISTER_SEND_BYTE0;
			when S_TMP_REGISTER_SEND_BYTE0 =>
				if i2c_busy = '0' then
					i2c_cs			<= '1';
					i2c_mode		<= "01"; -- write only
					i2c_bytes_tx	<= to_unsigned(1, i2c_bytes_tx'length); -- write one byte
					moist_state_nxt	<= S_TMP_READ_DELAY;
				end if;
			when S_TMP_READ_DELAY	=>
				-- wait 20ms as recommended
				if moist_read_delay_cnt = to_unsigned(MOIST_READ_DELAY_TICKS - 1, moist_read_delay_cnt'length) then
					moist_read_delay_cnt_nxt	<= (others => '0');
					moist_state_nxt				<= S_TMP_READ_START;
				else
					moist_read_delay_cnt_nxt	<= moist_read_delay_cnt + to_unsigned(1, moist_read_delay_cnt'length);
				end if;
			when S_TMP_READ_START =>
				if i2c_busy = '0' then					
					i2c_cs			<= '1';
					i2c_mode 		<= "00"; -- read only
					i2c_bytes_rx	<= to_unsigned(MOIST_VALUES_WIDTH, i2c_bytes_rx'length); -- read two bytes
					moist_state_nxt	<= S_TMP_READ_WAIT;
				end if;
			when S_TMP_READ_WAIT =>
				-- wait for i2c_master to finish communication
				if i2c_busy = '0' then
					moist_state_nxt	<= S_TMP_READ_BYTES;
					moist_valid_nxt	<= '1'; -- valid by default
				end if;
			when S_TMP_READ_BYTES =>
				-- read bytes that are in rx fifo
				if i2c_rx_data_valid = '1' then
					-- get one byte
					i2c_rx_data_en <= '1';
					-- increment amount of received bytes
					moist_received_cnt_nxt <= moist_received_cnt + to_unsigned(1, moist_received_cnt'length);
					if moist_received_cnt < to_unsigned(MOIST_VALUES_WIDTH, moist_received_cnt'length) then
						-- assign byte to vals register
						moist_vals_nxt(to_integer(moist_received_cnt)) <= i2c_rx_data;				
					end if;
					if i2c_error = '1' then
						-- an error occured, data isn't valid anymore
						moist_valid_nxt	<= '0';
					end if;
				else
					-- rx fifo empty
					moist_state_nxt	<= S_TMP_CHECK;
				end if;
			when S_TMP_CHECK =>			
				-- clean up for next cycle, independent from `data_valid`
				moist_received_cnt_nxt	<= (others => '0');
				if moist_valid = '1' then
					-- data is valid
					temp_value := resize(unsigned(std_ulogic_vector'(moist_vals(0) & moist_vals(1))), temp_value'length);
					-- check if received value is in a reasonable range
					if temp_value > to_unsigned(150, temp_value'length) and temp_value < to_unsigned(350, temp_value'length) then
						-- update moisture register
						temp_reg_nxt <= unsigned(std_ulogic_vector'(moist_vals(0) & moist_vals(1)));
					end if;
				end if;
				-- go back to idle state
				moist_state_nxt		<= S_MST_IDLE;
		end case;

	end process;
	
end rtl;
