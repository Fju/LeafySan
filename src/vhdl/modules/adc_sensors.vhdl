----------------------------------------------------------------------
-- Project		:	LeafySan
-- Module		:	ADC Sensor Module
-- Authors		:	Florian Winkler
-- Lust update	:	01.09.2017
-- Description	:	Reads voltage of analogue sensors through ADC's and converts them into unit dependent digital values
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity adc_sensors is
	port(
		clock				: in  std_ulogic;
		reset				: in  std_ulogic;
		temperature			: out unsigned(11 downto 0);
		carbondioxide		: out unsigned(13 downto 0);
		-- ADC/DAC
		adc_dac_cs 	 		: out std_ulogic;
		adc_dac_wr 	 		: out std_ulogic;
		adc_dac_addr 		: out std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0);
		adc_dac_din  		: in  std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
		adc_dac_dout 		: out std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0)
	);
end adc_sensors;

architecture rtl of adc_sensors is
	constant READ_CLOCK_COUNT			: natural := 1953125; -- 39,0625ms (5s / 128)
	constant READ_ITEM_COUNT			: natural := 128;
	constant ADC_RESOLUTION				: natural := 12; -- 12 bit
	
	type adc_state_t is (S_ADC_INIT, S_ADC_WAIT, S_ADC_READ_TEMP, S_ADC_READ_CO2);
	signal adc_state, adc_state_nxt		: adc_state_t;	
	
	signal adc_clock, adc_clock_nxt		: unsigned(to_log2(READ_CLOCK_COUNT) - 1 downto 0);
	
	signal temp_value, temp_value_nxt	: std_ulogic_vector(29 downto 0);
	signal temp_sum, temp_sum_nxt		: unsigned(ADC_RESOLUTION + to_log2(READ_ITEM_COUNT + 1) - 1 downto 0);
	signal temp_cnt, temp_cnt_nxt		: unsigned(to_log2(READ_ITEM_COUNT + 1) - 1 downto 0);
	
	signal co2_value, co2_value_nxt		: std_ulogic_vector(26 downto 0);
	signal co2_sum, co2_sum_nxt			: unsigned(ADC_RESOLUTION + to_log2(READ_ITEM_COUNT + 1) - 1 downto 0);
	signal co2_cnt, co2_cnt_nxt			: unsigned(to_log2(READ_ITEM_COUNT + 1) - 1 downto 0);
	
	signal temp, temp_nxt		: unsigned(11 downto 0);
	signal co2, co2_nxt			: unsigned(13 downto 0);
begin


	-- sequential process
	process(clock, reset)
	begin
		if reset = '1' then
			adc_state		<= S_ADC_INIT;
			adc_clock		<= (others => '0');
			temp_value		<= (others => '0');
			temp_sum		<= (others => '0');
			temp_cnt		<= (others => '0');
			co2_value		<= (others => '0');
			co2_sum			<= (others => '0');
			co2_cnt			<= (others => '0');
			temp			<= (others => '0');
			co2				<= (others => '0');
		elsif rising_edge(clock) then
			adc_state		<= adc_state_nxt;
			adc_clock		<= adc_clock_nxt;
			temp_value		<= temp_value_nxt;
			temp_cnt		<= temp_cnt_nxt;
			temp_sum		<= temp_sum_nxt;
			co2_value		<= co2_value_nxt;
			co2_cnt			<= co2_cnt_nxt;
			co2_sum			<= co2_sum_nxt;
			temp			<= temp_nxt;
			co2				<= co2_nxt;
		end if;
	end process;
	
	
	process(co2, temp, adc_state, adc_clock, temp_value, temp_cnt, temp_sum, co2_value, co2_sum, co2_cnt, adc_dac_din)
	begin
		-- hold previous values by default
		adc_state_nxt	<= adc_state;
		adc_clock_nxt	<= adc_clock;
		temp_value_nxt	<= temp_value;
		temp_cnt_nxt	<= temp_cnt;
		temp_sum_nxt	<= temp_sum;
		co2_value_nxt	<= co2_value;
		co2_cnt_nxt		<= co2_cnt;
		co2_sum_nxt		<= co2_sum;
		
		temp_nxt		<= temp;
		co2_nxt			<= co2;
		
		-- default assignments for the DAC/ADC module
		adc_dac_cs 	 		<= '0';
		adc_dac_wr 	 		<= '0';
		adc_dac_addr 		<= (others => '0');
		adc_dac_dout 		<= (others => '0');
		
		temperature			<= temp;
		carbondioxide		<= co2;
		
		case adc_state is
			when S_ADC_INIT =>
				-- activate ADC channels
				adc_dac_cs		<= '1';
				adc_dac_wr		<= '1';
				adc_dac_addr	<= CV_ADDR_ADC_DAC_CTRL;
				adc_dac_dout(9 downto 0) <= "0011111111";
				-- next state
				adc_state_nxt	<= S_ADC_WAIT;
				
			when S_ADC_WAIT =>
				adc_clock_nxt	<= adc_clock + to_unsigned(1, adc_clock'length);
				if adc_clock = to_unsigned(READ_CLOCK_COUNT - 1, adc_clock'length) then
					-- switch state after 50 million clocks (1s @ speed = 1)
					adc_clock_nxt	<= (others => '0');
					adc_state_nxt	<= S_ADC_READ_TEMP;
					
					temp_nxt	<= resize(shift_right(unsigned(temp_value) * 74043 + 131072, 18), temp'length);
					co2_nxt		<= resize(shift_right((unsigned(co2_value) - 496) * 82539, 15), co2'length);
				end if;

			when S_ADC_READ_TEMP =>
				adc_dac_cs <= '1';
				adc_dac_wr <= '0';
				adc_dac_addr(3 downto 0)  <= CV_ADDR_ADC0;

				temp_cnt_nxt <= temp_cnt + to_unsigned(1, temp_cnt'length);
				temp_sum_nxt <= temp_sum + resize(unsigned(adc_dac_din(11 downto 0)), temp_sum'length);
				
				if temp_cnt = to_unsigned(READ_ITEM_COUNT - 1, temp_cnt'length) then
					temp_value_nxt	<= std_ulogic_vector(resize(shift_right(temp_sum, to_log2(READ_ITEM_COUNT)), temp_value'length));				
					temp_cnt_nxt 	<= (others => '0');
					temp_sum_nxt 	<= (others => '0');
				end if;				
				adc_state_nxt <= S_ADC_READ_CO2;
				
			when S_ADC_READ_CO2 =>
				adc_dac_cs <= '1';
				adc_dac_wr <= '0';
				adc_dac_addr(3 downto 0)  <= CV_ADDR_ADC1;

				co2_cnt_nxt <= co2_cnt + to_unsigned(1, co2_cnt'length);
				co2_sum_nxt <= co2_sum + resize(unsigned(adc_dac_din(11 downto 0)), co2_sum'length);
				
				if co2_cnt = to_unsigned(READ_ITEM_COUNT - 1, co2_cnt'length) then
					co2_value_nxt	<= std_ulogic_vector(resize(shift_right(co2_sum, to_log2(READ_ITEM_COUNT)), co2_value'length));				
					co2_cnt_nxt 	<= (others => '0');
					co2_sum_nxt 	<= (others => '0');
				end if;				
				adc_state_nxt <= S_ADC_WAIT;
		end case;				
	end process;
	
end rtl;
