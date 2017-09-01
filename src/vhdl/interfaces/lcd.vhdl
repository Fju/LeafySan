-----------------------------------------------------------------------------------------
-- Project      : 	Invent a Chip
-- Module       : 	LC-Display
-- Author 		: 	Christian Leibold / Jan Dürre
-- Last update  : 	29.04.2015
-- Description	: 	-
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity lcd is
	generic(
		SIMULATION	: boolean := false
	);
	port(
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
end lcd;

architecture rtl of lcd is

	-- buffer for incoming lcd-commands
	component fifo is
		generic (
			DEPTH 		: natural;
			WORDWIDTH 	: natural
		);
		port (
			clock 			: in    std_ulogic;
			reset_n  		: in    std_ulogic;
			write_en		: in 	std_ulogic;
			data_in			: in	std_ulogic_vector(WORDWIDTH-1 downto 0);
			read_en			: in 	std_ulogic;
			data_out		: out	std_ulogic_vector(WORDWIDTH-1 downto 0);
			empty 			: out 	std_ulogic;
			full			: out 	std_ulogic;
			fill_cnt 		: out 	unsigned(to_log2(DEPTH+1)-1 downto 0)
		);
	end component fifo;

	signal buf_write_en		: std_ulogic;
	signal buf_data_in		: std_ulogic_vector(7 downto 0);
	signal buf_read_en		: std_ulogic;
	signal buf_data_out		: std_ulogic_vector(7 downto 0);
	signal buf_empty 		: std_ulogic;
	signal buf_full			: std_ulogic;


	type state_t IS (S_POWER_UP, S_INIT, S_READY, S_SEND, S_CURSOR_DATA, S_CURSOR_SET);
	signal state, state_nxt 		: state_t;
	signal clk_count, clk_count_nxt : unsigned(42 downto 0) := (others => '0');
	signal count_inc, count_rst		: std_ulogic;
	signal rs, rs_nxt				: std_ulogic;
	signal data, data_nxt			: std_ulogic_vector(7 downto 0);
	-- LCD state registers
	signal cursor_on, cursor_on_nxt	: std_ulogic; -- Static cursor	(1 = on , 0 = off)
	signal blink_on, blink_on_nxt	: std_ulogic; -- Cursor blinks	(1 = on , 0 = off)
	signal col, col_nxt				: unsigned(3 downto 0);
	signal row, row_nxt				: unsigned(0 downto 0);
	signal cursor_home				: std_ulogic;
	signal cursor_right				: std_ulogic;
	signal cursor_left				: std_ulogic;
	signal cursor_set				: std_ulogic;
		
	constant CYCLES_POWER_UP  	    : natural := 50*(CV_SYS_CLOCK_RATE/1000); 	 -- 50 ms
	signal CYCLES_INIT_FUNC			: natural;
	signal CYCLES_INIT_FUNC_WAIT	: natural;
	signal CYCLES_INIT_DISP			: natural;
	signal CYCLES_INIT_DISP_WAIT 	: natural;
	signal CYCLES_INIT_CLR			: natural;
	signal CYCLES_INIT_CLR_WAIT		: natural;
	signal CYCLES_INIT_ENTRY		: natural;
	signal CYCLES_INIT_ENTRY_WAIT	: natural;
	
	signal TIME_1us					: natural;
	signal TIME_50us				: natural;
	signal TIME_14us				: natural;
	signal TIME_27us				: natural;
	
begin

	CYCLES_INIT_FUNC 		<= 10*(CV_SYS_CLOCK_RATE/1000000) 								when SIMULATION = false else 10;
	CYCLES_INIT_FUNC_WAIT	<= CYCLES_INIT_FUNC			+ 50*(CV_SYS_CLOCK_RATE/1000000)	when SIMULATION = false else CYCLES_INIT_FUNC 		+ 50;	-- + 50 us
	CYCLES_INIT_DISP		<= CYCLES_INIT_FUNC_WAIT	+ 10*(CV_SYS_CLOCK_RATE/1000000)	when SIMULATION = false else CYCLES_INIT_FUNC_WAIT	+ 10;	-- + 10 us
	CYCLES_INIT_DISP_WAIT	<= CYCLES_INIT_DISP			+ 50*(CV_SYS_CLOCK_RATE/1000000)	when SIMULATION = false else CYCLES_INIT_DISP		+ 50;	-- + 50 us
	CYCLES_INIT_CLR			<= CYCLES_INIT_DISP_WAIT	+ 10*(CV_SYS_CLOCK_RATE/1000000)	when SIMULATION = false else CYCLES_INIT_DISP_WAIT	+ 10;	-- + 10 us
	CYCLES_INIT_CLR_WAIT	<= CYCLES_INIT_CLR 			+ 02*(CV_SYS_CLOCK_RATE/1000)		when SIMULATION = false else CYCLES_INIT_CLR 		+ 02;	-- +  2 ms
	CYCLES_INIT_ENTRY		<= CYCLES_INIT_CLR_WAIT		+ 10*(CV_SYS_CLOCK_RATE/1000000)	when SIMULATION = false else CYCLES_INIT_CLR_WAIT	+ 10;	-- + 10 us
	CYCLES_INIT_ENTRY_WAIT	<= CYCLES_INIT_ENTRY 		+ 60*(CV_SYS_CLOCK_RATE/1000000)	when SIMULATION = false else CYCLES_INIT_ENTRY 		+ 60;	-- + 60 us
	
	TIME_1us				<= 01*(CV_SYS_CLOCK_RATE/1000000) when SIMULATION = false else  1; --  1 us
	TIME_50us				<= 50*(CV_SYS_CLOCK_RATE/1000000) when SIMULATION = false else 50; -- 50 us
	TIME_14us				<= 14*(CV_SYS_CLOCK_RATE/1000000) when SIMULATION = false else 14; -- 14 us
	TIME_27us				<= 27*(CV_SYS_CLOCK_RATE/1000000) when SIMULATION = false else 27; -- 27 us
	
	
	buf_inst : fifo
		generic map (
			DEPTH 		=> CS_LCD_BUFFER,
			WORDWIDTH 	=> 8
		)
		port map (
			clock 		=> clock,
			reset_n  	=> reset_n,
			write_en	=> buf_write_en,
			data_in		=> buf_data_in,
			read_en		=> buf_read_en,
			data_out	=> buf_data_out,
			empty 		=> buf_empty,
			full		=> buf_full,
			fill_cnt 	=> open
		);


	process(clock, reset_n)
	begin
		if reset_n = '0' then
			clk_count <= (others => '0');
			rs		  <= '0';
			data	  <= (others => '0');
			state 	  <= S_POWER_UP;
			-- LCD registers
			cursor_on <= '0';
			blink_on  <= '0';
			col		  <= (others => '0');
			row		  <= (others => '0');
		elsif rising_edge(clock) then
			clk_count <= clk_count_nxt;
			rs		  <= rs_nxt;
			data	  <= data_nxt;
			state 	  <= state_nxt;
			-- LCD registers
			cursor_on <= cursor_on_nxt;
			blink_on  <= blink_on_nxt;
			col		  <= col_nxt;
			row		  <= row_nxt;
		end if;
	end process;
	
	
	iobus_if : process(iobus_cs, iobus_wr, iobus_addr, iobus_din, buf_empty, buf_full, state)
	begin
		buf_write_en	<= '0';
		buf_data_in		<= (others => '0');
		
		iobus_irq_rdy 	<= not buf_full;		
		iobus_dout 		<= (others => '0');
	
		-- chipselect
		if iobus_cs = '1' then
			-- write
			if iobus_wr = '1' then
				-- data
				if iobus_addr = CV_ADDR_LCD_DATA then
					-- avoid overflow
					if buf_full = '0' then
						buf_write_en <= '1';
						buf_data_in <= iobus_din;
					end if;
				end if;
			-- read
			else
				-- status
				if iobus_addr = CV_ADDR_LCD_STATUS then
					-- working
					if buf_empty = '0' or state /= S_READY then
						iobus_dout(0) <= '1';
					else
						iobus_dout(0) <= '0';
					end if;
				end if;
			end if;
		end if;
	
	end process;
	
	
	clk_count_nxt <= (others => '0') when count_rst = '1' else
					 clk_count + 1   when count_inc = '1' else
					 clk_count;
	
	disp_rs		<= rs;
	disp_dat 	<= data;
	disp_rw  	<= '0';
	disp_pwr	<= '1';
	disp_blon	<= '0';
	
	
	process(state, clk_count, data, rs, cursor_on, blink_on, col, row, buf_empty, buf_data_out, CYCLES_INIT_FUNC, CYCLES_INIT_FUNC_WAIT, CYCLES_INIT_DISP, CYCLES_INIT_DISP_WAIT, CYCLES_INIT_CLR, CYCLES_INIT_CLR_WAIT, CYCLES_INIT_ENTRY, CYCLES_INIT_ENTRY_WAIT, TIME_1us, TIME_50us, TIME_14us, TIME_27us)
		variable data_in : unsigned(7 downto 0) := (others => '0');
	begin
		state_nxt		<= state;
		data_nxt		<= data;
		rs_nxt			<= rs;
		cursor_on_nxt	<= cursor_on;
		blink_on_nxt	<= blink_on;
		
		count_rst		<= '0';
		count_inc		<= '0';
		disp_en			<= '0';
		
		buf_read_en 	<= '0';
		
		cursor_home		<= '0';
		cursor_right	<= '0';
		cursor_left		<= '0';
		cursor_set		<= '0';
		
		case state is
			-- Wait 50 ms to ensure VDD has risen and required LCD wait is met
			WHEN S_POWER_UP =>
				if (clk_count < CYCLES_POWER_UP) and not SIMULATION then
					count_inc <= '1';
				elsif (clk_count < 10) and SIMULATION then
					count_inc <= '1';
				else								-- Power-up complete
					count_rst <= '1';
					rs_nxt	  <= '0';
					data_nxt  <= "00111100";		-- 2-line mode, display on
					state_nxt <= S_INIT;
				end if;

			-- Cycle through initialization sequence  
			WHEN S_INIT =>
				count_inc <= '1';
				if clk_count < CYCLES_INIT_FUNC then	-- Function set
					disp_en 	<= '1';
				elsif clk_count < CYCLES_INIT_FUNC_WAIT then -- Wait 50 us
					disp_en  <= '0';
					data_nxt 	  <= "00001100";      	-- Display on, Cursor off, Blink off					
				elsif clk_count < CYCLES_INIT_DISP THEN	-- Display on/off control
					cursor_on_nxt <= '0';				-- Save cursor off state
					blink_on_nxt  <= '0';				-- Save blink off state
					disp_en 	  <= '1';
				elsif clk_count < CYCLES_INIT_DISP_WAIT then -- Wait 50 us
					disp_en  <= '0';
					data_nxt 	<= x"01";					
				elsif clk_count < CYCLES_INIT_CLR then		-- Display clear
					cursor_home <= '1';
					disp_en  	<= '1';
				elsif clk_count < CYCLES_INIT_CLR_WAIT then	-- Wait 2 ms
					disp_en  <= '0';
					data_nxt     <= "00000110";      		-- Increment mode, entire shift off					
				elsif clk_count < CYCLES_INIT_ENTRY then	-- Entry mode set
					disp_en      <= '1';
				elsif clk_count < CYCLES_INIT_ENTRY_WAIT then	-- Wait 60 us
					data_nxt <= (others => '0');
					disp_en  <= '0';
				else										-- Initialization complete
					count_rst <= '1';
					state_nxt <= S_READY;
				END IF;    

			-- Wait for the enable signal (iobus_cs & iobus_wr) and then latch in the instruction
			when S_READY =>
				count_rst <= '1';
				if buf_empty = '0' then
					state_nxt <= S_SEND;
					
					buf_read_en <= '1';
					data_in := unsigned(buf_data_out(7 downto 0));
					
					-- Code for a character
					if (data_in>=16#20# and data_in<=16#7F#) or (data_in>=16#A0# and data_in<=16#FE#) then
						rs_nxt   	 <= '1';
						data_nxt 	 <= buf_data_out(7 downto 0);
						cursor_right <= '1';
						
					-- Code for a function
					elsif (data_in>=16#00# and data_in<=16#06#) or (data_in>=16#80# and data_in<=16#9F#) then
						rs_nxt <= '0';
						if data_in = 16#00# then	-- Display clear
							data_nxt 	<= x"01";
							cursor_home <= '1';
						elsif data_in = 16#01# then	-- Cursor on
							data_nxt      <= x"0" & '1' & '1' & '1' & blink_on;
							cursor_on_nxt <= '1';
						elsif data_in = 16#02# then	-- Cursor off
							data_nxt      <= x"0" & '1' & '1' & '0' & blink_on;
							cursor_on_nxt <= '0';
						elsif data_in = 16#03# then	-- Blinking on
							data_nxt     <= x"0" & '1' & '1' & cursor_on & '1';
							blink_on_nxt <= '1';
						elsif data_in = 16#04# then	-- Blinking off
							data_nxt     <= x"0" & '1' & '1' & cursor_on & '0';
							blink_on_nxt <= '0';
						elsif data_in = 16#05# then	-- Move cursor right
							cursor_right <= '1';
							state_nxt  <= S_CURSOR_DATA;
						elsif data_in = 16#06# then	-- Move cursor left
							cursor_left <= '1';
							state_nxt  <= S_CURSOR_DATA;
						else
							cursor_set <= '1';
							state_nxt  <= S_CURSOR_DATA;
						end if;

					-- Invalid codes will be ignored and the display won't get busy
					else
						rs_nxt	  <= '0';
						data_nxt  <= (others => '0');
						state_nxt <= S_READY;
					end if;
				else
					rs_nxt	  <= '0';
					data_nxt  <= (others => '0');
				end if;

			-- Send instruction to LCD        
			when S_SEND =>
				if clk_count < TIME_50us then			-- Do not exit for 50us
					count_inc <= '1';
					if clk_count < TIME_1us then		-- Negative enable
						disp_en <= '0';
					elsif clk_count < TIME_14us then	-- Positive enable half-cycle
						disp_en <= '1';
					elsif clk_count < TIME_27us then	-- Negative enable half-cycle
						disp_en <= '0';
					end if;
				else
					rs_nxt	  <= '0';
					data_nxt  <= '1' & row(0) & "00" & std_ulogic_vector(col);
					count_rst <= '1';
					state_nxt <= S_CURSOR_SET;
				end if;
			
			when S_CURSOR_DATA =>
				rs_nxt	  <= '0';
				data_nxt  <= '1' & row(0) & "00" & std_ulogic_vector(col);
				count_rst <= '1';
				state_nxt <= S_CURSOR_SET;
			
			when S_CURSOR_SET =>
				if clk_count < TIME_50us then			-- Do not exit for 50us
					count_inc <= '1';
					if clk_count < TIME_1us then		-- Negative enable
						disp_en <= '0';
					elsif clk_count < TIME_14us then	-- Positive enable half-cycle
						disp_en <= '1';
					elsif clk_count < TIME_27us then	-- Negative enable half-cycle
						disp_en <= '0';
					end if;
				else
					count_rst <= '1';
					state_nxt <= S_READY;
				end if;
				
		end case;    
	end process;
	
	process(col, row, cursor_home, cursor_right, cursor_left, cursor_set, buf_data_out)
	begin
		col_nxt	<= col;
		row_nxt <= row;
		if cursor_home = '1' then
			col_nxt	<= (others => '0');
		    row_nxt <= (others => '0');
		elsif cursor_right = '1' then
			if col = 15 then 
				col_nxt <= (others => '0');
				row_nxt <= row + 1;
			else
				col_nxt <= col + 1;
			end if;
		elsif cursor_left = '1' then
			if col = 15 then 
				col_nxt <= (others => '0');
				row_nxt <= row - 1;
			else
				col_nxt <= col - 1;
			end if;
		elsif cursor_set = '1' then
			col_nxt <= unsigned(buf_data_out(3 downto 0));
			row_nxt <= unsigned(buf_data_out(4 downto 4));
		end if;
	end process;
	
end rtl;