-------------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : WM8731 Audio Codec Configurator
-- Author 		: Jan Dürre
-- Last update  : 18.08.2014
-- Description 	: First this module pre-configures the audio-codec 
--				  according to an init-config, second a simple 
--				  interface is provided to write the registers of
--				  the audio-codec.
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity wm8731_configurator is
	port(
		clock					: in 	std_ulogic;
		reset_n					: in 	std_ulogic;
		-- simple interface to write configurations to wm8731
		busy 					: out	std_ulogic;
		reg_addr 				: in 	std_ulogic_vector(6 downto 0);
		reg_data 				: in 	std_ulogic_vector(8 downto 0);
		valid 					: in 	std_ulogic;
		-- interface to i2c master
		i2c_busy 				: in	std_ulogic;
		i2c_cs 					: out 	std_ulogic;
		i2c_mode 				: out 	std_ulogic_vector(1 downto 0);
		i2c_slave_addr 			: out 	std_ulogic_vector(6 downto 0);
		i2c_bytes_tx			: out 	unsigned(4 downto 0);
		i2c_bytes_rx			: out 	unsigned(4 downto 0);
		i2c_tx_data				: out 	std_ulogic_vector(7 downto 0);
		i2c_tx_data_valid		: out 	std_ulogic;
		i2c_rx_data				: in	std_ulogic_vector(7 downto 0);
		i2c_rx_data_valid		: in 	std_ulogic;
		i2c_rx_data_en			: out 	std_ulogic;
		i2c_error 				: in 	std_ulogic
    );
end wm8731_configurator;

architecture rtl of wm8731_configurator is

	-- i2c slave address of wm8731
	constant WM8731_SLAVE_ADDR : std_ulogic_vector(6 downto 0) := "0011010";

	-- control fsm
	type state_t is (S_BOOT, S_INIT_BYTE0, S_INIT_BYTE1, S_INIT_WAIT, S_IDLE, S_WR_BYTE0, S_WR_BYTE1, S_WAIT);
	signal state, state_nxt : state_t;
	
	-- init config
	type wm8731_settings_t is record
		addr	: std_ulogic_vector(6 downto 0);
		data	: std_ulogic_vector(8 downto 0);
	end record;
	type wm8731_settings_array is array (natural range <>) of wm8731_settings_t;
	
	constant CV_INIT_CONFIG_SIZE : natural := 11;
	constant WM8731_INIT_SETTINGS : wm8731_settings_array(0 to CV_INIT_CONFIG_SIZE-1) := (
			-- ADDR		 DATA
			("0000000", "000010111"),	--  0: left line in
			("0000001", "000010111"),	--  1: right line in
			("0000010", "001111110"),	--  2: left headphone out
			("0000011", "001111110"),	--  3: right headphone out
			("0000100", "000010000"),	--  4: analog audio path control
			("0000101", "000000000"),	--  5: digital audio path control
			("0000110", "000000000"),	--  6: power down control
			("0000111", "001000010"),	--  7: digital audio interface format
			("0001000", "000100011"),	--  8: sampling control
			("0001001", "000000001"),	--  9: active control
			("0001010", "000000000")	-- 10: reset register
		);
	-- counter for initial configuration
	signal init_cnt, init_cnt_nxt 	: unsigned(to_log2(CV_INIT_CONFIG_SIZE)-1 downto 0);
		
	-- counter to await the boot up of the audio-codec
	constant CV_WM8731_BOOT_TIME 	: natural := 1024;
	signal wait_cnt, wait_cnt_nxt 	: unsigned(to_log2(CV_WM8731_BOOT_TIME)-1 downto 0);
	
	-- register to hold configure request
	signal wm8731_cfg, wm8731_cfg_nxt : wm8731_settings_t;

begin
	
	-- ff
	process (clock, reset_n)
	begin
		if reset_n = '0' then			
			state		<= S_BOOT;
			init_cnt 	<= (others => '0');
			wait_cnt 	<= (others => '0');
			wm8731_cfg 	<= (others => (others => '0'));
		elsif rising_edge(clock) then
			state		<= state_nxt;
			init_cnt 	<= init_cnt_nxt;
			wait_cnt 	<= wait_cnt_nxt;
			wm8731_cfg 	<= wm8731_cfg_nxt;
		end if;
	end process;


	-- logic: control fsm
	process (state, init_cnt, wait_cnt, wm8731_cfg, reg_addr, reg_data, valid, i2c_busy, i2c_rx_data, i2c_rx_data_valid, i2c_error)
	begin
		-- hold registers
		state_nxt		<= state;
		init_cnt_nxt 	<= init_cnt;
		wait_cnt_nxt 	<= wait_cnt;
		wm8731_cfg_nxt	<= wm8731_cfg;
		
		-- interface signals
		busy 					<= '1';	-- always busy, when not stated other
		
		-- i2c signals
		i2c_cs 					<= '0';
		i2c_mode 				<= "01"; 								-- always write only
		i2c_slave_addr 			<= WM8731_SLAVE_ADDR; 					-- always same slave
		i2c_bytes_tx			<= to_unsigned(2, i2c_bytes_tx'length);	-- always 2 bytes
		
		-- rx is never used: wm8731 does not support read
		i2c_bytes_rx			<= (others => '0');
		i2c_rx_data_en			<= '0';
		
		i2c_tx_data				<= (others => '0');
		i2c_tx_data_valid		<= '0';

		-- fsm
		case state is
			when S_BOOT =>
				-- wait for counter to reach boot-time
				if wait_cnt = CV_WM8731_BOOT_TIME-1 then
					wait_cnt_nxt <= wait_cnt + 1;
				else
					state_nxt <= S_INIT_BYTE0;
				end if;
				
			when S_INIT_BYTE0 =>
				-- write (according to init_cnt) first byte of active init-configuration-register to i2c-master
				i2c_tx_data 		<= WM8731_INIT_SETTINGS(to_integer(init_cnt)).addr & WM8731_INIT_SETTINGS(to_integer(init_cnt)).data(8);
				i2c_tx_data_valid 	<= '1';
				
				state_nxt 			<= S_INIT_BYTE1;
			
			when S_INIT_BYTE1 =>
				-- write (according to init_cnt) second byte of active init-configuration-register to i2c-master
				i2c_tx_data 		<= WM8731_INIT_SETTINGS(to_integer(init_cnt)).data(7 downto 0);
				i2c_tx_data_valid 	<= '1';
				-- and start i2c transfer (other required signals are constant (i2c_mode, i2c_slave_addr, i2c_bytes_tx))
				i2c_cs 				<= '1';
				
				state_nxt 			<= S_INIT_WAIT;
			
			when S_INIT_WAIT =>
				-- wait for busy signal to go down
				if i2c_busy = '0' then
					-- if last init-configuration-register was written
					if init_cnt = CV_INIT_CONFIG_SIZE - 1 then
						-- go to idle
						state_nxt 		<= S_IDLE;
					else
						-- return to writing init-configuration-registers
						init_cnt_nxt 	<= init_cnt + 1;
						state_nxt 		<= S_INIT_BYTE0;
					end if;
				end if;
			
			when S_IDLE =>
				-- not busy, accessible for register write requests
				busy <= '0';
				-- incoming write request
				if valid = '1' then
					-- save register addr and data
					wm8731_cfg_nxt.addr <= reg_addr;
					wm8731_cfg_nxt.data <= reg_data;
					-- start with byte 0
					state_nxt <= S_WR_BYTE0;
				end if;
				
			when S_WR_BYTE0 =>
				-- write first byte to i2c-master
				i2c_tx_data 		<= wm8731_cfg.addr & wm8731_cfg.data(8);
				i2c_tx_data_valid 	<= '1';
				-- continue with second byte
				state_nxt 			<= S_WR_BYTE1;
			
			when S_WR_BYTE1 =>
				-- write second byte to i2c-master
				i2c_tx_data 		<= wm8731_cfg.data(7 downto 0);
				i2c_tx_data_valid 	<= '1';
				-- and start i2c transfer (other required signals are constant (i2c_mode, i2c_slave_addr, i2c_bytes_tx))
				i2c_cs 				<= '1';
				
				state_nxt 			<= S_WAIT;
			
			when S_WAIT =>
				-- wait for i2c-master to finish transfer
				if i2c_busy = '0' then
					state_nxt 	<= S_IDLE;
				end if;
			
		end case;
		
	end process;

end rtl;

