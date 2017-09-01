-----------------------------------------------------------------------------------------
-- Project      : 	Invent a Chip
-- Module       : 	Audio Interface
-- Author 		: 	Jan Dürre
-- Last update  : 	18.04.2016
-- Description	: 	-
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity audio is
	port (
		-- global
		clock 			: in    std_ulogic;
		clock_audio 	: in 	std_ulogic;
		reset_n  		: in    std_ulogic;
		-- bus interface
		iobus_cs		: in  	std_ulogic;
		iobus_wr		: in  	std_ulogic;
		iobus_addr		: in  	std_ulogic_vector(CW_ADDR_AUDIO-1 downto 0);
		iobus_din		: in  	std_ulogic_vector(CW_DATA_AUDIO-1 downto 0);
		iobus_dout		: out 	std_ulogic_vector(CW_DATA_AUDIO-1 downto 0);
		-- IRQ handling
		iobus_irq_left	: out 	std_ulogic;
		iobus_irq_right	: out 	std_ulogic;
		iobus_ack_left	: in  	std_ulogic;
		iobus_ack_right	: in  	std_ulogic;
		-- connections to audio codec
		aud_xclk		: out 	std_ulogic;
		aud_bclk     	: in    std_ulogic;
		aud_adc_lrck 	: in    std_ulogic;
		aud_adc_dat  	: in    std_ulogic;
		aud_dac_lrck 	: in    std_ulogic;
		aud_dac_dat  	: out   std_ulogic;
		i2c_sdat     	: inout std_logic;
		i2c_sclk     	: inout std_logic
    );
end entity audio;

architecture rtl of audio is

	-- internal register for audiodata
	signal audio_left_in 			: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_left_in_nxt		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_right_in 			: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_right_in_nxt		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_left_out 			: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_left_out_nxt		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_left_out_buf		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_left_out_buf_nxt	: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_right_out 			: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_right_out_nxt		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_right_out_buf 		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_right_out_buf_nxt	: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	
	-- counter for retrieval of serial audio data
	signal counter_left 		: unsigned(to_log2(CW_AUDIO_SAMPLE)-1 downto 0);
	signal counter_left_nxt 	: unsigned(to_log2(CW_AUDIO_SAMPLE)-1 downto 0);
	signal counter_right 		: unsigned(to_log2(CW_AUDIO_SAMPLE)-1 downto 0);
	signal counter_right_nxt 	: unsigned(to_log2(CW_AUDIO_SAMPLE)-1 downto 0);
	
	-- register for interrupt signals
	signal irq_left, irq_left_nxt 	: std_ulogic;
	signal irq_right, irq_right_nxt : std_ulogic;
	
	-- register for configuration purpose
	signal config 			: std_ulogic_vector(7 downto 0);	--bit 0: select mic-in; bit 1: activate mic-boost
	signal config_nxt 		: std_ulogic_vector(7 downto 0);
	signal config_old 		: std_ulogic_vector(7 downto 0);
	signal config_old_nxt 	: std_ulogic_vector(7 downto 0);
	
	signal last_bit_left 		: std_ulogic;
	signal last_bit_left_nxt 	: std_ulogic;
	signal last_bit_right 		: std_ulogic;
	signal last_bit_right_nxt 	: std_ulogic;

	-- connection signals to i2c master
	signal i2c_busy 				: std_ulogic;
	signal i2c_cs 					: std_ulogic;
	signal i2c_mode 				: std_ulogic_vector(1 downto 0);
	signal i2c_slave_addr 			: std_ulogic_vector(6 downto 0);
	signal i2c_bytes_tx				: unsigned(4 downto 0);
	signal i2c_bytes_rx				: unsigned(4 downto 0);
	signal i2c_tx_data				: std_ulogic_vector(7 downto 0);
	signal i2c_tx_data_valid		: std_ulogic;
	signal i2c_rx_data				: std_ulogic_vector(7 downto 0);
	signal i2c_rx_data_valid		: std_ulogic;
	signal i2c_rx_data_en			: std_ulogic;
	signal i2c_error 				: std_ulogic;
	
	component i2c_master is
		generic (
			GV_SYS_CLOCK_RATE		: natural := 50000000;
			GV_I2C_CLOCK_RATE 		: natural := 400000; 	-- standard mode: (100000) 100 kHz; fast mode: 400000 Hz (400 kHz)
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
			mode 					: in 	std_ulogic_vector(1 downto 0);	-- 00: only read; 01: only write; 10: first read, second write; 11: first write, second read
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
	end component i2c_master;
	
	-- connection signals to acodec configurator
	signal configurator_busy 			: std_ulogic;
	signal configurator_reg_addr		: std_ulogic_vector(6 downto 0);
	signal configurator_reg_data		: std_ulogic_vector(8 downto 0);
	signal configurator_valid 			: std_ulogic;
	
	component wm8731_configurator is
		port (
			clock			: in 	std_ulogic;
			reset_n			: in 	std_ulogic;
			-- simple interface to write configurations to 
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
	end component wm8731_configurator;

	-- connection signals for acodec_interface
	signal ain_left_sync 	: std_ulogic;
	signal ain_left_data 	: std_ulogic;
	signal ain_right_sync 	: std_ulogic;
	signal ain_right_data 	: std_ulogic;
	signal aout_left_sync 	: std_ulogic;
	signal aout_left_data 	: std_ulogic;
	signal aout_right_sync 	: std_ulogic;
	signal aout_right_data 	: std_ulogic;
	
	component i2s_slave is
		port (
			-- general signals
			clock			: in  std_ulogic;
			reset_n			: in  std_ulogic;
			-- input signals from adc
			aud_bclk		: in  std_ulogic;
			aud_adc_lrck	: in  std_ulogic;
			aud_adc_dat		: in  std_ulogic;
			-- output signals to dac
			aud_dac_lrck	: in  std_ulogic;
			aud_dac_dat		: out std_ulogic;
			-- audio sample inputs
			ain_left_sync	: out std_ulogic;
			ain_left_data	: out std_ulogic;
			ain_right_sync	: out std_ulogic;
			ain_right_data	: out std_ulogic;
			-- audio sample outputs
			aout_left_sync	: in  std_ulogic;
			aout_left_data	: in  std_ulogic;
			aout_right_sync : in  std_ulogic;
			aout_right_data : in  std_ulogic
		);
	end component i2s_slave;

begin

	aud_xclk 	<= clock_audio;
	
	-- i2c master
	i2c_master_inst : i2c_master
		generic map (
			GV_SYS_CLOCK_RATE		=> CV_SYS_CLOCK_RATE,
			GV_I2C_CLOCK_RATE 		=> 400000,
			GW_SLAVE_ADDR 			=> 7,
			GV_MAX_BYTES 			=> 16,
			GB_USE_INOUT 			=> true,
			GB_TIMEOUT 				=> false
		)
		port map (
			clock 					=> clock,
			reset_n					=> reset_n,
			i2c_clk 				=> i2c_sclk,
			i2c_clk_ctrl 			=> open,
			i2c_clk_in 				=> '0',
			i2c_clk_out 			=> open,
			i2c_dat 				=> i2c_sdat,
			i2c_dat_ctrl 			=> open,
			i2c_dat_in 				=> '0',
			i2c_dat_out 			=> open,
			busy 					=> i2c_busy,
			cs 						=> i2c_cs,
			mode 					=> i2c_mode,
			slave_addr 				=> i2c_slave_addr,
			bytes_tx				=> i2c_bytes_tx,
			bytes_rx				=> i2c_bytes_rx,
			tx_data					=> i2c_tx_data,
			tx_data_valid			=> i2c_tx_data_valid,
			rx_data					=> i2c_rx_data,
			rx_data_valid			=> i2c_rx_data_valid,
			rx_data_en				=> i2c_rx_data_en,
			error 					=> i2c_error 					
		);

	-- wm8731_configurator
	acodec_configurator_inst : wm8731_configurator
		port map (
			clock					=> clock,
			reset_n					=> reset_n,
			busy 					=> configurator_busy,
			reg_addr 				=> configurator_reg_addr,
			reg_data 				=> configurator_reg_data,
			valid 					=> configurator_valid,
			i2c_busy 				=> i2c_busy,
			i2c_cs 					=> i2c_cs,
			i2c_mode 				=> i2c_mode,
			i2c_slave_addr 			=> i2c_slave_addr,
			i2c_bytes_tx			=> i2c_bytes_tx,
			i2c_bytes_rx			=> i2c_bytes_rx,
			i2c_tx_data				=> i2c_tx_data,
			i2c_tx_data_valid		=> i2c_tx_data_valid,
			i2c_rx_data				=> i2c_rx_data,
			i2c_rx_data_valid		=> i2c_rx_data_valid,
			i2c_rx_data_en			=> i2c_rx_data_en,
			i2c_error 				=> i2c_error 				
		);


	-- i2s_slave
	i2s_slave_inst : i2s_slave
		port map (
			clock			=> clock,
			reset_n			=> reset_n,
			aud_bclk 		=> aud_bclk,
			aud_adc_lrck	=> aud_adc_lrck,
			aud_adc_dat		=> aud_adc_dat,
			aud_dac_lrck	=> aud_dac_lrck,
			aud_dac_dat		=> aud_dac_dat,
			ain_left_sync	=> ain_left_sync,
			ain_left_data	=> ain_left_data,
			ain_right_sync	=> ain_right_sync,
			ain_right_data	=> ain_right_data,
			aout_left_sync	=> aout_left_sync,
			aout_left_data	=> aout_left_data,
			aout_right_sync => aout_right_sync,
			aout_right_data => aout_right_data);
			
	-- register
	process(clock, reset_n)
	begin
		if reset_n = '0' then
			audio_left_in 		<= (others => '0');
			audio_right_in 		<= (others => '0');
			audio_left_out 		<= (others => '0');
			audio_left_out_buf	<= (others => '0');
			audio_right_out 	<= (others => '0');
			audio_right_out_buf	<= (others => '0');
			counter_left		<= (others => '0');
			counter_right		<= (others => '0');
			irq_left			<= '0';
			irq_right			<= '0';
			config 				<= (others => '0');
			config_old 			<= (others => '0');
			last_bit_left 		<= '0';
			last_bit_right 		<= '0';
		elsif rising_edge(clock) then 
			audio_left_in 		<= audio_left_in_nxt;
			audio_right_in 		<= audio_right_in_nxt;
			audio_left_out 		<= audio_left_out_nxt;
			audio_left_out_buf	<= audio_left_out_buf_nxt;
			audio_right_out 	<= audio_right_out_nxt;
			audio_right_out_buf	<= audio_right_out_buf_nxt;
			counter_left		<= counter_left_nxt;
			counter_right		<= counter_right_nxt;
			irq_left			<= irq_left_nxt;
			irq_right			<= irq_right_nxt;
			config 				<= config_nxt;
			config_old 			<= config_old_nxt;
			last_bit_left 		<= last_bit_left_nxt;
			last_bit_right 		<= last_bit_right_nxt;
		end if;
	end process;
	
	
	-- handling of incoming audio data --
	iobus_irq_left 	<= irq_left;
	iobus_irq_right <= irq_right;

	-- counter
	counter_left_nxt 	<= 	to_unsigned(CW_AUDIO_SAMPLE-1, counter_left'length) 		when ain_left_sync = '1' 									else
							counter_left - to_unsigned(1, counter_left'length)			when counter_left > to_unsigned(0, counter_left'length)		else
							counter_left;
	counter_right_nxt 	<= 	to_unsigned(CW_AUDIO_SAMPLE-1, counter_right'length) 		when ain_right_sync = '1' 									else
							counter_right - to_unsigned(1, counter_right'length)		when counter_right > to_unsigned(0, counter_right'length)	else
							counter_right;
							
	last_bit_left_nxt 	<= 	'1' when counter_left = to_unsigned(1, counter_left'length) else
							'0';
	last_bit_right_nxt 	<= 	'1' when counter_right = to_unsigned(1, counter_right'length) else
							'0';
	
	-- shift register
	audio_left_in_nxt 	<=	audio_left_in(CW_AUDIO_SAMPLE-2 downto 0) & ain_left_data	when (ain_left_sync = '1') or (counter_left > to_unsigned(0, counter_left'length)) 		else
							audio_left_in;
	audio_right_in_nxt 	<=	audio_right_in(CW_AUDIO_SAMPLE-2 downto 0) & ain_right_data	when (ain_right_sync = '1') or (counter_right > to_unsigned(0, counter_right'length)) 	else
							audio_right_in;
	
	-- interrupt
	irq_left_nxt 		<= 	'1' when last_bit_left = '1'	else 
							'0' when iobus_ack_left = '1'	else
							irq_left;
	irq_right_nxt 		<= 	'1' when last_bit_right	= '1'	else 
							'0' when iobus_ack_right = '1'	else
							irq_right;
	
	
	-- buffer audio-data for serialization (to prevent change of data during serialization)
	audio_left_out_buf_nxt 	<= audio_left_out 	when ain_left_sync = '1' 	else audio_left_out_buf;
	audio_right_out_buf_nxt <= audio_right_out 	when ain_right_sync = '1' 	else audio_right_out_buf;
	
	-- handling of outgoing audio data
	aout_left_sync 		<= 	'1' when ain_left_sync = '1' else 
							'0';
	aout_left_data 		<= 	audio_left_out(CW_AUDIO_SAMPLE-1) 					when ain_left_sync = '1'								else
							audio_left_out_buf(to_integer(counter_left)-1) 		when counter_left > to_unsigned(0, counter_left'length) else
							'0';
							
	aout_right_sync 	<= 	'1' when ain_right_sync = '1' else 
							'0';
	aout_right_data 	<= 	audio_right_out(CW_AUDIO_SAMPLE-1) 					when ain_right_sync = '1'									else
							audio_right_out_buf(to_integer(counter_right)-1) 	when counter_right > to_unsigned(0, counter_right'length)	else
							'0';
	
	configurator_reg_data	<= 	"000010" & config(0) & '0' & config(1)	when (config_old /= config)	else
								(others => '0');
	configurator_reg_addr	<= 	"0000100"	when (config_old /= config)	else
								(others => '0');
	configurator_valid		<= 	'1'	when ((configurator_busy = '0') and (config_old /= config)) else
								'0';
	config_old_nxt 			<= 	config	when ((configurator_busy = '0') and (config_old /= config)) else
								config_old;
	
	-- iobus
	process(iobus_cs, iobus_wr, iobus_addr, iobus_din, audio_left_out, audio_right_out, config, audio_left_in, audio_right_in)
	begin
		audio_left_out_nxt 	<= audio_left_out;
		audio_right_out_nxt <= audio_right_out;
		config_nxt 			<= config;
		
		iobus_dout <= (others => '0');
		
		-- chipselect
		if iobus_cs	= '1' then
			-- write outgoing register / config reg
			if iobus_wr = '1' then
				-- left channel
				if 		iobus_addr = std_ulogic_vector(to_unsigned(0, iobus_addr'length)) then 
					audio_left_out_nxt 	<= iobus_din(CW_AUDIO_SAMPLE-1 downto 0);
					
				-- right channel
				elsif 	iobus_addr = std_ulogic_vector(to_unsigned(1, iobus_addr'length)) then 
					audio_right_out_nxt <= iobus_din(CW_AUDIO_SAMPLE-1 downto 0);
					
				-- config register
				else 
					config_nxt 			<= iobus_din(config'length-1 downto 0);
				end if;
			
			--read register
			else
				-- left channel
				if 		iobus_addr = std_ulogic_vector(to_unsigned(0, iobus_addr'length)) then 
					iobus_dout(CW_AUDIO_SAMPLE-1 downto 0) 	<= audio_left_in;
					
				-- right channel
				elsif 	iobus_addr = std_ulogic_vector(to_unsigned(1, iobus_addr'length)) then 
					iobus_dout(CW_AUDIO_SAMPLE-1 downto 0) 	<= audio_right_in;
					
				-- config register
				else 
					iobus_dout(config'length-1 downto 0) 	<= config;
				end if;
				
			end if; -- wr
			
		end if; -- cs
	
	end process;
	

end rtl;