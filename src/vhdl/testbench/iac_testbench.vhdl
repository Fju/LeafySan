-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : Testbench
-- Last update  : 28.11.2013
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.standard.all;
use std.textio.all;
use std.env.all;

library work;
use work.iac_pkg.all;

entity iac_testbench is

end iac_testbench;

architecture sim of iac_testbench is

	constant SYSTEM_CYCLE_TIME 	: time := 20 ns; -- 50MHz
	constant SIMULATION_TIME 	: time := 100000 * SYSTEM_CYCLE_TIME;
		
	constant FULL_DEBUG : natural := 0;
	
	constant SIMULATION_MODE : boolean := true;

	signal clock, reset_n, reset : std_ulogic;
	
	signal end_simulation : std_ulogic;
	
	
	-- 7_seg
	signal hex0_n					: std_ulogic_vector(6 downto 0);
	signal hex1_n					: std_ulogic_vector(6 downto 0);
	signal hex2_n					: std_ulogic_vector(6 downto 0);
	signal hex3_n					: std_ulogic_vector(6 downto 0);
	signal hex4_n					: std_ulogic_vector(6 downto 0);
	signal hex5_n					: std_ulogic_vector(6 downto 0);
	signal hex6_n					: std_ulogic_vector(6 downto 0);
	signal hex7_n					: std_ulogic_vector(6 downto 0);
	-- gpio               
	signal gpio 					: std_logic_vector(15 downto 0);
	-- lcd                
	signal lcd_en					: std_ulogic;
	signal lcd_rs					: std_ulogic;
	signal lcd_rw					: std_ulogic;
	signal lcd_on					: std_ulogic;
	signal lcd_blon					: std_ulogic;
	signal lcd_dat					: std_ulogic_vector(7 downto 0);
	-- led/switches/keys  
	signal led_green				: std_ulogic_vector(8  downto 0);
	signal led_red					: std_ulogic_vector(17 downto 0);
	signal switch					: std_ulogic_vector(17 downto 0);
	signal key_n, key				: std_ulogic_vector(2  downto 0);
	-- adc_dac
	signal exb_adc_switch 			: std_ulogic_vector(2 downto 0);
	signal exb_adc_en_n				: std_ulogic;
	signal exb_dac_ldac_n 			: std_ulogic;		
	signal exb_spi_clk 				: std_ulogic;
	signal exb_spi_mosi 			: std_ulogic;
	signal exb_spi_miso 			: std_logic;
	signal exb_spi_cs_adc_n 		: std_ulogic;
	signal exb_spi_cs_dac_n 		: std_ulogic;
	-- sram               
	signal sram_ce_n				: std_ulogic;
	signal sram_oe_n				: std_ulogic;
	signal sram_we_n				: std_ulogic;
	signal sram_ub_n				: std_ulogic;
	signal sram_lb_n				: std_ulogic;
	signal sram_addr				: std_ulogic_vector(19 downto 0);
	signal sram_dq					: std_logic_vector(15 downto 0);
	-- uart        
	signal uart_rts 				: std_ulogic;
	signal uart_cts 				: std_ulogic;	
	signal uart_rxd					: std_ulogic;
	signal uart_txd					: std_ulogic;
	-- audio
	signal aud_xclk     			: std_ulogic;
	signal aud_bclk     			: std_ulogic;
	signal aud_adc_lrck 			: std_ulogic;
	signal aud_adc_dat  			: std_ulogic;
	signal aud_dac_lrck 			: std_ulogic;
	signal aud_dac_dat  			: std_ulogic;
	signal i2c_sdat     			: std_logic;
	signal i2c_sclk     			: std_ulogic;
	-- infrared
	signal irda_rxd 				: std_ulogic;



	component iac_toplevel is
		generic (
			SIMULATION 				: boolean
		);
		port (
			-- global signals
			clock_ext_50			: in  	std_ulogic;
			clock_ext2_50			: in  	std_ulogic;
			clock_ext3_50			: in  	std_ulogic;
			reset_n					: in  	std_ulogic; -- (key3)
			-- 7_seg
			hex0_n					: out 	std_ulogic_vector(6 downto 0);
			hex1_n					: out 	std_ulogic_vector(6 downto 0);
			hex2_n					: out 	std_ulogic_vector(6 downto 0);
			hex3_n					: out 	std_ulogic_vector(6 downto 0);
			hex4_n					: out 	std_ulogic_vector(6 downto 0);
			hex5_n					: out 	std_ulogic_vector(6 downto 0);
			hex6_n					: out 	std_ulogic_vector(6 downto 0);
			hex7_n					: out 	std_ulogic_vector(6 downto 0);
			-- gpio
			gpio 					: inout	std_logic_vector(15 downto 0);
			-- lcd
			lcd_en					: out 	std_ulogic;
			lcd_rs					: out 	std_ulogic;
			lcd_rw					: out 	std_ulogic;
			lcd_on					: out 	std_ulogic;
			lcd_blon				: out 	std_ulogic;
			lcd_dat					: out 	std_ulogic_vector(7 downto 0);
			-- led/switches/keys
			led_green				: out 	std_ulogic_vector(8  downto 0);
			led_red					: out	std_ulogic_vector(17 downto 0);
			switch					: in	std_ulogic_vector(17 downto 0);
			key_n 					: in	std_ulogic_vector(2  downto 0);
			-- adc_dac
			exb_adc_switch  		: out 	std_ulogic_vector(2 downto 0);
			exb_adc_en_n			: out 	std_ulogic;
			exb_dac_ldac_n 			: out 	std_ulogic;		
			exb_spi_clk 			: out 	std_ulogic;
			exb_spi_mosi 			: out 	std_ulogic;
			exb_spi_miso 			: in  	std_logic;
			exb_spi_cs_adc_n 		: out 	std_ulogic;
			exb_spi_cs_dac_n 		: out 	std_ulogic;
			-- sram
			sram_ce_n				: out   std_ulogic;
			sram_oe_n				: out   std_ulogic;
			sram_we_n				: out   std_ulogic;
			sram_ub_n				: out   std_ulogic;
			sram_lb_n				: out   std_ulogic;
			sram_addr				: out   std_ulogic_vector(19 downto 0);
			sram_dq					: inout std_logic_vector(15 downto 0);
			-- uart
			uart_rts 				: in 	std_ulogic;
			uart_cts 				: out 	std_ulogic;
			uart_rxd				: in  	std_ulogic;
			uart_txd				: out 	std_ulogic;
			-- audio
			aud_xclk     			: out   std_ulogic;
			aud_bclk     			: in    std_ulogic;
			aud_adc_lrck 			: in    std_ulogic;
			aud_adc_dat  			: in    std_ulogic;
			aud_dac_lrck 			: in    std_ulogic;
			aud_dac_dat  			: out   std_ulogic;
			i2c_sdat     			: inout std_logic;
			i2c_sclk     			: inout std_logic;
			-- infrared
			irda_rxd 				: in 	std_ulogic
		);
	end component iac_toplevel;


	component io_model is
		generic(
			-- file containing static bit-settings for io's
			FILE_NAME_SET 		: string
		);
		port(
			-- io's
			gpio 				: inout	std_logic_vector(15 downto 0);
			switch				: out	std_ulogic_vector(17 downto 0);
			key 				: out	std_ulogic_vector(2  downto 0)
		);
	end component io_model;
	
	component adc_model is
		generic(
			SYSTEM_CYCLE_TIME 	: time;
			FULL_DEBUG 			: natural;
			FILE_NAME_PRELOAD 	: string
		);
		port(
			-- Global Signals
			end_simulation : in  std_logic;
			-- SPI Signals
			spi_clk 	   : in  std_ulogic;
			spi_miso 	   : out std_logic;
			spi_cs_n 	   : in  std_ulogic;
			-- Switch Signals
			swt_select	   : in  std_ulogic_vector(2 downto 0);
			swt_enable_n   : in  std_ulogic
		);
	end component adc_model;
	
	component dac_model is
		generic(
			SYSTEM_CYCLE_TIME 	: time;
			FILE_NAME_DUMP 		: string
		);
		port(
			-- Global Signals
			end_simulation : in  std_logic;
			-- SPI Signals
			spi_clk 	   : in std_ulogic;
			spi_mosi 	   : in std_ulogic;
			spi_cs_n 	   : in std_ulogic;
			-- DAC Signals
			dac_ldac_n	   : in std_ulogic
		);
	end component dac_model;
	
	
	component seven_seg_model is
		generic (
			SYSTEM_CYCLE_TIME 	: time
		);
		port (
			-- Global Signals
			end_simulation 	: in std_ulogic;
			-- 7-seg connections
			hex0_n			: in std_ulogic_vector(6 downto 0);
			hex1_n			: in std_ulogic_vector(6 downto 0);
			hex2_n			: in std_ulogic_vector(6 downto 0);
			hex3_n			: in std_ulogic_vector(6 downto 0);
			hex4_n			: in std_ulogic_vector(6 downto 0);
			hex5_n			: in std_ulogic_vector(6 downto 0);
			hex6_n			: in std_ulogic_vector(6 downto 0);
			hex7_n			: in std_ulogic_vector(6 downto 0)
		);
	end component seven_seg_model;
	
	
	component infrared_model is
		generic (
			SYSTEM_CYCLE_TIME 	: time;
			-- file with bytes to be send to fpga
			FILE_NAME_COMMAND 	: string;
			-- custom code of ir-sender
			CUSTOM_CODE 		: std_ulogic_vector(15 downto 0);
			SIMULATION 			: boolean
		);
		port (
			-- global signals
			end_simulation	: in  std_ulogic;
			-- ir-pin
			irda_txd 		: out std_ulogic
		);
	end component infrared_model;
	
	
	component lcd_model is
		generic(
			SYSTEM_CYCLE_TIME 	: time;
			FULL_DEBUG 			: natural
		);
		port(
			-- Global Signals
			end_simulation : in  std_ulogic;
			-- LCD Signals
			disp_en 	   : in  std_ulogic;
			disp_rs 	   : in  std_ulogic;
			disp_rw 	   : in  std_ulogic;
			disp_dat	   : in  std_ulogic_vector(7 downto 0)
		);
	end component lcd_model;
	
	
	component sram_model is
		generic(
			SYSTEM_CYCLE_TIME 	: time;
			FULL_DEBUG 			: natural;
			-- file for preload of sram
			FILE_NAME_PRELOAD 	: string;
			-- file for dump at end of simulation
			FILE_NAME_DUMP 		: string;
			-- number of addressable words in sram (size of sram)
			GV_SRAM_SIZE 		: natural
		);
		port(
			-- global signals
			end_simulation 	: in 	std_ulogic;
			-- sram connections
			sram_ce_n		: in	std_ulogic;
			sram_oe_n		: in	std_ulogic;
			sram_we_n		: in	std_ulogic;
			sram_ub_n		: in	std_ulogic;
			sram_lb_n		: in	std_ulogic;
			sram_addr		: in	std_ulogic_vector(19 downto 0);
			sram_dq			: inout	std_logic_vector(15 downto 0)
		);
	end component sram_model;
	
	
	component uart_model is
		generic (
			SYSTEM_CYCLE_TIME 	: time;
			-- file with data to be send to fpga
			FILE_NAME_COMMAND 	: string;
			-- file for dump of data, received by pc
			FILE_NAME_DUMP 		: string;
			-- communication speed for uart-link
			BAUD_RATE 			: natural;
			SIMULATION 			: boolean
		);
		port (
			-- global signals
			end_simulation	: in  std_ulogic;
			-- uart-pins (pc side)
			rx 				: in  std_ulogic; 
			tx 				: out std_ulogic
		);
	end component uart_model;
	
	
	signal i2c_sdat_pullup_wire : std_logic;
	signal i2c_sclk_pullup_wire : std_logic;
	
	component acodec_model is
		generic (
			SAMPLE_WIDTH 	: natural;
			SAMPLE_RATE 	: natural;
			SAMPLE_FILE 	: string
		);
		port (
			-- acodec signals
			aud_xclk		: in	std_ulogic;
			aud_bclk 		: out   std_ulogic;
			aud_adc_lrck 	: out   std_ulogic;
			aud_adc_dat  	: out   std_ulogic;
			aud_dac_lrck 	: out   std_ulogic;
			aud_dac_dat  	: in    std_ulogic;
			i2c_sdat		: inout std_logic;
			i2c_sclk		: in    std_logic
		);
	end component acodec_model;

begin

	reset <= not(reset_n);

	clk : process
	begin
		clock <= '1';
		wait for SYSTEM_CYCLE_TIME/2;
		clock <= '0';
		wait for SYSTEM_CYCLE_TIME/2;
	end process clk;
	
	rst : process
	begin
		reset_n <= '0';
		wait for 2*SYSTEM_CYCLE_TIME;
		reset_n <= '1';
		wait;
	end process rst;
	
	end_sim : process
		variable tmp : line;
	begin
		end_simulation <= '0';
		wait for SIMULATION_TIME;
		end_simulation <= '1';
		wait for 10*SYSTEM_CYCLE_TIME;
		write(tmp, string'("Simulation finished: end time reached!"));
		writeline(output, tmp);
		stop;
		wait;
	end process end_sim;
	
	
	iac_toplevel_inst : iac_toplevel
		generic map (
			SIMULATION 				=> SIMULATION_MODE
		)
		port map (
			clock_ext_50			=> clock,
			clock_ext2_50			=> clock,
			clock_ext3_50			=> clock,
			reset_n					=> reset_n,
			hex0_n					=> hex0_n,				
			hex1_n					=> hex1_n,
			hex2_n					=> hex2_n,
			hex3_n					=> hex3_n,
			hex4_n					=> hex4_n,
			hex5_n					=> hex5_n,
			hex6_n					=> hex6_n,
			hex7_n					=> hex7_n,
			gpio 					=> gpio,
			lcd_en					=> lcd_en,
			lcd_rs					=> lcd_rs,
			lcd_rw					=> lcd_rw,
			lcd_on					=> lcd_on,
			lcd_blon				=> lcd_blon,
			lcd_dat					=> lcd_dat,
			led_green				=> led_green,
			led_red					=> led_red,
			switch					=> switch,
			key_n 					=> key_n,
			exb_adc_switch  		=> exb_adc_switch,
			exb_adc_en_n			=> exb_adc_en_n,
			exb_dac_ldac_n 			=> exb_dac_ldac_n,
			exb_spi_clk 			=> exb_spi_clk,
			exb_spi_mosi 			=> exb_spi_mosi,
			exb_spi_miso 			=> exb_spi_miso,
			exb_spi_cs_adc_n 		=> exb_spi_cs_adc_n,
			exb_spi_cs_dac_n 		=> exb_spi_cs_dac_n,
			sram_ce_n				=> sram_ce_n,
			sram_oe_n				=> sram_oe_n,
			sram_we_n				=> sram_we_n,
			sram_ub_n				=> sram_ub_n,
			sram_lb_n				=> sram_lb_n,
			sram_addr				=> sram_addr,
			sram_dq					=> sram_dq,
			uart_rts 				=> uart_rts,
			uart_cts 				=> uart_cts,
			uart_rxd				=> uart_rxd,
			uart_txd				=> uart_txd,
			aud_xclk     			=> aud_xclk,
			aud_bclk     			=> aud_bclk,
			aud_adc_lrck 			=> aud_adc_lrck,
			aud_adc_dat  			=> aud_adc_dat,
			aud_dac_lrck 			=> aud_dac_lrck,
			aud_dac_dat  			=> aud_dac_dat,
			i2c_sdat     			=> i2c_sdat_pullup_wire,
			i2c_sclk     			=> i2c_sclk_pullup_wire,
			irda_rxd 				=> irda_rxd
		);
		
	
	key_n	<= not(key);
	
	
	io_model_inst : io_model
		generic map (
			FILE_NAME_SET 		=> "io.txt")
		port map (
			gpio 				=> gpio,
			switch				=> switch,
			key 				=> key
		);
	
	
	seven_seg_gen : if CV_EN_SEVENSEG = 1 generate
		seven_seg_model_inst : seven_seg_model
			generic map (
				SYSTEM_CYCLE_TIME 	=> SYSTEM_CYCLE_TIME)
			port map (
				end_simulation 	=> end_simulation,
				hex0_n			=> hex0_n,
				hex1_n			=> hex1_n,
				hex2_n			=> hex2_n,
				hex3_n			=> hex3_n,
				hex4_n			=> hex4_n,
				hex5_n			=> hex5_n,
				hex6_n			=> hex6_n,
				hex7_n			=> hex7_n
			);
	end generate seven_seg_gen;
	
		
	exb_spi_miso <= 'H';
		
	adc_dac_gen : if CV_EN_ADC_DAC = 1 generate
		adc_model_inst : adc_model
			generic map (
				SYSTEM_CYCLE_TIME 	=> SYSTEM_CYCLE_TIME,
				FULL_DEBUG 			=> FULL_DEBUG,
				FILE_NAME_PRELOAD 	=> "adc_preload.txt")
			port map (
				end_simulation	=> end_simulation,
				spi_clk			=> exb_spi_clk,
				spi_miso		=> exb_spi_miso,
				spi_cs_n		=> exb_spi_cs_adc_n,
				swt_select		=> exb_adc_switch,
				swt_enable_n	=> exb_adc_en_n
			);
			
		dac_model_inst : dac_model
			generic map (
				SYSTEM_CYCLE_TIME 	=> SYSTEM_CYCLE_TIME,
				FILE_NAME_DUMP 		=> "dac_dump.txt")
			port map (
				end_simulation	=> end_simulation,
				spi_clk			=> exb_spi_clk,
				spi_mosi		=> exb_spi_mosi,
				spi_cs_n		=> exb_spi_cs_dac_n,
				dac_ldac_n		=> exb_dac_ldac_n
			);
	end generate adc_dac_gen;
	
	
	i2c_sdat_pullup_wire <= 'H';
	i2c_sclk_pullup_wire <= 'H';

	audio_gen : if CV_EN_AUDIO = 1 generate
		acodec_inst : acodec_model
			generic map (
				SAMPLE_WIDTH 	=> 16,
				SAMPLE_RATE 	=> 8*44100,
				SAMPLE_FILE 	=> "audio_samples.txt")
			port  map (
				aud_xclk 		=> aud_xclk,
				aud_bclk 		=> aud_bclk,
				aud_adc_lrck 	=> aud_adc_lrck,
				aud_adc_dat  	=> aud_adc_dat,
				aud_dac_lrck 	=> aud_dac_lrck,
				aud_dac_dat  	=> aud_dac_dat,
				i2c_sdat		=> i2c_sdat_pullup_wire,
				i2c_sclk		=> i2c_sclk_pullup_wire
			);
	end generate audio_gen;
	
	
	infrared_gen : if CV_EN_IR = 1 generate
		infrared_inst : infrared_model
			generic map (
				SYSTEM_CYCLE_TIME 	=> SYSTEM_CYCLE_TIME,
				FILE_NAME_COMMAND 	=> "ir_command.txt",
				CUSTOM_CODE 		=> x"6B86",
				SIMULATION 			=> SIMULATION_MODE
			)
			port map (
				end_simulation	=> end_simulation,
				irda_txd 		=> irda_rxd
			);
	end generate infrared_gen;
	
	
	lcd_gen : if CV_EN_LCD = 1 generate
		lcd_model_inst : lcd_model
		generic map(
			SYSTEM_CYCLE_TIME 	=> SYSTEM_CYCLE_TIME,
		    FULL_DEBUG 			=> FULL_DEBUG
		)
		port map (
			end_simulation => end_simulation,
			disp_en 	   => lcd_en,
			disp_rs 	   => lcd_rs,
			disp_rw 	   => lcd_rw,
			disp_dat	   => lcd_dat
		);
	end generate lcd_gen;
	
	
	sram_gen : if CV_EN_SRAM = 1 generate
		sram_model_inst : sram_model
			generic map (
				SYSTEM_CYCLE_TIME 	=> SYSTEM_CYCLE_TIME,
				FULL_DEBUG 			=> FULL_DEBUG,
				FILE_NAME_PRELOAD 	=> "sram_preload.txt",
				FILE_NAME_DUMP 		=> "sram_dump.txt",
				GV_SRAM_SIZE 		=> 2**20
			)
			port map (
				end_simulation 	=> end_simulation,
				sram_ce_n		=> sram_ce_n,
				sram_oe_n		=> sram_oe_n,
				sram_we_n		=> sram_we_n,
				sram_ub_n		=> sram_ub_n,
				sram_lb_n		=> sram_lb_n,
				sram_addr		=> sram_addr,
				sram_dq			=> sram_dq
			);
	end generate sram_gen;
	
	
	uart_gen : if CV_EN_UART = 1 generate
		uart_model_inst : uart_model
			generic map (
				SYSTEM_CYCLE_TIME 	=> SYSTEM_CYCLE_TIME,
				FILE_NAME_COMMAND 	=> "uart_command.txt",
				FILE_NAME_DUMP 		=> "uart_dump.txt",
				BAUD_RATE 			=> CV_UART_BAUDRATE,
				SIMULATION 			=> SIMULATION_MODE
			)
			port map (
				end_simulation	=> end_simulation,
				rx 				=> uart_txd,
				tx 				=> uart_rxd
			);
	end generate uart_gen;
	
end sim;
