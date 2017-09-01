-----------------------------------------------------------------------------------------
-- Project      : 	Invent a Chip
-- Module       : 	ADC/DAC Communication for the extension board
-- Author 		: 	Christian Leibold / Jan Dürre
-- Last update  : 	24.03.2014
-- Description	: 	-
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity adc_dac is
	port (
		-- global signals
		clock			: in  std_ulogic;
		reset_n			: in  std_ulogic;
		-- bus interface
		iobus_cs		: in  std_ulogic;
		iobus_wr		: in  std_ulogic;
		iobus_addr		: in  std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0);
		iobus_din		: in  std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
		iobus_dout		: out std_ulogic_vector(CW_DATA_ADC_DAC-1 downto 0);
		-- adc/dac signals
		-- spi signals
		spi_clk			: out std_ulogic;
		spi_mosi		: out std_ulogic;
		spi_miso		: in  std_ulogic;
		spi_cs_dac_n	: out std_ulogic;
		spi_cs_adc_n	: out std_ulogic;
		-- switch signals
		swt_select		: out std_ulogic_vector(2 downto 0);
		swt_enable_n	: out std_ulogic;
		-- dac Signals
		dac_ldac_n		: out std_ulogic
    );
end adc_dac;

architecture rtl of adc_dac is

	constant MUX_SWITCH_TIME   : natural := 20;
	constant ADC_COOLDOWN_TIME : natural := 4;
	constant DAC_COOLDOWN_TIME : natural := 4;
	
	component spi_master
		port(
			clock			: in  std_ulogic;
			reset_n			: in  std_ulogic;
			spi_clk			: out std_ulogic;
			spi_mosi		: out std_ulogic;
			spi_cs_n		: out std_ulogic_vector(1 downto 0);
			spi_miso		: in  std_logic;
			spi_slaveid		: in  std_ulogic;
			spi_trenable	: in  std_ulogic;
			spi_txdata		: in  std_ulogic_vector(15 downto 0);
			spi_rxdata		: out std_ulogic_vector(15 downto 0);
			spi_trcomplete	: out std_ulogic
		);
	end component spi_master;
	
	signal control_idx, control_idx_nxt : unsigned(to_log2(10)-1 downto 0);
	signal control_reg, control_reg_nxt : std_ulogic_vector(9 downto 0); -- 8 adc + 2 dac
	
	signal dac_control_last, dac_control_last_nxt : std_ulogic_vector(1 downto 0);
	
	type adc_reg_t is array (0 to 7) of std_ulogic_vector(11 downto 0);
	signal adc_reg, adc_reg_nxt : adc_reg_t;
	
	type dac_reg_t is array (0 to 1) of std_ulogic_vector(7  downto 0);
	signal dac_reg, dac_reg_nxt   : dac_reg_t;
	
	
	signal adc_select , adc_select_nxt  : std_ulogic_vector(3 downto 0);
	signal dac_select , dac_select_nxt  : std_ulogic;
	
	signal mux_switch_cnt, mux_switch_cnt_nxt 		: unsigned(to_log2(MUX_SWITCH_TIME)-1 downto 0);
	signal adc_cooldown_cnt, adc_cooldown_cnt_nxt 	: unsigned(to_log2(ADC_COOLDOWN_TIME)-1 downto 0);
	signal dac_cooldown_cnt, dac_cooldown_cnt_nxt 	: unsigned(to_log2(DAC_COOLDOWN_TIME)-1 downto 0);
		
	type state_t is (S_INIT, S_CONTROL, S_ADC_MUX_SWITCH, S_ADC_READ, S_ADC_WAIT, S_ADC_COOLDOWN, S_DAC_SET, S_DAC_WAIT, S_DAC_COOLDOWN, S_DAC_SHUTDOWN);
	signal state, state_nxt : state_t;
	
	signal txdata, rxdata 	: std_ulogic_vector(15 downto 0);
	signal trcomplete	  	: std_ulogic;
	signal slaveid		  	: std_ulogic;
	signal trenable		  	: std_ulogic;
	
	signal mux_select	  	: std_ulogic_vector(2 downto 0);
	
	signal spi_cs_n		  	: std_ulogic_vector(1 downto 0);
	
begin

	spi_inst : spi_master
		port map(
			clock			=> clock,
			reset_n			=> reset_n,
			spi_clk			=> spi_clk,
			spi_mosi		=> spi_mosi,
			spi_cs_n		=> spi_cs_n, 
			spi_miso		=> spi_miso, 
			spi_slaveid		=> slaveid,
			spi_trenable	=> trenable,
			spi_txdata		=> txdata,
			spi_rxdata		=> rxdata,
			spi_trcomplete	=> trcomplete
		);

	spi_cs_adc_n <= spi_cs_n(0);
	spi_cs_dac_n <= spi_cs_n(1);
	
	process(clock, reset_n)
	begin
		if reset_n = '0' then
			control_idx 		<= (others => '0');
			control_reg 		<= (others => '0');
			dac_control_last 	<= (others => '1');
			adc_reg  			<= (others => (others => '0'));
			dac_reg  			<= (others => (others => '0'));
			adc_select 			<= (others => '0');
			dac_select  		<= '0';
			mux_switch_cnt 		<= (others => '0');
			adc_cooldown_cnt 	<= (others => '0');
			dac_cooldown_cnt 	<= (others => '0');
			state 	 			<= S_INIT;
		elsif rising_edge(clock) then
			control_idx 		<= control_idx_nxt;
			control_reg 		<= control_reg_nxt;
			dac_control_last 	<= dac_control_last_nxt;
			adc_reg  			<= adc_reg_nxt;
			dac_reg  			<= dac_reg_nxt;
			adc_select 			<= adc_select_nxt;
			dac_select  		<= dac_select_nxt;
			mux_switch_cnt 		<= mux_switch_cnt_nxt;
			adc_cooldown_cnt 	<= adc_cooldown_cnt_nxt;
			dac_cooldown_cnt 	<= dac_cooldown_cnt_nxt;
			state	 			<= state_nxt;
		end if;
	end process;

	process(state, trcomplete, rxdata, control_idx, control_reg, adc_reg, dac_reg, adc_select, dac_select, mux_switch_cnt, adc_cooldown_cnt, dac_cooldown_cnt, dac_control_last)
	begin
	
		txdata		<= (others => '0');
		trenable	<= '0';
		slaveid		<= '0';
		
		state_nxt    			<= state;
		control_idx_nxt 		<= control_idx;		
		dac_control_last_nxt	<= dac_control_last;
		adc_reg_nxt  			<= adc_reg;
		adc_select_nxt 			<= adc_select;
		dac_select_nxt 			<= dac_select;
		mux_switch_cnt_nxt 		<= mux_switch_cnt;
		adc_cooldown_cnt_nxt 	<= adc_cooldown_cnt;
		dac_cooldown_cnt_nxt 	<= dac_cooldown_cnt;
				
		case state is
			when S_INIT =>
				state_nxt 			<= S_CONTROL;
				control_idx_nxt 	<= (others => '0');
				adc_select_nxt  	<= (others => '0');
				
			when S_CONTROL =>
			
				-- control index counter
				if control_idx < to_unsigned(10-1, control_idx'length) then
					control_idx_nxt <= control_idx + 1;
				else 
					control_idx_nxt <= (others => '0');
				end if;
				
				-- choose next state
				-- adc
				if control_idx < to_unsigned(8, control_idx'length) then
				
					if control_reg(to_integer(control_idx)) = '1' then
						adc_select_nxt <= std_ulogic_vector(control_idx(adc_select'range));
						mux_switch_cnt_nxt <= (others => '0');
						state_nxt <= S_ADC_MUX_SWITCH;
					end if;
					
				-- dac
				else
					
					if control_idx = to_unsigned(8, control_idx'length) then
						if 	control_reg(8) = '0' and dac_control_last(0) = '1' then
							dac_control_last_nxt(0) <= '0';
							state_nxt <= S_DAC_SHUTDOWN;
						elsif control_reg(8) = '1' then
							dac_control_last_nxt(0) <= '1';
							state_nxt <= S_DAC_SET;
						end if;
						dac_select_nxt <= '0';
					else
						if 	control_reg(9) = '0' and dac_control_last(1) = '1' then
							dac_control_last_nxt(1) <= '0';
							state_nxt <= S_DAC_SHUTDOWN;
						elsif control_reg(9) = '1' then
							dac_control_last_nxt(1) <= '1';
							state_nxt <= S_DAC_SET;
						end if;
						dac_select_nxt <= '1';
					end if;
				end if;
							
			when S_ADC_MUX_SWITCH =>
				-- wait for mux to switch
				if mux_switch_cnt < to_unsigned(MUX_SWITCH_TIME,mux_switch_cnt'length) then
					mux_switch_cnt_nxt <= mux_switch_cnt + 1;
				-- start read of adc
				else
					state_nxt <= S_ADC_READ;
				end if;
				
			when S_ADC_READ =>
			
				-- request spi-data from adc
				trenable	<= '1';
				slaveid		<= '0';
				
				state_nxt <= S_ADC_WAIT;
				
			when S_ADC_WAIT => 
			
				-- transfer finished
				if trcomplete = '1' then
					-- save data
					adc_reg_nxt(to_integer(unsigned(adc_select))) <= rxData(12 downto 1);
					-- set cooldown counter
					adc_cooldown_cnt_nxt <= (others => '0');
					state_nxt    <= S_ADC_COOLDOWN;
				end if;
				
			when S_ADC_COOLDOWN =>
			
				-- wait for adc cooldown
				if adc_cooldown_cnt < to_unsigned(ADC_COOLDOWN_TIME, adc_cooldown_cnt'length) then
					adc_cooldown_cnt_nxt <= adc_cooldown_cnt + 1;
				-- back to control state
				else
					state_nxt <= S_CONTROL;
				end if;
				
			when S_DAC_SET =>
			
				trenable	<= '1';
				slaveid		<= '1'; -- DAC
			
				txdata(15) <= dac_select;
				txdata(13) <= '0';
				txdata(12) <= '1';
				
				if dac_select = '0' then 
					txdata(11 downto 4) <= dac_reg(0);
				else
					txdata(11 downto 4) <= dac_reg(1);
				end if;
				
				state_nxt  <= S_DAC_WAIT;
				
			when S_DAC_WAIT =>
				if trcomplete = '1' then
					dac_cooldown_cnt_nxt <= (others => '0');
					state_nxt <= S_DAC_COOLDOWN;
				end if;
				
			when S_DAC_COOLDOWN => 
				-- wait for dac cooldown
				if dac_cooldown_cnt < to_unsigned(DAC_COOLDOWN_TIME, dac_cooldown_cnt'length) then
					dac_cooldown_cnt_nxt <= dac_cooldown_cnt + 1;
				-- back to control state
				else
					state_nxt <= S_CONTROL;
				end if;
				
			when S_DAC_SHUTDOWN =>
			
				trenable	<= '1';
				slaveid		<= '1'; -- DAC
			
				txdata(15) <= dac_select;
				txdata(13) <= '0';
				txdata(12) <= '0'; -- shutdown_n
				
				state_nxt  <= S_DAC_WAIT;
				
		end case;
	end process;
	
	
	swt_Select   <= mux_select;
	swt_Enable_n <= '1' when unsigned(control_reg(7 downto 0)) = 0 else -- no adc is activated
					'0';
	
	dac_ldac_n   <= '0';
	
	process(iobus_cs, iobus_wr, iobus_addr, iobus_din, adc_reg, dac_reg, control_reg)
	begin
		control_reg_nxt 	<= control_reg;
		
		dac_reg_nxt 		<= dac_reg;
		iobus_dout  		<= (others => '0');
		
		if iobus_cs = '1' then
			if iobus_wr = '1' then
				if 	iobus_addr = CV_ADDR_DAC0 then 
					dac_reg_nxt(0) <= iobus_din(7 downto 0);
				elsif iobus_addr = CV_ADDR_DAC1 then
					dac_reg_nxt(1) <= iobus_din(7 downto 0);
				elsif iobus_addr = CV_ADDR_ADC_DAC_CTRL then 
					control_reg_nxt <= iobus_din(control_reg'range);
				end if;
			else
				if 	iobus_addr = CV_ADDR_DAC0 then
					iobus_dout(7 downto 0) 	<= dac_reg(0);
				elsif iobus_addr = CV_ADDR_DAC1 then
					iobus_dout(7 downto 0) 	<= dac_reg(1);
				elsif iobus_addr = CV_ADDR_ADC0 then
					iobus_dout(11 downto 0) <= adc_reg(0);
				elsif iobus_addr = CV_ADDR_ADC1 then
					iobus_dout(11 downto 0) <= adc_reg(1);
				elsif iobus_addr = CV_ADDR_ADC2 then
					iobus_dout(11 downto 0) <= adc_reg(2);
				elsif iobus_addr = CV_ADDR_ADC3 then
					iobus_dout(11 downto 0) <= adc_reg(3);
				elsif iobus_addr = CV_ADDR_ADC4 then
					iobus_dout(11 downto 0) <= adc_reg(4);
				elsif iobus_addr = CV_ADDR_ADC5 then
					iobus_dout(11 downto 0) <= adc_reg(5);
				elsif iobus_addr = CV_ADDR_ADC6 then
					iobus_dout(11 downto 0) <= adc_reg(6);
				elsif iobus_addr = CV_ADDR_ADC7 then
					iobus_dout(11 downto 0) <= adc_reg(7);
				elsif iobus_addr = CV_ADDR_ADC_DAC_CTRL then
					iobus_dout(9 downto 0) 	<= control_reg;
				end if;
			end if;
		end if;
	end process;
	
	process(adc_select)
		variable sel : natural;
	begin
		sel := to_integer(unsigned(adc_select));
		case sel is
			when 0 		=> mux_select <= std_ulogic_vector(to_unsigned(7, mux_select'length));
			when 1		=> mux_select <= std_ulogic_vector(to_unsigned(2, mux_select'length));
			when 2 		=> mux_select <= std_ulogic_vector(to_unsigned(5, mux_select'length));
			when 3 		=> mux_select <= std_ulogic_vector(to_unsigned(1, mux_select'length));
			when 4 		=> mux_select <= std_ulogic_vector(to_unsigned(6, mux_select'length));
			when 5 		=> mux_select <= std_ulogic_vector(to_unsigned(0, mux_select'length));
			when 6 		=> mux_select <= std_ulogic_vector(to_unsigned(4, mux_select'length));
			when 7 		=> mux_select <= std_ulogic_vector(to_unsigned(3, mux_select'length));
			when others => mux_select <= std_ulogic_vector(to_unsigned(7, mux_select'length));
		end case;
	end process;
	
end rtl;