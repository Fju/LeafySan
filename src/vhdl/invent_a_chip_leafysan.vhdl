----------------------------------------------------------------------
-- Project		:	LeafySan
-- Module		:	Main module
-- Authors		:	Florian Winkler
-- Lust update	:	03.09.2017
-- Description	:	Connects all modules with external stuff (switches, gpio pins, LED's)
--					Furthermore it displays all read sensor values on a LCD and a 7-Segment Display
--					Also sends data via UART to a microcomputer
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

	component adc_sensors is
		port (
			clock			: in  std_ulogic;
			reset			: in  std_ulogic;
			temperature		: out unsigned(11 downto 0);
			carbondioxide	: out unsigned(13 downto 0);
			adc_dac_cs 	 	: out std_ulogic;
			adc_dac_wr 	 	: out std_ulogic;
			adc_dac_addr 	: out std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0);
			adc_dac_din  	: in  std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
			adc_dac_dout 	: out std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0)
		);
	end component adc_sensors;

	component light_sensor is
		generic (
			CYCLE_TICKS			: natural	:= 50000000
		);
		port (
			clock				: in  std_ulogic;
			reset				: in  std_ulogic;
			i2c_clk_ctrl 		: out std_ulogic;
			i2c_clk_in 			: in  std_ulogic;
			i2c_clk_out 		: out std_ulogic;
			i2c_dat_ctrl 		: out std_ulogic;
			i2c_dat_in 			: in  std_ulogic;
			i2c_dat_out 		: out std_ulogic;
			value				: out unsigned(15 downto 0);
			enabled				: in  std_ulogic
		);
	end component light_sensor;
	
	component moisture_sensor is
		generic (
			CYCLE_TICKS			: natural	:= 50000000
		);
		port (
			clock				: in  std_ulogic;
			reset				: in  std_ulogic;
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
	end component moisture_sensor;
	
	component peripherals is
		port(
			clock				: in  std_ulogic;
			reset				: in  std_ulogic;
			temperature			: in  unsigned(11 downto 0);
			brightness			: in  unsigned(15 downto 0);
			moisture			: in  unsigned(15 downto 0);
			lighting_on			: out std_ulogic;
			heating_on			: out std_ulogic;
			watering_on			: out std_ulogic;
			ventilation_on		: out std_ulogic;
			heating_thresh		: in  unsigned(11 downto 0);
			lighting_thresh		: in  unsigned(15 downto 0);
			watering_thresh		: in  unsigned(15 downto 0)
		);
	end component peripherals;
	

	constant SENSOR_CYCLE_TICKS		: natural := 50000000; -- 1s	
	constant LCD_CLOCK_TICKS		: natural := 10000000;	-- 200ms
	constant SEG_CLOCK_TICKS		: natural := 12500000;	-- 250ms
	constant UART_WR_BYTE_COUNT		: natural := 13;
	constant UART_RD_BYTE_COUNT		: natural := 9;
	constant UART_DATA_WIDTH		: natural := 6;
	constant WARNING_CLOCK_TICKS	: natural := 37500000;	-- 750ms


	-- state definitions
	type lcd_state_t is (S_LCD_WAIT, S_LCD_DISPLAY);
	type seg_state_t is (S_SEG_WAIT, S_SEG_DISPLAY_DEC, S_SEG_DISPLAY_HEX);
	type uart_state_t is (S_UART_RD_WAIT_START, S_UART_RD_READ_LOOP, S_UART_WR_START, S_UART_WR_WRITE_LOOP, S_UART_WR_END);
	type sensor_state_t is (S_SENS_LIGHT, S_SENS_MOIST);
	-- state registers
	signal lcd_state, lcd_state_nxt			: lcd_state_t;
	signal seg_state, seg_state_nxt			: seg_state_t;
	signal uart_state, uart_state_nxt		: uart_state_t;
	signal sensor_state, sensor_state_nxt	: sensor_state_t;

	
	-- seven-segment registers
	signal seg_clock, seg_clock_nxt	: unsigned(to_log2(SEG_CLOCK_TICKS) - 1 downto 0);

	
	-- LCD registers
	signal lcd_clock, lcd_clock_nxt	: unsigned(to_log2(LCD_CLOCK_TICKS) - 1 downto 0);
	signal lcd_cmds, lcd_cmds_nxt 	: lcd_commands_t(0 to 32);
	-- amount of bytes sent to determine whether all data has been sent already
	signal lcd_sent_chars, lcd_sent_chars_nxt : unsigned(to_log2(lcd_cmds'length) - 1 downto 0);

	
	-- UART registers
	signal uart_sent_bytes, uart_sent_bytes_nxt			: unsigned(to_log2(UART_WR_BYTE_COUNT) - 1 downto 0);
	signal uart_received_bytes, uart_received_bytes_nxt	: unsigned(to_log2(UART_RD_BYTE_COUNT) - 1 downto 0);
	type uart_protocol_entry_t is record
		cmd	: std_ulogic_vector(1 downto 0);
		data	: std_ulogic_vector(5 downto 0);
	end record;
	type uart_protocol_array is array (natural range <>) of uart_protocol_entry_t;
	signal uart_wr_array, uart_wr_array_nxt			: uart_protocol_array(0 to UART_WR_BYTE_COUNT - 1);
	signal uart_rd_array, uart_rd_array_nxt			: uart_protocol_array(0 to UART_RD_BYTE_COUNT - 1);



	-- signals for `adc_sensors` component
	signal adc_temperature		: unsigned(11 downto 0);
	signal adc_carbondioxide	: unsigned(13 downto 0);


	-- signals for `light_sensor` component
	signal light_clk_ctrl, light_dat_ctrl	: std_ulogic;
	signal light_clk_in, light_dat_in		: std_ulogic;
	signal light_clk_out, light_dat_out		: std_ulogic;
	signal light_enabled					: std_ulogic;
	signal light_value						: unsigned(15 downto 0);

	
	-- signals for `moisture_sensor` component
	signal moist_clk_ctrl, moist_dat_ctrl	: std_ulogic;
	signal moist_clk_in, moist_dat_in		: std_ulogic;
	signal moist_clk_out, moist_dat_out		: std_ulogic;
	signal moist_enabled					: std_ulogic;
	signal moist_moisture					: unsigned(15 downto 0);
	signal moist_temperature				: unsigned(15 downto 0);
	signal moist_address					: unsigned(6 downto 0);
	
	-- signals for `peripherals` component
	signal peripherals_heating_on			: std_ulogic;
	signal peripherals_watering_on			: std_ulogic;
	signal peripherals_lighting_on			: std_ulogic;
	signal peripherals_ventilation_on		: std_ulogic;

	signal heating_thresh, heating_thresh_nxt		: unsigned(11 downto 0);
	signal lighting_thresh, lighting_thresh_nxt		: unsigned(15 downto 0);
	signal watering_thresh, watering_thresh_nxt		: unsigned(15 downto 0);
	
	-- registers to create blinking led effect
	signal warning_clock, warning_clock_nxt	: unsigned(to_log2(WARNING_CLOCK_TICKS) - 1 downto 0);
	signal warning_led, warning_led_nxt		: std_ulogic;
begin
	-- map all component signals to internal signals
	adc_sensors_inst : adc_sensors
		port map (
			clock			=> clock,
			reset			=> reset,
			temperature		=> adc_temperature,
			carbondioxide	=> adc_carbondioxide,
			adc_dac_cs 	 	=> adc_dac_cs,
			adc_dac_wr 		=> adc_dac_wr,
			adc_dac_addr 	=> adc_dac_addr,
			adc_dac_din  	=> adc_dac_din,
			adc_dac_dout 	=> adc_dac_dout
		);
	light_sensor_inst : light_sensor
		generic map (
			CYCLE_TICKS		=> SENSOR_CYCLE_TICKS
		)
		port map (
			clock			=> clock,
			reset			=> reset,
			i2c_clk_ctrl	=> light_clk_ctrl,
			i2c_clk_in		=> light_clk_in,
			i2c_clk_out		=> light_clk_out,
			i2c_dat_ctrl	=> light_dat_ctrl,
			i2c_dat_in		=> light_dat_in,
			i2c_dat_out		=> light_dat_out,
			value			=> light_value,
			enabled			=> light_enabled
		);
	moisture_sensor_inst : moisture_sensor
		generic map (
			CYCLE_TICKS		=> SENSOR_CYCLE_TICKS
		)
		port map (
			clock			=> clock,
			reset			=> reset,
			i2c_clk_ctrl	=> moist_clk_ctrl,
			i2c_clk_in		=> moist_clk_in,
			i2c_clk_out		=> moist_clk_out,
			i2c_dat_ctrl	=> moist_dat_ctrl,
			i2c_dat_in		=> moist_dat_in,
			i2c_dat_out		=> moist_dat_out,
			moisture		=> moist_moisture,
			temperature		=> moist_temperature,
			address			=> moist_address,
			enabled			=> moist_enabled
		);
	peripherals_inst : peripherals
		port map (
			clock			=> clock,
			reset			=> reset,
			temperature		=> adc_temperature,
			brightness		=> light_value,
			moisture		=> moist_moisture,
			lighting_on		=> peripherals_lighting_on,
			heating_on		=> peripherals_heating_on,
			watering_on		=> peripherals_watering_on,
			ventilation_on	=> peripherals_ventilation_on,
			heating_thresh	=> heating_thresh,
			lighting_thresh	=> lighting_thresh,
			watering_thresh	=> watering_thresh
		);


	-- sequential process
	process(clock, reset)
	begin
		if reset = '1' then
			lcd_state			<= S_LCD_WAIT;
			lcd_clock			<= (others => '0');
			lcd_cmds			<= (others => (others => '0'));
			lcd_sent_chars		<= (others => '0');
			seg_state			<= S_SEG_WAIT;
			seg_clock			<= (others => '0');
			uart_state			<= S_UART_RD_WAIT_START;
			uart_wr_array		<= (others => (others => (others => '0')));
			uart_rd_array		<= (others => (others => (others => '0')));
			uart_sent_bytes		<= (others => '0');
			uart_received_bytes	<= (others => '0');
			warning_clock		<= (others => '0');
			warning_led			<= '0';
			-- set thresholds to default value
			heating_thresh		<= to_unsigned(220, heating_thresh'length);  -- 22,0 °C
			lighting_thresh		<= to_unsigned(400, lighting_thresh'length); -- 400 lx
			watering_thresh		<= to_unsigned(500, watering_thresh'length); -- 50,0 %
		elsif rising_edge(clock) then
			lcd_state			<= lcd_state_nxt;
			lcd_clock			<= lcd_clock_nxt;
			lcd_cmds			<= lcd_cmds_nxt;
			lcd_sent_chars		<= lcd_sent_chars_nxt;
			seg_state			<= seg_state_nxt;
			seg_clock			<= seg_clock_nxt;
			uart_state			<= uart_state_nxt;
			uart_wr_array		<= uart_wr_array_nxt;
			uart_rd_array		<= uart_rd_array_nxt;
			uart_sent_bytes		<= uart_sent_bytes_nxt;
			uart_received_bytes	<= uart_received_bytes_nxt;
			warning_clock		<= warning_clock_nxt;
			warning_led			<= warning_led_nxt;
			heating_thresh		<= heating_thresh_nxt;
			lighting_thresh		<= lighting_thresh_nxt;
			watering_thresh		<= watering_thresh_nxt;
		end if;
	end process;

	-- GPIO process
	process(peripherals_ventilation_on, peripherals_heating_on, peripherals_lighting_on, peripherals_watering_on,
			moist_clk_ctrl, moist_clk_in, moist_clk_out, moist_dat_ctrl, moist_dat_in, moist_dat_out,
			light_clk_ctrl, light_clk_in, light_clk_out, light_dat_ctrl, light_dat_in, light_dat_out,
			warning_clock, warning_led, gp_in, switch)
	begin
		-- safety / development / debug switches
		led_green(0)	<= switch(0);
		led_green(1)	<= not(gp_in(8));
		-- automatic / manual peripherals control switch
		led_green(2)	<= switch(1);
		
		led_red 		<= (others => '0'); -- default assignment
		
		-- i2c connections
		light_enabled		<= '1'; -- for debugging purpose
		gp_ctrl(1 downto 0)	<= light_clk_ctrl & light_dat_ctrl;
		gp_out(1 downto 0)	<= light_clk_out & light_dat_out;
		light_clk_in		<= gp_in(1);
		light_dat_in		<= gp_in(0);
		moist_enabled		<= '1'; -- for debugging purpose
		gp_ctrl(3 downto 2)	<= moist_clk_ctrl & moist_dat_ctrl;
		gp_out(3 downto 2)	<= moist_clk_out & moist_dat_out;
		moist_clk_in		<= gp_in(3);
		moist_dat_in		<= gp_in(2);	
		
		-- setup pin mode: 1 input (safety switch), 4 outputs (relais control)
		gp_ctrl(8 downto 4)	<= "01111";
		-- disable all relais by default
		gp_out(7 downto 4)	<= not("0000");
		
		warning_led_nxt		<= warning_led;
		warning_clock_nxt	<= warning_clock;				
		if gp_in(8) = '1' or switch(0) = '1' then
			warning_led_nxt		<= '0';
			warning_clock_nxt	<= (others => '0');			
			if switch(1) = '0' then
				-- automatic GPIO outputs
				-- Map: GPIO_4 -> IN1 (lighting), GPIO_5 -> IN2 (watering), GPIO_6 -> IN3 (ventilation), GPIO_7 -> IN4 (heating)
				-- relais needs '1' for off and '0' for on, that's why `not(...)` is used
				gp_out(7 downto 4) 	<= not(peripherals_heating_on & peripherals_ventilation_on & peripherals_watering_on & peripherals_lighting_on);
				led_red(3 downto 0)	<= peripherals_heating_on & peripherals_ventilation_on & peripherals_watering_on & peripherals_lighting_on;
			else
				-- manual GPIO outputs
				gp_out(7 downto 4)	<= not(switch(5 downto 2));
				led_red(3 downto 0)	<= switch(5 downto 2);
			end if;
		else
			-- generate blinking led row when safety switch is off
			led_red <= (others => warning_led); -- all on or all off
			if warning_clock = to_unsigned(WARNING_CLOCK_TICKS - 1, warning_clock'length) then
				warning_clock_nxt	<= (others => '0');
				if warning_led = '1' then
					warning_led_nxt <= '0';
				else
					warning_led_nxt <= '1';
				end if;
			else
				warning_clock_nxt <= warning_clock + to_unsigned(1, warning_clock'length);
			end if;
		end if;
		
		--
		gp_ctrl(15 downto 9)	<= (others => '0');
		gp_out(15 downto 8)		<= (others => '0');
		led_green(8 downto 3)	<= (others => '0');
	end process;
	
	-- LCD process
	process(key, adc_dac_din, lcd_state, lcd_clock, lcd_irq_rdy, lcd_cmds, lcd_sent_chars, moist_moisture, moist_temperature, light_value, adc_carbondioxide,
			lighting_thresh, watering_thresh, heating_thresh)
		-- variables for converting numbers into lcd_cmds
		variable mst_bcd_value	: unsigned(15 downto 0) := (others => '0');
		variable tmp_bcd_value	: unsigned(15 downto 0) := (others => '0');
		variable lux_bcd_value	: unsigned(19 downto 0) := (others => '0');
		variable co2_bcd_value	: unsigned(15 downto 0) := (others => '0');
		variable mst_bcd_thresh	: unsigned(11 downto 0) := (others => '0');
		variable tmp_bcd_thresh	: unsigned(11 downto 0) := (others => '0');
		variable lux_bcd_thresh	: unsigned(19 downto 0) := (others => '0');
		variable lcd_cmds_mst	: std_ulogic_vector(55 downto 0) := (others => '0');
		variable lcd_cmds_tmp	: std_ulogic_vector(55 downto 0) := (others => '0');
		variable lcd_cmds_lux	: std_ulogic_vector(63 downto 0) := (others => '0');
		variable lcd_cmds_co2	: std_ulogic_vector(55 downto 0) := (others => '0');
		variable lcd_thresh_mst	: std_ulogic_vector(31 downto 0) := (others => '0');
		variable lcd_thresh_tmp	: std_ulogic_vector(31 downto 0) := (others => '0');
		variable lcd_thresh_lux	: std_ulogic_vector(39 downto 0) := (others => '0');
	begin	
		-- hold values of all registers by default
		lcd_state_nxt		<= lcd_state;
		lcd_clock_nxt		<= lcd_clock;
		lcd_cmds_nxt		<= lcd_cmds;
		lcd_sent_chars_nxt	<= lcd_sent_chars;

		-- default assignments for the LCD module
		lcd_cs			<= '0';
		lcd_wr			<= '0';
		lcd_addr		<= (others => '0');
		lcd_dout		<= (others => '0');
		lcd_ack_rdy		<= '0';

		case lcd_state is
			when S_LCD_WAIT =>
				-- increment counter value
				lcd_clock_nxt <= lcd_clock + to_unsigned(1, lcd_clock'length);
				if lcd_clock >= to_unsigned(LCD_CLOCK_TICKS, lcd_clock'length) then
					-- switch state after 10000000 "clocks" (200 ms)
					lcd_clock_nxt 		<= (others => '0');
					lcd_sent_chars_nxt	<= (others => '0');

					-- convert binary values into x decimal numbers
					mst_bcd_value	:= unsigned(to_bcd(std_ulogic_vector(moist_moisture), 4));
					tmp_bcd_value	:= unsigned(to_bcd(std_ulogic_vector(moist_temperature), 4));
					lux_bcd_value	:= unsigned(to_bcd(std_ulogic_vector(light_value), 5));
					co2_bcd_value	:= unsigned(to_bcd(std_ulogic_vector(adc_carbondioxide), 4));
					mst_bcd_thresh	:= unsigned(to_bcd(std_ulogic_vector(watering_thresh), 3));
					tmp_bcd_thresh	:= unsigned(to_bcd(std_ulogic_vector(heating_thresh), 3));
					lux_bcd_thresh	:= unsigned(to_bcd(std_ulogic_vector(lighting_thresh), 5));

					-- ascii storages
					lcd_cmds_mst	:= asciitext("M: ") & ascii(mst_bcd_value(15 downto 12)) & ascii(mst_bcd_value(11 downto 8)) & ascii(mst_bcd_value(7 downto 4)) & ascii(mst_bcd_value(3 downto 0));
					lcd_cmds_tmp	:= asciitext("T: ") & ascii(tmp_bcd_value(15 downto 12)) & ascii(tmp_bcd_value(11 downto 8)) & ascii(tmp_bcd_value(7 downto 4)) & ascii(tmp_bcd_value(3 downto 0));
					lcd_cmds_lux	:= asciitext("L: ") & ascii(lux_bcd_value(19 downto 16)) & ascii(lux_bcd_value(15 downto 12)) & ascii(lux_bcd_value(11 downto 8)) & ascii(lux_bcd_value(7 downto 4)) & ascii(lux_bcd_value(3 downto 0));
					lcd_cmds_co2	:= asciitext("C: ") & ascii(co2_bcd_value(15 downto 12)) & ascii(co2_bcd_value(11 downto 8)) & ascii(co2_bcd_value(7 downto 4)) & ascii(co2_bcd_value(3 downto 0));
					lcd_thresh_mst	:= ascii(mst_bcd_thresh(11 downto 8)) & ascii(mst_bcd_thresh(7 downto 4)) & asciitext(".") & ascii(mst_bcd_thresh(3 downto 0));
					lcd_thresh_tmp	:= ascii(tmp_bcd_thresh(11 downto 8)) & ascii(tmp_bcd_thresh(7 downto 4)) & asciitext(".") & ascii(tmp_bcd_thresh(3 downto 0));
					lcd_thresh_lux	:= ascii(lux_bcd_value(19 downto 16)) & ascii(lux_bcd_thresh(15 downto 12)) & ascii(lux_bcd_thresh(11 downto 8)) & ascii(lux_bcd_thresh(7 downto 4)) & ascii(lux_bcd_thresh(3 downto 0));
					-- set next lcd commands that will be displayed
					if key(1) = '0' then
						lcd_cmds_nxt	<= lcd_cmd(lcd_cursor_pos(0, 0) & lcd_cmds_mst & asciitext("  ") & lcd_cmds_co2 & lcd_cmds_lux & asciitext(" ") & lcd_cmds_tmp);
					else
						lcd_cmds_nxt	<= lcd_cmd(lcd_cursor_pos(0, 0) & asciitext("Thresh (L,M,T)") & asciitext("  ") & lcd_thresh_lux & asciitext(" ") & lcd_thresh_mst & asciitext(" ") & lcd_thresh_tmp & asciitext(" "));
					end if;
					-- change state in order to display it/send it to the LCD
					lcd_state_nxt 	<= S_LCD_DISPLAY;
				end if;
			when S_LCD_DISPLAY =>
				if lcd_irq_rdy = '1' then
					-- enable Chip Select, Write Mode and acknowledge ready
					lcd_cs <= '1';
					lcd_wr <= '1';
					lcd_ack_rdy <= '1';
					lcd_addr	<= CV_ADDR_LCD_DATA;
					-- send one byte of date
					lcd_dout(7 downto 0) <= lcd_cmds(to_integer(lcd_sent_chars));

					-- check whether all characters have already been sent
					if lcd_sent_chars = to_unsigned(lcd_cmds'length - 1, lcd_sent_chars'length) then
						-- all characters have been sent, so switch state back to S_WAIT
						lcd_state_nxt <= S_LCD_WAIT;
					else
						-- increment `lcd_sent_chars` in order to send the next character
						lcd_sent_chars_nxt <= lcd_sent_chars + to_unsigned(1, lcd_sent_chars'length);
					end if;
				end if;
		end case;
	end process;
	
	-- UART process
	process(uart_state, uart_wr_array, uart_rd_array, uart_sent_bytes, uart_received_bytes, uart_irq_tx, uart_irq_rx, uart_din,
		peripherals_ventilation_on, peripherals_heating_on, peripherals_lighting_on, peripherals_watering_on,  moist_moisture, moist_temperature, light_value, adc_carbondioxide,
		heating_thresh, lighting_thresh, watering_thresh)
		constant VALUE_COUNT	: natural := 5; -- amount of data segments (four segments for each sensor + one segment including all states (on/off) of peripherals)
		constant SEGMENT_COUNT	: natural := 3; -- 3 bytes per "segment"
		variable i, j			: natural := 0; -- loop variables
		variable segment_cmd	: std_ulogic_vector(1 downto 0);
		variable segment_data	: std_ulogic_vector(SEGMENT_COUNT * UART_DATA_WIDTH - 1 downto 0);
		variable item			: uart_protocol_entry_t;
		variable segment_value	: std_ulogic_vector(15 downto 0);
	begin
		uart_cs			<= '0';
		uart_wr			<= '0';
		uart_addr		<= (others => '0');
		uart_dout		<= (others => '0');
		uart_ack_rx  	<= '0';
		uart_ack_tx  	<= '0';

		-- hold values		
		uart_state_nxt			<= uart_state;
		uart_sent_bytes_nxt		<= uart_sent_bytes;
		uart_received_bytes_nxt	<= uart_received_bytes;
		uart_rd_array_nxt		<= uart_rd_array;
		uart_wr_array_nxt		<= uart_wr_array;
		lighting_thresh_nxt		<= lighting_thresh;
		watering_thresh_nxt		<= watering_thresh;
		heating_thresh_nxt		<= heating_thresh;

		case uart_state is
			when S_UART_RD_WAIT_START =>
				if uart_irq_rx = '1' then 
					uart_cs <= '1';
					uart_addr <= CV_ADDR_UART_DATA_RX;
					uart_wr	<= '0';
					-- save data
					if uart_din(7 downto 0) = "01000000" then
						uart_received_bytes_nxt <= to_unsigned(0, uart_received_bytes'length);
						uart_rd_array_nxt	<= (others => (others => (others => '0')));
						uart_state_nxt		<= S_UART_RD_READ_LOOP;
					end if;
				end if;
			when S_UART_RD_READ_LOOP =>
				if uart_irq_rx = '1' then 
					uart_cs <= '1';
					uart_addr <= CV_ADDR_UART_DATA_RX;
					uart_wr	<= '0';
					
					-- increment counter	
					uart_received_bytes_nxt	<= uart_received_bytes + to_unsigned(1, uart_received_bytes'length);
					if uart_din(7 downto 0) = "00111111" then
						-- received end command
						if uart_received_bytes = to_unsigned(UART_RD_BYTE_COUNT, uart_received_bytes'length) then
							for i in 0 to 2 loop
								if uart_rd_array(i*3).cmd = "10" or uart_rd_array(i*3).cmd = "11" then
									segment_value := uart_rd_array(i*3).data & uart_rd_array(i*3+1).data & uart_rd_array(i*3+2).data(5 downto 2);
									if uart_rd_array(i*3+2).data(1 downto 0) = "00" then
										lighting_thresh_nxt	<= unsigned(segment_value);
									elsif uart_rd_array(i*3+2).data(1 downto 0) = "01" then
										watering_thresh_nxt	<= unsigned(segment_value);
									elsif uart_rd_array(i*3+2).data(1 downto 0) = "10" then
										heating_thresh_nxt	<= resize(unsigned(segment_value), heating_thresh'length);
									end if;
								end if;
							end loop;
						end if;
						uart_state_nxt	<= S_UART_WR_START;
					else						
						uart_rd_array_nxt(to_integer(uart_received_bytes)) <= (
							uart_din(7 downto 6),	-- cmd
							uart_din(5 downto 0)		-- data
						); 
					end if;
				end if;
			when S_UART_WR_START =>
				if uart_irq_tx = '1' then					
					uart_cs		<= '1';
					uart_addr	<= CV_ADDR_UART_DATA_TX;
					uart_wr		<= '1';
					-- write `start` cmd
					uart_dout(7 downto 0)	<= "01000000";
					
					-- assign sensor values to protocol
					for i in 0 to VALUE_COUNT - 1 loop
						if i = 0 then
							segment_cmd	:= "10";
							segment_data	:= std_ulogic_vector(resize(light_value, segment_data'length - 2)) & "00";
						elsif i = 1 then
							segment_cmd	:= "11";
							segment_data	:= std_ulogic_vector(moist_moisture) & "01";
						elsif i = 2 then
							segment_cmd	:= "10";
							segment_data	:= std_ulogic_vector(moist_temperature) & "10";
						elsif i = 3 then
							segment_cmd	:= "11";
							segment_data	:= std_ulogic_vector(resize(adc_carbondioxide, segment_data'length - 2)) & "11";
						else
							segment_cmd	:= "10";
							segment_data	:= std_ulogic_vector(resize(unsigned'(peripherals_lighting_on & peripherals_watering_on & peripherals_heating_on & peripherals_ventilation_on & "00"), segment_data'length));
						end if;
						for j in 0 to SEGMENT_COUNT - 1 loop
							if i < 4 or j = 0 then
								uart_wr_array_nxt(j + i * SEGMENT_COUNT) <= (
									segment_cmd, -- cmd
									std_ulogic_vector(resize(shift_right(unsigned(segment_data), (2 - j) * UART_DATA_WIDTH), UART_DATA_WIDTH)) -- data
								);
							end if;
						end loop;
					end loop;

					uart_state_nxt <= S_UART_WR_WRITE_LOOP;
				end if;
			when S_UART_WR_WRITE_LOOP =>
				if uart_irq_tx = '1' then
					uart_cs		<= '1';
					uart_addr	<= CV_ADDR_UART_DATA_TX;
					uart_wr		<= '1';

					item := uart_wr_array(to_integer(uart_sent_bytes));
					uart_dout(7 downto 0)	<= item.cmd & item.data;

					if uart_sent_bytes = to_unsigned(UART_WR_BYTE_COUNT - 1, uart_sent_bytes'length) then
						-- last byte sent
						uart_sent_bytes_nxt	<= (others => '0'); -- reset counter
						uart_state_nxt			<= S_UART_WR_END;
					else
						-- increment counter
						uart_sent_bytes_nxt	<= uart_sent_bytes + to_unsigned(1, uart_sent_bytes'length);
					end if;
				end if;
			when S_UART_WR_END =>
				if uart_irq_tx = '1' then
					uart_cs		<= '1';
					uart_addr	<= CV_ADDR_UART_DATA_TX;
					uart_wr		<= '1';
					-- write `end` cmd
					uart_dout(7 downto 0)	<= "00111111";

					uart_state_nxt <= S_UART_RD_WAIT_START;
				end if;
		end case;
	end process;

	-- Seven Segment process
	process(seg_state, seg_clock, adc_temperature, moist_address)
	begin
		seg_state_nxt	<= seg_state;
		seg_clock_nxt	<= seg_clock;

		sevenseg_cs		<= '0';
		sevenseg_wr		<= '0';
		sevenseg_addr	<= CV_ADDR_SEVENSEG_DEC;
		sevenseg_dout	<= (others => '0');

		case seg_state is
			when S_SEG_WAIT =>
				if seg_clock = to_unsigned(SEG_CLOCK_TICKS - 1, seg_clock'length) then
					seg_clock_nxt	<= (others => '0');
					seg_state_nxt	<= S_SEG_DISPLAY_DEC;
				else
					seg_clock_nxt	<= seg_clock + to_unsigned(1, seg_clock'length);
				end if;
			when S_SEG_DISPLAY_DEC =>
				sevenseg_cs		<= '1';
				sevenseg_wr		<= '1';
				sevenseg_dout	<= std_ulogic_vector(resize(adc_temperature, sevenseg_dout'length));
				seg_state_nxt	<= S_SEG_DISPLAY_HEX;
			when S_SEG_DISPLAY_HEX =>
				sevenseg_cs		<= '1';
				sevenseg_wr		<= '1';
				sevenseg_addr	<= CV_ADDR_SEVENSEG_HEX4 or CV_ADDR_SEVENSEG_HEX5;
				sevenseg_dout	<= std_ulogic_vector("000000000" & moist_address);
				seg_state_nxt	<= S_SEG_WAIT;
		end case;
	end process;

	-- unused signals
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
	sram_cs 		 	<= '0';
	sram_wr 	 		<= '0';
	sram_addr 	 		<= (others => '0');
	sram_dout 	 		<= (others => '0');
end rtl;
