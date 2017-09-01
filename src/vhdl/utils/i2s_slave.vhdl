-------------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : I2S Slave
-- Author 		: Jan Duerre
-- Last update  : 21.08.2014
-- Description 	: This module implements a Slave-Receiver for the 
--				  Inter-IC Sound Bus.
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity i2s_slave is
	port (
		-- general signals
		clock			: in  std_ulogic; -- system clock
		reset_n			: in  std_ulogic; -- global reset
		-- input signals from adc
		aud_bclk		: in  std_ulogic; -- bitstream clock
		aud_adc_lrck	: in  std_ulogic; -- adc left/~right clock
		aud_adc_dat		: in  std_ulogic; -- adc serial audio data
		-- output signals to dac
		aud_dac_lrck	: in  std_ulogic; -- dac left/~right clock
		aud_dac_dat		: out std_ulogic; -- dac serial audio data
		-- audio sample inputs
		ain_left_sync	: out std_ulogic;
		ain_left_data	: out std_ulogic;
		ain_right_sync	: out std_ulogic;
		ain_right_data	: out std_ulogic;
		-- audio sample outputs
		aout_left_sync	: in  std_ulogic;
		aout_left_data	: in  std_ulogic;
		aout_right_sync	: in  std_ulogic;
		aout_right_data	: in  std_ulogic
    );
end i2s_slave;

architecture rtl of i2s_slave is

	-- shift regs for signal detection
	signal aud_bclk_sreg 			: std_ulogic_vector(2 downto 0);
	signal aud_bclk_sreg_nxt 		: std_ulogic_vector(2 downto 0);
	
	signal aud_adc_lrck_sreg		: std_ulogic_vector(1 downto 0);
	signal aud_adc_lrck_sreg_nxt 	: std_ulogic_vector(1 downto 0);
	
	signal aud_dac_lrck_sreg 		: std_ulogic_vector(1 downto 0);
	signal aud_dac_lrck_sreg_nxt 	: std_ulogic_vector(1 downto 0);
	
	signal aud_adc_dat_reg 			: std_ulogic;
	signal aud_adc_dat_reg_nxt		: std_ulogic;
	
	-- data registers
	signal audio_data_in_lr 		: std_ulogic;
	signal audio_data_in_lr_nxt 	: std_ulogic;
	signal ain_lr 					: std_ulogic;
	signal ain_lr_nxt 				: std_ulogic;
	
	signal audio_data_in_left 		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_in_left_nxt 	: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_in_right 		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_in_right_nxt 	: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_in_sreg		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_in_sreg_nxt 	: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	
	
	signal audio_data_out_lr 		: std_ulogic;
	signal audio_data_out_lr_nxt 	: std_ulogic;
	signal aout_lr					: std_ulogic;
	signal aout_lr_nxt				: std_ulogic;
	
	signal audio_data_out_left 		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_out_left_nxt	: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_out_right 	: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_out_right_nxt	: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_out_sreg		: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	signal audio_data_out_sreg_nxt 	: std_ulogic_vector(CW_AUDIO_SAMPLE-1 downto 0);
	
	-- bit counter
	signal audio_data_in_cnt_left 		: unsigned(to_log2(CW_AUDIO_SAMPLE+2)-1 downto 0);
	signal audio_data_in_cnt_left_nxt	: unsigned(to_log2(CW_AUDIO_SAMPLE+2)-1 downto 0);
	signal audio_data_in_cnt_right 		: unsigned(to_log2(CW_AUDIO_SAMPLE+2)-1 downto 0);
	signal audio_data_in_cnt_right_nxt	: unsigned(to_log2(CW_AUDIO_SAMPLE+2)-1 downto 0);
	
	signal audio_data_out_cnt 		: unsigned(to_log2(CW_AUDIO_SAMPLE+2)-1 downto 0);
	signal audio_data_out_cnt_nxt	: unsigned(to_log2(CW_AUDIO_SAMPLE+2)-1 downto 0);
	
	signal ain_cnt 					: unsigned(to_log2(CW_AUDIO_SAMPLE+1)-1 downto 0);
	signal ain_cnt_nxt 				: unsigned(to_log2(CW_AUDIO_SAMPLE+1)-1 downto 0);
	
	signal aout_cnt 				: unsigned(to_log2(CW_AUDIO_SAMPLE+1)-1 downto 0);
	signal aout_cnt_nxt 			: unsigned(to_log2(CW_AUDIO_SAMPLE+1)-1 downto 0);
	
	
	-- FSM adc (audio in)
	type fsm_ain_t is (S_WAIT_FOR_EDGE_LR, S_WAIT_1BCLK_RISE, S_WAIT_1BCLK_FALL);
	signal state_ain, state_ain_nxt : fsm_ain_t;
	
	-- FSM dac (audio out)
	type fsm_aout_t is (S_WAIT_FOR_EDGE_LR, S_WAIT_1BCLK_RISE, S_WAIT_1BCLK_FALL);
	signal state_aout, state_aout_nxt : fsm_aout_t;
	

begin

	-- FFs
	process(clock, reset_n)
	begin
		if reset_n = '0' then
			aud_bclk_sreg			<= (others => '0');
			aud_adc_lrck_sreg		<= (others => '1');
			aud_dac_lrck_sreg		<= (others => '1');
			
			aud_adc_dat_reg 		<= '0';
			
			audio_data_in_lr 		<= '0';
			audio_data_in_left 		<= (others => '0');
			audio_data_in_right		<= (others => '0');
			audio_data_in_sreg		<= (others => '0');
			
			audio_data_out_lr 		<= '0';
			audio_data_out_left		<= (others => '0');
			audio_data_out_right	<= (others => '0');
			audio_data_out_sreg		<= (others => '0');
			
			audio_data_in_cnt_left 	<= to_unsigned(CW_AUDIO_SAMPLE+1, audio_data_in_cnt_left'length);
			audio_data_in_cnt_right	<= to_unsigned(CW_AUDIO_SAMPLE+1, audio_data_in_cnt_right'length);
			audio_data_out_cnt 		<= to_unsigned(CW_AUDIO_SAMPLE+1, audio_data_out_cnt'length);
			
			ain_cnt 				<= to_unsigned(CW_AUDIO_SAMPLE, ain_cnt'length);
			aout_cnt 				<= (others => '0');
			ain_lr 					<= '0';
			aout_lr 				<= '0';
			
			state_ain 				<= S_WAIT_FOR_EDGE_LR;
			state_aout 				<= S_WAIT_FOR_EDGE_LR;
			
		elsif rising_edge(clock) then
			aud_bclk_sreg			<= aud_bclk_sreg_nxt;
			aud_adc_lrck_sreg		<= aud_adc_lrck_sreg_nxt;
			aud_dac_lrck_sreg		<= aud_dac_lrck_sreg_nxt;	
			
			aud_adc_dat_reg 		<= aud_adc_dat_reg_nxt;
			
			audio_data_in_lr 		<= audio_data_in_lr_nxt;
			audio_data_in_left		<= audio_data_in_left_nxt;
			audio_data_in_right		<= audio_data_in_right_nxt;
			audio_data_in_sreg		<= audio_data_in_sreg_nxt;
			
			audio_data_out_lr 		<= audio_data_out_lr_nxt;
			audio_data_out_left		<= audio_data_out_left_nxt;
			audio_data_out_right	<= audio_data_out_right_nxt;
			audio_data_out_sreg		<= audio_data_out_sreg_nxt;
			
			audio_data_in_cnt_left	<= audio_data_in_cnt_left_nxt;
			audio_data_in_cnt_right	<= audio_data_in_cnt_right_nxt;
			audio_data_out_cnt 		<= audio_data_out_cnt_nxt;
			
			ain_cnt 				<= ain_cnt_nxt;
			aout_cnt 				<= aout_cnt_nxt;
			ain_lr 					<= ain_lr_nxt;
			aout_lr 				<= aout_lr_nxt;
			
			state_ain 				<= state_ain_nxt;
			state_aout 				<= state_aout_nxt;
			
		end if;
	end process;

	
	-- shift regs for edge detection
	aud_bclk_sreg_nxt		<= aud_bclk			& aud_bclk_sreg(2 downto 1);
	aud_adc_lrck_sreg_nxt	<= aud_adc_lrck		& aud_adc_lrck_sreg(1);
	aud_dac_lrck_sreg_nxt	<= aud_dac_lrck		& aud_dac_lrck_sreg(1);

	-- connect adc data in to register, to have access to past data
	aud_adc_dat_reg_nxt 	<= aud_adc_dat;
	
	-- FSM Audio In
	process (state_ain, audio_data_in_lr, audio_data_in_left, audio_data_in_right, audio_data_in_cnt_left, audio_data_in_cnt_right, ain_cnt, ain_lr, aud_adc_lrck, aud_adc_lrck_sreg, aud_bclk_sreg, aud_adc_dat, audio_data_in_sreg, aud_adc_dat_reg)
	begin
	
		state_ain_nxt 			<= state_ain;
		
		audio_data_in_lr_nxt 	<= audio_data_in_lr;
		audio_data_in_left_nxt 	<= audio_data_in_left;
		audio_data_in_right_nxt <= audio_data_in_right;
		audio_data_in_sreg_nxt	<= audio_data_in_sreg;
			
		audio_data_in_cnt_left_nxt 	<= audio_data_in_cnt_left;
		audio_data_in_cnt_right_nxt <= audio_data_in_cnt_right;
			
		ain_cnt_nxt 			<= ain_cnt;
		ain_lr_nxt 				<= ain_lr;
		
		ain_left_sync			<= '0';
		ain_left_data			<= '0';
		ain_right_sync			<= '0';
		ain_right_data			<= '0';
		
		-- serialization
		if ain_cnt /= CW_AUDIO_SAMPLE then 
			-- sync signal
			if ain_cnt = 0 then
				-- left / right
				if ain_lr = '0' then
					ain_left_sync 	<= '1';
				else 
					ain_right_sync 	<= '1';
				end if;
			end if;
			
			-- serial data signal
			if ain_lr = '0' then
				-- left
				ain_left_data 	<= audio_data_in_sreg(CW_AUDIO_SAMPLE-1);
			else 
				-- right
				ain_right_data 	<= audio_data_in_sreg(CW_AUDIO_SAMPLE-1);
			end if;
			
			-- shift data
			audio_data_in_sreg_nxt 	<= audio_data_in_sreg(CW_AUDIO_SAMPLE-2 downto 0) & '0';
			-- count
			ain_cnt_nxt 		<= ain_cnt + 1;
			
		end if;
		
		
		-- i2s rx
		-- rising edge on bclk: shift in data
		if aud_bclk_sreg(2 downto 1) = "10" then
			-- left
			if audio_data_in_lr = '0' then
				audio_data_in_left_nxt 	<= audio_data_in_left(CW_AUDIO_SAMPLE-2 downto 0) & aud_adc_dat_reg;
			-- right
			else
				audio_data_in_right_nxt <= audio_data_in_right(CW_AUDIO_SAMPLE-2 downto 0) & aud_adc_dat_reg;
			end if;
		end if;
		
		-- rising edge on bclk: count data
		if aud_bclk_sreg(2 downto 1) = "10" then
			-- left
			if audio_data_in_lr = '0' then
				if audio_data_in_cnt_left <= CW_AUDIO_SAMPLE then
					audio_data_in_cnt_left_nxt <= audio_data_in_cnt_left + 1;
				end if;
			else
				-- right
				if audio_data_in_cnt_right <= CW_AUDIO_SAMPLE then
					audio_data_in_cnt_right_nxt <= audio_data_in_cnt_right + 1;
				end if;
			end if;
		end if;
		
		-- finished rx : start serialization
		if audio_data_in_cnt_left = CW_AUDIO_SAMPLE then
			ain_cnt_nxt 				<= (others => '0');
			ain_lr_nxt 					<= audio_data_in_lr;
			audio_data_in_sreg_nxt 		<= audio_data_in_left;
			audio_data_in_cnt_left_nxt 	<= audio_data_in_cnt_left + 1;
		end if;
		
		if audio_data_in_cnt_right = CW_AUDIO_SAMPLE then
			ain_cnt_nxt 				<= (others => '0');
			ain_lr_nxt 					<= audio_data_in_lr;
			audio_data_in_sreg_nxt 		<= audio_data_in_right;
			audio_data_in_cnt_right_nxt <= audio_data_in_cnt_right + 1;
		end if;
		
		
		-- mini-fsm to control flow
		case state_ain is
			when S_WAIT_FOR_EDGE_LR =>
				-- on falling or rising edge on lrc
				if 		aud_adc_lrck_sreg = "01" or aud_adc_lrck_sreg = "10" then
					-- await first cycle 
					state_ain_nxt <= S_WAIT_1BCLK_RISE;
				end if;
				
			when S_WAIT_1BCLK_RISE =>
				-- rising edge on bclk
				if aud_bclk_sreg(2 downto 1) = "10" then
					-- await first cycle 
					state_ain_nxt <= S_WAIT_1BCLK_FALL;
				end if;
				
			when S_WAIT_1BCLK_FALL =>
				-- falling edge on bclk
				if aud_bclk_sreg(2 downto 1) = "01" then
					-- start recording data
					if aud_adc_lrck = '0' then
						audio_data_in_cnt_left_nxt 	<= (others => '0');
					else
						audio_data_in_cnt_right_nxt <= (others => '0');
					end if;
					-- save channel
					audio_data_in_lr_nxt 	<= aud_adc_lrck;
					-- wait for next edge
					state_ain_nxt 			<= S_WAIT_FOR_EDGE_LR;
				end if;
			
		end case;
  
	end process;
	
	
	-- FSM Audio Out
	process (state_aout, aout_cnt, aout_lr, aout_left_sync, aout_left_data, aout_right_sync, aout_right_data, audio_data_out_left, audio_data_out_right, audio_data_out_sreg, audio_data_out_lr, audio_data_out_cnt, aud_dac_lrck, aud_dac_lrck_sreg, aud_bclk_sreg)
	begin
	
		state_aout_nxt 				<= state_aout;
		
		audio_data_out_lr_nxt 		<= audio_data_out_lr;
		audio_data_out_left_nxt		<= audio_data_out_left;
		audio_data_out_right_nxt	<= audio_data_out_right;
		audio_data_out_sreg_nxt		<= audio_data_out_sreg;
			
		audio_data_out_cnt_nxt 		<= audio_data_out_cnt;
		
		aout_cnt_nxt 				<= aout_cnt;
		aout_lr_nxt 				<= aout_lr;
		
		aud_dac_dat 				<= '0';
		
		
		-- parallelization
		if aout_left_sync = '1' then 
			audio_data_out_left_nxt 	<= audio_data_out_left(CW_AUDIO_SAMPLE-2 downto 0) & aout_left_data;
			aout_lr_nxt 				<= '0';
		elsif aout_right_sync = '1' then
			audio_data_out_right_nxt 	<= audio_data_out_right(CW_AUDIO_SAMPLE-2 downto 0) & aout_right_data;
			aout_lr_nxt 				<= '1';
		end if;
		
		if aout_left_sync = '1' or aout_right_sync = '1' then
			aout_cnt_nxt	<= (others => '0');			
		end if;
		
		if aout_cnt /= CW_AUDIO_SAMPLE - 1 then
			-- left / right
			if aout_lr = '0' then
				audio_data_out_left_nxt 	<= audio_data_out_left(CW_AUDIO_SAMPLE-2 downto 0) & aout_left_data;
			else 
				audio_data_out_right_nxt 	<= audio_data_out_right(CW_AUDIO_SAMPLE-2 downto 0) & aout_right_data;
			end if;
			-- count
			aout_cnt_nxt 	<= aout_cnt + 1;
		end if;
		
		
		-- i2s tx
		aud_dac_dat <= audio_data_out_sreg(CW_AUDIO_SAMPLE-1);
		
		if audio_data_out_cnt <= CW_AUDIO_SAMPLE then
			-- rising edge on delayed bclk: shift
			if aud_bclk_sreg(1 downto 0) = "10" then
				-- left
				if audio_data_out_lr = '0' then
					audio_data_out_sreg_nxt <= audio_data_out_sreg(CW_AUDIO_SAMPLE-2 downto 0) & '0';
				-- right
				else 
					audio_data_out_sreg_nxt <= audio_data_out_sreg(CW_AUDIO_SAMPLE-2 downto 0) & '0';
				end if;
			end if;
			
			-- rising edge on bclk: count
			if aud_bclk_sreg(2 downto 1) = "10" then
				-- count
				audio_data_out_cnt_nxt <= audio_data_out_cnt + 1;				
			end if;
		end if;
		

		-- mini-fsm to control flow
		case state_aout is
			when S_WAIT_FOR_EDGE_LR =>
				-- on rising or falling edge on lrc
				if aud_dac_lrck_sreg = "10" or aud_dac_lrck_sreg = "01" then
					state_aout_nxt <= S_WAIT_1BCLK_RISE;
				end if;
				
			when S_WAIT_1BCLK_RISE =>
				-- rising edge on bclk
				if aud_bclk_sreg(2 downto 1) = "10" then
					state_aout_nxt <= S_WAIT_1BCLK_FALL;
					
					if aud_dac_lrck = '0' then
						audio_data_out_sreg_nxt <= audio_data_out_left;
					else
						audio_data_out_sreg_nxt <= audio_data_out_right;
					end if;
					
				end if;
				
			when S_WAIT_1BCLK_FALL => 
				-- falling edge on bclk
				if aud_bclk_sreg(2 downto 1) = "01" then
					audio_data_out_lr_nxt 	<= aud_dac_lrck;
					state_aout_nxt 			<= S_WAIT_FOR_EDGE_LR;
					audio_data_out_cnt_nxt 	<= (others => '0');
				end if;
			
		end case;
  
	end process;

end architecture rtl;