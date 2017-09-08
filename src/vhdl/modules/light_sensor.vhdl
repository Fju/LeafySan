----------------------------------------------------------------------
-- Project		:	LeafySan
-- Module		:	Light Sensor Module
-- Authors		:	Florian Winkler
-- Lust update	:	01.09.2017
-- Description	:	Reads a digital light sensor by Grove through an I2C bus
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity light_sensor is
	generic (
		CYCLE_TICKS			: natural	:= 50000000 -- 1s
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
		enabled				: in  std_ulogic;
		value				: out unsigned(15 downto 0)
	);
end light_sensor;

architecture rtl of light_sensor is

	component calc_lux is
		port(
			clock		: in  std_ulogic;
			reset		: in  std_ulogic;
			channel0	: in  unsigned(15 downto 0);
			channel1	: in  unsigned(15 downto 0);
			start		: in  std_ulogic;
			busy		: out std_ulogic;
			lux			: out unsigned(15 downto 0)
		);
	end component calc_lux;

	component i2c_master is
		generic (
			GV_SYS_CLOCK_RATE	: natural := 50000000;
			GV_I2C_CLOCK_RATE	: natural := 400000;
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
	

	type light_state_t is (S_LT_IDLE, S_LT_POWER_ON_BYTE0, S_LT_POWER_ON_BYTE1, S_LT_POWER_ON_SEND, S_LT_BOOT_DELAY,
							S_LT_GAIN_BYTE0, S_LT_GAIN_BYTE1, S_LT_GAIN_SEND, S_LT_READ_DELAY, S_LT_REGISTER_BYTE0,
							S_LT_REGISTER_SEND_BYTE0, S_LT_WAIT_READ, S_LT_READ_START, S_LT_READ_BYTE0, S_LT_CHECK, 
							S_LT_CALC_LUX, S_LT_POWER_OFF_BYTE0, S_LT_POWER_OFF_BYTE1, S_LT_POWER_OFF_SEND);
	signal light_state, light_state_nxt	: light_state_t;
	
	
	constant LIGHT_SLAVE_ADDR		: std_ulogic_vector(6 downto 0) := "0101001"; -- 0x29
	
	-- light register addresses
	constant LIGHT_REG_CONTROL 		: std_ulogic_vector(7 downto 0) := "10000000"; -- 0x80
	constant LIGHT_REG_TIMING		: std_ulogic_vector(7 downto 0) := "10000001"; -- 0x81
	constant LIGHT_REG_INTERRUPT	: std_ulogic_vector(7 downto 0) := "10000110"; -- 0x86
	constant LIGHT_REG_CHANNEL0L	: std_ulogic_vector(7 downto 0) := "10001100"; -- 0x8C
	constant LIGHT_REG_CHANNEL0H	: std_ulogic_vector(7 downto 0) := "10001101"; -- 0x8D
	constant LIGHT_REG_CHANNEL1L	: std_ulogic_vector(7 downto 0) := "10001110"; -- 0x8E
	constant LIGHT_REG_CHANNEL1H	: std_ulogic_vector(7 downto 0) := "10001111"; -- 0x8F
	
	-- contains channel addresses from whom we will read
	type light_ch_reg_array is array (natural range <>) of std_ulogic_vector(7 downto 0);
	constant LIGHT_CH_REG_LENGTH	: natural := 4;
	constant LIGHT_CH_REGS : light_ch_reg_array(0 to LIGHT_CH_REG_LENGTH - 1) := (
		LIGHT_REG_CHANNEL0L, LIGHT_REG_CHANNEL0H, LIGHT_REG_CHANNEL1L, LIGHT_REG_CHANNEL1H
	);
	signal light_ch_reg_cnt, light_ch_reg_cnt_nxt	: unsigned(to_log2(LIGHT_CH_REG_LENGTH + 1) - 1 downto 0);
	signal light_ch_valid, light_ch_valid_nxt		: std_ulogic;	
	-- register to save received channel values
	type light_ch_vals_array is array (natural range <>) of std_ulogic_vector(7 downto 0);
	signal light_ch_vals, light_ch_vals_nxt : light_ch_vals_array(0 to LIGHT_CH_REG_LENGTH - 1);	
	signal light_busy : std_ulogic;
	
	constant LIGHT_READ_DELAY_TICKS		: natural := 40000000;	-- 800ms
	constant LIGHT_BOOT_DELAY_TICKS		: natural := 20000000;	-- 400ms
	
	signal light_read_delay_cnt, light_read_delay_cnt_nxt	: unsigned(to_log2(LIGHT_READ_DELAY_TICKS) - 1 downto 0);
	signal light_boot_delay_cnt, light_boot_delay_cnt_nxt	: unsigned(to_log2(LIGHT_BOOT_DELAY_TICKS) - 1 downto 0);
	
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
	
	-- signals of `calc_lux` component
	signal calc_lux_start		: std_ulogic;
	signal calc_lux_busy		: std_ulogic;
	signal calc_lux_value		: unsigned(15 downto 0);
	signal calc_lux_channel0	: unsigned(15 downto 0);
	signal calc_lux_channel1	: unsigned(15 downto 0);
	
	signal brightness_reg, brightness_reg_nxt	: unsigned(15 downto 0);
	
	signal cycle_cnt, cycle_cnt_nxt	: unsigned(to_log2(CYCLE_TICKS) - 1 downto 0);
	signal cycle_pulse				: std_ulogic;
begin
	-- configure `calc_lux` signal assignments
	calc_lux_inst : calc_lux
		port map (
			clock		=> clock,
			reset		=> reset,
			start		=> calc_lux_start,
			busy		=> calc_lux_busy,
			lux			=> calc_lux_value,
			channel0	=> calc_lux_channel0,
			channel1	=> calc_lux_channel1
		);

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
		i2c_reset_n	<= not(reset);		
		if reset = '1' then
			light_state				<= S_LT_IDLE;
			light_ch_reg_cnt		<= (others => '0');
			light_ch_valid			<= '0';
			light_ch_vals			<= (others => (others => '0'));		
			light_read_delay_cnt	<= (others => '0');	
			light_boot_delay_cnt	<= (others => '0');			
			brightness_reg			<= (others => '0');
			cycle_cnt				<= (others => '0');
		elsif rising_edge(clock) then
			light_state				<= light_state_nxt;
			light_ch_reg_cnt		<= light_ch_reg_cnt_nxt;
			light_ch_valid			<= light_ch_valid_nxt;
			light_ch_vals			<= light_ch_vals_nxt;
			light_read_delay_cnt	<= light_read_delay_cnt_nxt;	
			light_boot_delay_cnt	<= light_boot_delay_cnt_nxt;			
			brightness_reg			<= brightness_reg_nxt;
			cycle_cnt				<= cycle_cnt_nxt;
		end if;
	end process;
	
	process(enabled, light_busy, cycle_cnt)
	begin
		cycle_pulse		<= '0';
		cycle_cnt_nxt	<= cycle_cnt;
		if cycle_cnt = to_unsigned(CYCLE_TICKS - 1, cycle_cnt'length) then
			-- reset clock only if sensor isn't busy anymore and main entity enabled the reading process (enabled = '1')
			if enabled = '1' and light_busy = '0' then
				-- set pulse to HIGH when the sensor isn't busy anymore
				cycle_pulse		<= '1';
				cycle_cnt_nxt	<= (others => '0');
			end if;
		else
			-- increment counter
			cycle_cnt_nxt	<= cycle_cnt + to_unsigned(1, cycle_cnt'length);
		end if;
	end process;
	
	process(enabled, cycle_pulse, i2c_error, i2c_busy, i2c_rx_data, i2c_rx_data_valid, calc_lux_busy, calc_lux_value, light_busy, light_state, light_ch_reg_cnt, light_ch_valid, light_ch_vals, light_read_delay_cnt, light_boot_delay_cnt, brightness_reg)
	begin
		-- output values
		value <= brightness_reg;
		
		-- hold value by default
		light_state_nxt				<= light_state;
		light_ch_reg_cnt_nxt		<= light_ch_reg_cnt;
		light_ch_valid_nxt			<= light_ch_valid;
		light_ch_vals_nxt			<= light_ch_vals;
		light_read_delay_cnt_nxt	<= light_read_delay_cnt;
		light_boot_delay_cnt_nxt	<= light_boot_delay_cnt;		
		brightness_reg_nxt			<= brightness_reg;
	
		-- default assignments of `i2c_master` component
		i2c_cs 				<= '0';
		i2c_slave_addr 		<= LIGHT_SLAVE_ADDR;
		i2c_mode			<= "00";
		i2c_bytes_rx		<= (others => '0');
		i2c_bytes_tx		<= (others => '0');
		i2c_rx_data_en		<= '0';
		i2c_tx_data_valid	<= '0';
		i2c_tx_data			<= (others => '0');
		
		-- default assignments of `calc_lux` component
		calc_lux_channel0	<= (others => '0');
		calc_lux_channel1	<= (others => '0');
		calc_lux_start		<= '0';
		
		-- always busy by default
		light_busy	<= '1';
		case light_state is
			when S_LT_IDLE =>
				-- waiting for cycle_pulse
				light_busy <= i2c_busy;
				if cycle_pulse = '1' then
					light_state_nxt 	<= S_LT_POWER_ON_BYTE0;
					light_ch_valid_nxt	<= '1';
				end if;
			when S_LT_POWER_ON_BYTE0 =>
				-- write "CONTROL" register address to tx fifo
				i2c_tx_data			<= LIGHT_REG_CONTROL;
				i2c_tx_data_valid	<= '1';
				light_state_nxt	<= S_LT_POWER_ON_BYTE1;						
			when S_LT_POWER_ON_BYTE1 =>
				-- write "POWER_ON" command to tx fifo
				i2c_tx_data			<= "00000011"; -- 0x03
				i2c_tx_data_valid	<= '1';
				light_state_nxt		<= S_LT_POWER_ON_SEND;
			when S_LT_POWER_ON_SEND =>
				if i2c_busy = '0' then
					i2c_cs			<= '1';
					i2c_mode		<= "01"; -- write only
					i2c_bytes_tx	<= to_unsigned(2, i2c_bytes_tx'length); -- write two bytes
					light_state_nxt	<= S_LT_BOOT_DELAY;
				end if;
			when S_LT_BOOT_DELAY =>
				-- delay 400ms, wait for light sensor to boot up
				if i2c_busy = '0' then							
					if light_boot_delay_cnt = to_unsigned(LIGHT_BOOT_DELAY_TICKS - 1, light_boot_delay_cnt'length) then
						light_state_nxt				<= S_LT_GAIN_BYTE0;
						light_boot_delay_cnt_nxt	<= (others => '0');
					else
						light_boot_delay_cnt_nxt	<= light_boot_delay_cnt + to_unsigned(1, light_boot_delay_cnt'length);
					end if;
				end if;
			when S_LT_GAIN_BYTE0 =>
				-- write "GAIN" register address to tx fifo
				i2c_tx_data			<= LIGHT_REG_TIMING;
				i2c_tx_data_valid	<= '1';
				light_state_nxt		<= S_LT_GAIN_BYTE1;						
			when S_LT_GAIN_BYTE1 =>
				-- write gain and integration time settings to tx fifo
				i2c_tx_data			<= "00010001"; -- 0x11: high gain (16x), integration time = 101ms
				i2c_tx_data_valid	<= '1';
				light_state_nxt		<= S_LT_GAIN_SEND;
			when S_LT_GAIN_SEND =>				
				if i2c_busy = '0' then
					i2c_cs			<= '1';
					i2c_mode		<= "01"; -- write only
					i2c_bytes_tx	<= to_unsigned(2, i2c_bytes_tx'length); -- write two bytes
					light_state_nxt	<= S_LT_READ_DELAY;
				end if;
			when S_LT_READ_DELAY =>
				-- delay 800ms, wait for integrety of channel values
				if i2c_busy = '0' then							
					if light_read_delay_cnt = to_unsigned(LIGHT_READ_DELAY_TICKS - 1, light_read_delay_cnt'length) then
						light_state_nxt				<= S_LT_REGISTER_BYTE0;
						light_read_delay_cnt_nxt	<= (others => '0');
					else
						light_read_delay_cnt_nxt	<= light_read_delay_cnt + to_unsigned(1, light_read_delay_cnt'length);
					end if;
				end if;		
			when S_LT_REGISTER_BYTE0 =>
				-- write register address of current channel to tx fifo
				i2c_tx_data 		<= LIGHT_CH_REGS(to_integer(light_ch_reg_cnt));
				i2c_tx_data_valid 	<= '1';
				light_state_nxt		<= S_LT_REGISTER_SEND_BYTE0;
			when S_LT_REGISTER_SEND_BYTE0 =>
				if i2c_busy = '0' then
					i2c_cs			<= '1';
					i2c_mode		<= "01"; -- write only
					i2c_bytes_tx	<= to_unsigned(1, i2c_bytes_tx'length); -- write one byte			
					light_state_nxt	<= S_LT_READ_START;
				end if;
			when S_LT_READ_START =>
				if i2c_busy = '0' then
					i2c_cs			<= '1';
					i2c_mode		<= "00"; -- read only
					i2c_bytes_rx	<= to_unsigned(1, i2c_bytes_rx'length); -- receive one byte
					light_state_nxt	<= S_LT_WAIT_READ;						
				end if;
			when S_LT_WAIT_READ =>
				-- wait for rx fifo to be filled
				if i2c_busy = '0' then
					light_state_nxt	<= S_LT_READ_BYTE0;
				end if;
			when S_LT_READ_BYTE0 =>
				if i2c_error = '1' then
					-- an error occured, data isn't valid
					light_ch_valid_nxt <= '0';
				end if;
				if i2c_rx_data_valid = '1' then
					-- read one byte from rx fifo
					i2c_rx_data_en	<= '1';
					light_ch_vals_nxt(to_integer(light_ch_reg_cnt)) <= i2c_rx_data;						
				else
					-- rx fifo empty
					if light_ch_reg_cnt = to_unsigned(LIGHT_CH_REG_LENGTH - 1, light_ch_reg_cnt'length) then
						-- received everything
						light_state_nxt			<= S_LT_CHECK;
					else
						-- write/read next channel register
						light_state_nxt			<= S_LT_REGISTER_BYTE0;
						light_ch_reg_cnt_nxt	<= light_ch_reg_cnt + to_unsigned(1, light_ch_reg_cnt'length);
					end if;
				end if;
			when S_LT_CHECK =>				
				-- clean up for next cycle, independent from valid data
				light_ch_reg_cnt_nxt	<= (others => '0');						
				if light_ch_valid = '1' then							
					calc_lux_start		<= '1'; -- start calculation
					calc_lux_channel0 	<= unsigned(std_ulogic_vector'(light_ch_vals(1) & light_ch_vals(0)));
					calc_lux_channel1 	<= unsigned(std_ulogic_vector'(light_ch_vals(3) & light_ch_vals(2)));							
					
					light_state_nxt	<= S_LT_CALC_LUX;
				else
					-- invalid data, skip to power off
					light_state_nxt	<= S_LT_POWER_OFF_BYTE0;
				end if;
			when S_LT_CALC_LUX =>
				calc_lux_start	<= '1'; -- keep high for ack mechanism
				if calc_lux_busy = '0' then
					calc_lux_start		<= '0'; -- ack
					brightness_reg_nxt	<= calc_lux_value;
					light_state_nxt		<= S_LT_POWER_OFF_BYTE0;
				end if;
			when S_LT_POWER_OFF_BYTE0 =>
				-- write power off command to tx fifo
				i2c_tx_data			<= LIGHT_REG_CONTROL;
				i2c_tx_data_valid	<= '1';
				light_state_nxt		<= S_LT_POWER_OFF_BYTE1;
			when S_LT_POWER_OFF_BYTE1 =>
				-- write power off command to tx fifo (part 2)
				i2c_tx_data			<= "00000000";
				i2c_tx_data_valid	<= '1';
				light_state_nxt		<= S_LT_POWER_OFF_SEND;
			when S_LT_POWER_OFF_SEND =>
				if i2c_busy = '0' then
					-- start transmission
					i2c_cs 			<= '1';
					i2c_mode		<= "01"; -- write only
					i2c_bytes_tx	<= to_unsigned(2, i2c_bytes_tx'length);
					light_state_nxt	<= S_LT_IDLE;
				end if;
		end case;		
	end process;
	
end rtl;
