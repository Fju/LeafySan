-----------------------------------------------------------------------------------------
-- Project      : 	Invent a Chip
-- Module       : 	Toplevel
-- Author 		: 	Jan D�rre
-- Last update  : 	12.01.2015
-- Description	: 	-
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity iac_toplevel is
	generic (
		SIMULATION 				: boolean := false
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
end iac_toplevel;

architecture rtl of iac_toplevel is

	-- clock
	signal clk_50 				: std_ulogic;	-- 50 MHz
	signal clk_audio_12  		: std_ulogic;	-- 12 MHz
	
	signal pll_locked 			: std_ulogic;

	-- reset
	signal reset 				: std_ulogic;
	signal reset_intern 		: std_ulogic;
	signal reset_n_intern 		: std_ulogic;
	
	-- 7-Seg Bus Signals
	signal sevenseg_cs 	 : std_ulogic;
	signal sevenseg_wr 	 : std_ulogic;
	signal sevenseg_addr : std_ulogic_vector(CW_ADDR_SEVENSEG-1 downto 0);
	signal sevenseg_din  : std_ulogic_vector(CW_DATA_SEVENSEG-1 downto 0);
	signal sevenseg_dout : std_ulogic_vector(CW_DATA_SEVENSEG-1 downto 0);

	-- ADC/DAC Bus Signals
	signal adc_dac_cs 	: std_ulogic;
	signal adc_dac_wr 	: std_ulogic;
	signal adc_dac_addr : std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0);
	signal adc_dac_din  : std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
	signal adc_dac_dout : std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
	
	-- Audio Bus Signals
	signal audio_cs 	   : std_ulogic;
	signal audio_wr 	   : std_ulogic;
	signal audio_addr  	   : std_ulogic_vector(CW_ADDR_AUDIO-1 downto 0);
	signal audio_din  	   : std_ulogic_vector(CW_DATA_AUDIO-1 downto 0);
	signal audio_dout 	   : std_ulogic_vector(CW_DATA_AUDIO-1 downto 0);
	signal audio_irq_left  : std_ulogic;
	signal audio_irq_right : std_ulogic;
	signal audio_ack_left  : std_ulogic;
	signal audio_ack_right : std_ulogic;
	
	-- Infra-red Receiver
	signal ir_cs 		: std_ulogic;
	signal ir_wr 		: std_ulogic;
	signal ir_addr 		: std_ulogic_vector(CW_ADDR_IR-1 downto 0);
	signal ir_din  		: std_ulogic_vector(CW_DATA_IR-1 downto 0);
	signal ir_dout 		: std_ulogic_vector(CW_DATA_IR-1 downto 0);
	signal ir_irq_rx	: std_ulogic;
	signal ir_ack_rx	: std_ulogic;
	
	-- LCD Bus Signals
	signal lcd_cs 		: std_ulogic;
	signal lcd_wr		: std_ulogic;
	signal lcd_addr		: std_ulogic_vector(CW_ADDR_LCD-1 downto 0);
	signal lcd_din		: std_ulogic_vector(CW_DATA_LCD-1 downto 0);
	signal lcd_dout 	: std_ulogic_vector(CW_DATA_LCD-1 downto 0);
	signal lcd_irq_rdy 	: std_ulogic;
	signal lcd_ack_rdy 	: std_ulogic;
		
	-- SRAM Bus Signals
	signal sram_cs 	 : std_ulogic;
	signal sram_wr 	 : std_ulogic;
	signal sram_adr  : std_ulogic_vector(CW_ADDR_SRAM-1 downto 0); -- slightly different name, because of a conflict with the entity
	signal sram_din  : std_ulogic_vector(CW_DATA_SRAM-1 downto 0);
	signal sram_dout : std_ulogic_vector(CW_DATA_SRAM-1 downto 0);
	
	-- UART Bus Signals
	signal uart_cs 	 	 	: std_ulogic;
	signal uart_wr 	 	 	: std_ulogic;
	signal uart_addr  	 	: std_ulogic_vector(CW_ADDR_UART-1 downto 0);
	signal uart_din  	 	: std_ulogic_vector(CW_DATA_UART-1 downto 0);
	signal uart_dout 	 	: std_ulogic_vector(CW_DATA_UART-1 downto 0);
	signal uart_irq_rx	 	: std_ulogic;
	signal uart_irq_tx	 	: std_ulogic;
	signal uart_ack_rx	 	: std_ulogic;
	signal uart_ack_tx	 	: std_ulogic;
	
	
	-- mux data signals for the case an interface is disabled
	signal sevenseg_dout_wire		: std_ulogic_vector(CW_DATA_SEVENSEG-1 downto 0);
	signal adc_dac_dout_wire		: std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
	signal ir_dout_wire 			: std_ulogic_vector(CW_DATA_IR-1 downto 0);
	signal lcd_dout_wire			: std_ulogic_vector(CW_DATA_LCD-1 downto 0);
	signal sram_dout_wire			: std_ulogic_vector(CW_DATA_SRAM-1 downto 0);
	signal uart_dout_wire			: std_ulogic_vector(CW_DATA_UART-1 downto 0);
	signal audio_dout_wire			: std_ulogic_vector(CW_DATA_AUDIO-1 downto 0);
	
	signal audio_irq_left_wire 		: std_ulogic;
	signal audio_irq_right_wire		: std_ulogic;
	signal ir_irq_rx_wire			: std_ulogic;
	signal lcd_irq_rdy_wire			: std_ulogic;
	signal uart_irq_rx_wire			: std_ulogic;
	signal uart_irq_tx_wire			: std_ulogic;
	
	
	-- key to revert key_n
	signal key 	: std_ulogic_vector(2 downto 0);
	-- register to sync async input signals
	signal key_reg		: std_ulogic_vector(2 downto 0);
	signal switch_reg 	: std_ulogic_vector(17 downto 0);
	
	-- gpio
	component gpio_switcher is
		port (
			gpio 			: inout std_logic_vector(15 downto 0);
			gp_ctrl 		: in  	std_ulogic_vector(15 downto 0);
			gp_in 			: out 	std_ulogic_vector(15 downto 0);
			gp_out 			: in	std_ulogic_vector(15 downto 0)
		);
	end component gpio_switcher;
	
	signal gp_ctrl 	: std_ulogic_vector(15 downto 0);
	signal gp_out 	: std_ulogic_vector(15 downto 0);
	signal gp_in 	: std_ulogic_vector(15 downto 0);
	
	-- PLL (clk_50, clk_audio_12)
	component pll is
		port (
			areset : in  std_ulogic;
			inclk0 : in  std_ulogic;
			c0     : out std_ulogic;
			c1     : out std_ulogic;
			locked : out std_ulogic
		);
	end component pll;
	
	-- components
	component invent_a_chip is
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
	end component invent_a_chip;
	
	
	component seven_seg is
		port (
			-- global signals
			clock		: in  std_ulogic;
			reset_n		: in  std_ulogic;
			-- bus interface
			iobus_cs	: in  std_ulogic;
			iobus_wr	: in  std_ulogic;
			iobus_addr	: in  std_ulogic_vector(CW_ADDR_SEVENSEG-1 downto 0);
			iobus_din	: in  std_ulogic_vector(CW_DATA_SEVENSEG-1 downto 0);
			iobus_dout	: out std_ulogic_vector(CW_DATA_SEVENSEG-1 downto 0);
			-- 7-Seg
			hex0_n		: out std_ulogic_vector(6 downto 0);
			hex1_n		: out std_ulogic_vector(6 downto 0);
			hex2_n		: out std_ulogic_vector(6 downto 0);
			hex3_n		: out std_ulogic_vector(6 downto 0);
			hex4_n		: out std_ulogic_vector(6 downto 0);
			hex5_n		: out std_ulogic_vector(6 downto 0);
			hex6_n		: out std_ulogic_vector(6 downto 0);
			hex7_n		: out std_ulogic_vector(6 downto 0)
		);
	end component seven_seg;
	
	
	component adc_dac is
		port (
			-- global signals
			clock          : in  std_ulogic;
			reset_n        : in  std_ulogic;
			-- bus interface
			iobus_cs       : in  std_ulogic;
			iobus_wr       : in  std_ulogic;
			iobus_addr     : in  std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0);
			iobus_din      : in  std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
			iobus_dout     : out std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
			-- adc/dac signals
			-- spi signals
			spi_clk		   : out std_ulogic;
			spi_mosi	   : out std_ulogic;
			spi_miso	   : in  std_ulogic;
			spi_cs_dac_n   : out std_ulogic;
			spi_cs_adc_n   : out std_ulogic;
			-- Switch Signals
			swt_select	   : out std_ulogic_vector(2 downto 0);
			swt_enable_n   : out std_ulogic;
			-- DAC Signals
			dac_ldac_n	   : out std_ulogic
		 );
	end component adc_dac;
	
	
	component audio is
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
			aud_xclk 		: out 	std_ulogic;
			aud_bclk     	: in    std_ulogic;
			aud_adc_lrck 	: in    std_ulogic;
			aud_adc_dat  	: in    std_ulogic;
			aud_dac_lrck 	: in    std_ulogic;
			aud_dac_dat  	: out   std_ulogic;
			i2c_sdat     	: inout std_logic;
			i2c_sclk     	: inout std_logic
		);
	end component audio;
	
	
	component infrared is
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
	end component infrared;
	
	
	component lcd is
		generic (
			SIMULATION 		: boolean := false
		);
		port (
			-- global signals
			clock			: in  std_ulogic;
			reset_n			: in  std_ulogic;
			-- bus signals 
			iobus_cs		: in  std_ulogic;
			iobus_wr		: in  std_ulogic;
			iobus_addr		: in  std_ulogic_vector(CW_ADDR_LCD-1 downto 0);
			iobus_din		: in  std_ulogic_vector(CW_DATA_LCD-1 downto 0);
			iobus_dout		: out std_ulogic_vector(CW_DATA_LCD-1 downto 0);
			iobus_irq_rdy 	: out std_ulogic;
			iobus_ack_rdy 	: in  std_ulogic;
			-- display signals
			disp_en			: out std_ulogic;
			disp_rs			: out std_ulogic;
			disp_rw			: out std_ulogic;
			disp_dat		: out std_ulogic_vector(7 downto 0);
			disp_pwr		: out std_ulogic;
			disp_blon		: out std_ulogic
		);
	end component lcd;
	
	
	component sram is
		port (
			-- global signals
			clock		: in  std_ulogic;
			reset_n		: in  std_ulogic;
			-- bus interface
			iobus_cs	: in  std_ulogic;
			iobus_wr	: in  std_ulogic;
			iobus_addr	: in  std_ulogic_vector(CW_ADDR_SRAM-1 downto 0);
			iobus_din	: in  std_ulogic_vector(CW_DATA_SRAM-1 downto 0);
			iobus_dout	: out std_ulogic_vector(CW_DATA_SRAM-1 downto 0);    
			-- sram connections
			sram_ce_n	: out   std_ulogic;
			sram_oe_n	: out   std_ulogic;
			sram_we_n	: out   std_ulogic;
			sram_ub_n	: out   std_ulogic;
			sram_lb_n	: out   std_ulogic;
			sram_addr	: out   std_ulogic_vector(19 downto 0);
			sram_dq		: inout std_logic_vector(15 downto 0)
		);
	end component sram;
	
	
	component uart is
		generic (
			SIMULATION 		: boolean := false
		);
        port (
            -- global signals
			clock			: in  std_ulogic;
			reset_n			: in  std_ulogic;
			-- bus interface
			iobus_cs		: in  std_ulogic;
			iobus_wr		: in  std_ulogic;
			iobus_addr		: in  std_ulogic_vector(CW_ADDR_UART-1 downto 0);
			iobus_din		: in  std_ulogic_vector(CW_DATA_UART-1 downto 0);
			iobus_dout		: out std_ulogic_vector(CW_DATA_UART-1 downto 0);
			-- IRQ handling
			iobus_irq_rx  	: out  std_ulogic;
			iobus_irq_tx  	: out  std_ulogic;
			iobus_ack_rx  	: in   std_ulogic;
			iobus_ack_tx  	: in   std_ulogic;
			-- pins to outside 
			rts				: in  std_ulogic;
			cts				: out std_ulogic;
			rxd				: in  std_ulogic;
			txd				: out std_ulogic
        );
	end component uart;		
	
begin

	-- gpio
	gpio_switcher_inst : gpio_switcher
		port map (
			gpio 			=> gpio,
			gp_ctrl 		=> gp_ctrl,
			gp_in 			=> gp_in,
			gp_out 			=> gp_out
		);


	-- PLL
	pll_inst : pll
		port map (
			areset	=> reset,
			inclk0	=> clock_ext_50,
			c0		=> clk_50,
			c1 		=> clk_audio_12,
			locked	=> pll_locked
		);
		
	
	-- external reset
	reset <= not(reset_n);
	
	-- high active internal reset-signal
	reset_n_intern <= pll_locked;
	reset_intern <= not reset_n_intern;
	
	-- invert low-active keys
	key <= not key_n;
	
	-- register to sync async signals
	process(clk_50, reset_n_intern)
	begin
		if reset_n_intern = '0' then
			key_reg 	<= (others => '0');
			switch_reg	<= (others => '0');
		elsif rising_edge(clk_50) then
			key_reg 	<= key;
			switch_reg 	<= switch;
		end if;
	end process;
	
	-- mux to prevent undefined signals
	sevenseg_dout_wire		<= (others => '0') when CV_EN_SEVENSEG	= 0 else sevenseg_dout;
	adc_dac_dout_wire		<= (others => '0') when CV_EN_ADC_DAC	= 0 else adc_dac_dout;
	audio_dout_wire			<= (others => '0') when CV_EN_AUDIO		= 0 else audio_dout;
	ir_dout_wire 			<= (others => '0') when CV_EN_IR 		= 0 else ir_dout;
	lcd_dout_wire			<= (others => '0') when CV_EN_LCD		= 0 else lcd_dout;
	sram_dout_wire			<= (others => '0') when CV_EN_SRAM		= 0 else sram_dout;
	uart_dout_wire			<= (others => '0') when CV_EN_UART		= 0 else uart_dout;
		
	audio_irq_left_wire 	<= '0'		when CV_EN_AUDIO	= 0 else audio_irq_left;
	audio_irq_right_wire	<= '0'		when CV_EN_AUDIO	= 0 else audio_irq_right;
	ir_irq_rx_wire 			<= '0' 		when CV_EN_IR 		= 0 else ir_irq_rx;
	lcd_irq_rdy_wire 		<= '0' 		when CV_EN_LCD 		= 0 else lcd_irq_rdy;
	uart_irq_rx_wire		<= '0'		when CV_EN_UART		= 0 else uart_irq_rx;
	uart_irq_tx_wire		<= '0'		when CV_EN_UART		= 0 else uart_irq_tx;
	
	
	-- invent_a_chip module
	invent_a_chip_inst : invent_a_chip
		port map (
			-- Global Signals
			clock				=> clk_50,
			reset				=> reset_intern,
			-- Interface Signals
			-- 7-Seg
			sevenseg_cs   		=> sevenseg_cs,
			sevenseg_wr   		=> sevenseg_wr,
			sevenseg_addr 		=> sevenseg_addr,
			sevenseg_din  		=> sevenseg_dout_wire,
			sevenseg_dout 		=> sevenseg_din,
			-- ADC/DAC
			adc_dac_cs 	 		=> adc_dac_cs,
			adc_dac_wr 	 		=> adc_dac_wr,
			adc_dac_addr 		=> adc_dac_addr,
			adc_dac_din  		=> adc_dac_dout_wire,
			adc_dac_dout 		=> adc_dac_din,
			-- AUDIO
			audio_cs   			=> audio_cs,
			audio_wr   			=> audio_wr,
			audio_addr 			=> audio_addr,
			audio_din  			=> audio_dout_wire,
			audio_dout 			=> audio_din,
			audio_irq_left  	=> audio_irq_left_wire,
			audio_irq_right 	=> audio_irq_right_wire,
			audio_ack_left  	=> audio_ack_left,
			audio_ack_right 	=> audio_ack_right,
			-- Infra-red Receiver
			ir_cs				=> ir_cs,
			ir_wr				=> ir_wr,
			ir_addr				=> ir_addr,
			ir_din				=> ir_dout_wire,
			ir_dout				=> ir_din,
			ir_irq_rx			=> ir_irq_rx_wire,
			ir_ack_rx			=> ir_ack_rx,
			-- LCD
			lcd_cs   			=> lcd_cs,
			lcd_wr   			=> lcd_wr,
			lcd_addr 			=> lcd_addr,
			lcd_din  			=> lcd_dout_wire,
			lcd_dout 			=> lcd_din,
			lcd_irq_rdy			=> lcd_irq_rdy_wire,
			lcd_ack_rdy			=> lcd_ack_rdy,
			-- SRAM
			sram_cs   			=> sram_cs,
			sram_wr   			=> sram_wr,
			sram_addr 			=> sram_adr,
			sram_din  			=> sram_dout_wire,
			sram_dout 			=> sram_din,
			-- UART
			uart_cs   	  		=> uart_cs,
			uart_wr   	  		=> uart_wr,
			uart_addr 	  		=> uart_addr,
			uart_din  	  		=> uart_dout_wire,
			uart_dout 	  		=> uart_din,
			uart_irq_rx  		=> uart_irq_rx_wire,
			uart_irq_tx  		=> uart_irq_tx_wire,
			uart_ack_rx  		=> uart_ack_rx,
			uart_ack_tx  		=> uart_ack_tx,
			-- GPIO
			gp_ctrl 			=> gp_ctrl,
			gp_in 				=> gp_in,
			gp_out				=> gp_out,
			-- LED/Switches/Keys
			led_green			=> led_green,
			led_red				=> led_red,
			switch				=> switch_reg,
			key 				=> key_reg
		);
	

	-- generate interface modules
	seven_seg_gen : if CV_EN_SEVENSEG = 1 generate
		sven_seg_inst : seven_seg
			port map (
				-- global signals
				clock		=> clk_50,
				reset_n		=> reset_n_intern,
				-- bus interface
				iobus_cs	=> sevenseg_cs,
				iobus_wr	=> sevenseg_wr,
				iobus_addr	=> sevenseg_addr,
				iobus_din	=> sevenseg_din,
				iobus_dout	=> sevenseg_dout,
				-- 7-Seg
				hex0_n		=> hex0_n,
				hex1_n		=> hex1_n,
				hex2_n		=> hex2_n,
				hex3_n		=> hex3_n,
				hex4_n		=> hex4_n,
				hex5_n		=> hex5_n,
				hex6_n		=> hex6_n,
				hex7_n		=> hex7_n
			);	
	end generate seven_seg_gen;
	
	adc_dac_gen : if CV_EN_ADC_DAC = 1 generate
		adc_dac_inst : adc_dac
			port map (
				-- global signals
				clock			=> clk_50,
				reset_n			=> reset_n_intern,
				-- bus interface
				iobus_cs		=> adc_dac_cs,
				iobus_wr		=> adc_dac_wr,
				iobus_addr		=> adc_dac_addr,
				iobus_din		=> adc_dac_din,
				iobus_dout		=> adc_dac_dout,
				-- adc/dac signals
				-- spi signals
				spi_clk			=> exb_spi_clk,
				spi_mosi		=> exb_spi_mosi,
				spi_miso		=> exb_spi_miso,
				spi_cs_dac_n	=> exb_spi_cs_dac_n,
				spi_cs_adc_n	=> exb_spi_cs_adc_n,
				-- switch signals
				swt_select		=> exb_adc_switch,
				swt_enable_n	=> exb_adc_en_n,
				-- dac signals
				dac_ldac_n		=> exb_dac_ldac_n
			);
	end generate adc_dac_gen;
	
	audio_gen : if CV_EN_AUDIO = 1 generate
		audio_inst : audio
			port map (
				-- global
				clock 			=> clk_50,
				clock_audio 	=> clk_audio_12,
				reset_n  		=> reset_n_intern,
				-- bus interface
				iobus_cs		=> audio_cs,
				iobus_wr		=> audio_wr,
				iobus_addr		=> audio_addr,
				iobus_din		=> audio_din,
				iobus_dout		=> audio_dout,
				-- IRQ handling
				iobus_irq_left	=> audio_irq_left,
				iobus_irq_right => audio_irq_right,
				iobus_ack_left	=> audio_ack_left,
				iobus_ack_right => audio_ack_right,
				-- connections to audio codec
				aud_xclk		=> aud_xclk,
				aud_bclk     	=> aud_bclk,
				aud_adc_lrck 	=> aud_adc_lrck,
				aud_adc_dat  	=> aud_adc_dat,
				aud_dac_lrck 	=> aud_dac_lrck,
				aud_dac_dat  	=> aud_dac_dat,
				i2c_sdat     	=> i2c_sdat,
				i2c_sclk     	=> i2c_sclk
			);
	end generate audio_gen;
	
	ir_gen : if CV_EN_IR = 1 generate
		ir_inst : infrared
			generic map (
				SIMULATION 		=> SIMULATION
			)
			port map (
				-- global
				clock 			=> clk_50,
				reset_n  		=> reset_n_intern,
				-- bus interface
				iobus_cs		=> ir_cs,
				iobus_wr		=> ir_wr,
				iobus_addr		=> ir_addr,
				iobus_din		=> ir_din,
				iobus_dout		=> ir_dout,
				-- IRQ handling
				iobus_irq_rx	=> ir_irq_rx,
				iobus_ack_rx	=> ir_ack_rx,
				-- connection to ir-receiver
				irda_rxd 		=> irda_rxd
			);
	end generate ir_gen;
	
	lcd_gen : if CV_EN_LCD = 1 generate 
		lcd_inst : lcd
			generic map (
				SIMULATION 		=> SIMULATION
			)
			port map (
				-- global signals
				clock			=> clk_50,
				reset_n			=> reset_n_intern,
				-- bus interface
				iobus_cs		=> lcd_cs,
				iobus_wr		=> lcd_wr,
				iobus_addr		=> lcd_addr,
				iobus_din		=> lcd_din,
				iobus_dout		=> lcd_dout,
				-- IRQ handling
				iobus_irq_rdy	=> lcd_irq_rdy,
				iobus_ack_rdy	=> lcd_ack_rdy,
				-- display signals
				disp_en			=> lcd_en,
				disp_rs			=> lcd_rs,
				disp_rw			=> lcd_rw,
				disp_dat		=> lcd_dat,
				disp_pwr		=> lcd_on,
				disp_blon		=> lcd_blon
			);
	end generate lcd_gen;
	
	sram_gen : if CV_EN_SRAM = 1 generate
		sram_inst : sram
			port map (
				-- global signals
				clock		=> clk_50,
				reset_n		=> reset_n_intern,
				-- bus interface
				iobus_cs	=> sram_cs,
				iobus_wr	=> sram_wr,
				iobus_addr	=> sram_adr,
				iobus_din	=> sram_din,
				iobus_dout	=> sram_dout,
				-- sram connections
				sram_ce_n	=> sram_ce_n,
				sram_oe_n	=> sram_oe_n,
				sram_we_n	=> sram_we_n,
				sram_ub_n	=> sram_ub_n,
				sram_lb_n	=> sram_lb_n,
				sram_addr	=> sram_addr,
				sram_dq		=> sram_dq
			);
	end generate sram_gen;
	
	uart_gen : if CV_EN_UART = 1 generate
		uart_inst : uart
			generic map (
				SIMULATION 	=> SIMULATION
			)
			port map (
				-- global signals
				clock			=> clk_50,
				reset_n			=> reset_n_intern,
				-- bus interface
				iobus_cs		=> uart_cs,
				iobus_wr		=> uart_wr,
				iobus_addr		=> uart_addr,
				iobus_din		=> uart_din,
				iobus_dout		=> uart_dout,
				-- IRQ handling
				iobus_irq_rx	=> uart_irq_rx,
				iobus_irq_tx	=> uart_irq_tx,
				iobus_ack_rx	=> uart_ack_rx,
				iobus_ack_tx	=> uart_ack_tx,
				-- pins to outside 
				rts				=> uart_rts,
				cts				=> uart_cts,
				rxd				=> uart_rxd,
				txd				=> uart_txd
			);
	end generate uart_gen;	
	
end rtl;