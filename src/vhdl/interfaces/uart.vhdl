-----------------------------------------------------------------------------------------
-- Project      : 	Invent a Chip
-- Module       : 	UART Interface
-- Author 		: 	Jan Dürre
-- Last update  : 	10.04.2015
-- Description	: 	-
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.iac_pkg.all;

entity uart is
	generic (
		SIMULATION 		: boolean := false
	);
	port (
		-- global signals
		clock			: in  	std_ulogic;
		reset_n			: in  	std_ulogic;
		-- bus interface
		iobus_cs		: in  	std_ulogic;
		iobus_wr		: in  	std_ulogic;
		iobus_addr		: in  	std_ulogic_vector(CW_ADDR_UART-1 downto 0);
		iobus_din		: in  	std_ulogic_vector(CW_DATA_UART-1 downto 0);
		iobus_dout		: out 	std_ulogic_vector(CW_DATA_UART-1 downto 0);
		-- IRQ handling
		iobus_irq_rx	: out 	std_ulogic;
		iobus_irq_tx	: out 	std_ulogic;
		iobus_ack_rx	: in  	std_ulogic;
		iobus_ack_tx	: in  	std_ulogic;
		-- pins to outside 
		rts				: in  	std_ulogic;
		cts				: out 	std_ulogic;
		rxd				: in  	std_ulogic;
		txd				: out 	std_ulogic
	);
end uart;

architecture rtl of uart is

	constant CV_BIT_DURATION_REAL	: natural := natural(ceil(real(CV_SYS_CLOCK_RATE) / real(CV_UART_BAUDRATE)));
	constant CV_BIT_DURATION_SIM 	: natural := 16;
	signal CV_BIT_DURATION : natural;

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

	signal rxbuf_write_en	: std_ulogic;
	signal rxbuf_data_in	: std_ulogic_vector(CV_UART_DATABITS-1 downto 0);
	signal rxbuf_read_en	: std_ulogic;
	signal rxbuf_data_out	: std_ulogic_vector(CV_UART_DATABITS-1 downto 0);
	signal rxbuf_empty 		: std_ulogic;
	signal rxbuf_full		: std_ulogic;
	
	signal txbuf_write_en	: std_ulogic;
	signal txbuf_data_in	: std_ulogic_vector(CV_UART_DATABITS-1 downto 0);
	signal txbuf_read_en	: std_ulogic;
	signal txbuf_data_out	: std_ulogic_vector(CV_UART_DATABITS-1 downto 0);
	signal txbuf_empty 		: std_ulogic;
	signal txbuf_full		: std_ulogic;
	
	-- rx
	type state_rx_t is (	S_IDLE,
							S_HALFSTARTBIT,
							S_DATABITS,
							S_PARITY,
							S_STOPBITS
						);
	signal state_rx 		: state_rx_t;
	signal state_rx_nxt		: state_rx_t;
	
	signal rxd_reg 			: std_ulogic_vector(2 downto 0);
	signal rxd_reg_nxt		: std_ulogic_vector(2 downto 0);
	
	signal rx_cnt 			: unsigned(to_log2(CV_BIT_DURATION_REAL)-1 downto 0);
	signal rx_cnt_nxt		: unsigned(to_log2(CV_BIT_DURATION_REAL)-1 downto 0);
	signal rx_cnt_reset 	: std_ulogic;
	
	signal rx_bitcnt 		: unsigned(to_log2(CV_UART_DATABITS)-1 downto 0);
	signal rx_bitcnt_nxt	: unsigned(to_log2(CV_UART_DATABITS)-1 downto 0);
	
	signal rx_data 			: std_ulogic_vector(CV_UART_DATABITS-1 downto 0);
	signal rx_data_nxt		: std_ulogic_vector(CV_UART_DATABITS-1 downto 0);
	
	signal error_reg 		: std_ulogic_vector(1 downto 0);	-- 1: overflow, 0: parity
	signal error_reg_nxt 	: std_ulogic_vector(1 downto 0);
	
	-- tx
	type state_tx_t is (	S_IDLE,
							S_STARTBIT,
							S_DATABITS,
							S_PARITY,
							S_STOPBITS
						);
	signal state_tx 		: state_tx_t;
	signal state_tx_nxt		: state_tx_t;
	
	signal tx_cnt 			: unsigned(to_log2(CV_BIT_DURATION_REAL)-1 downto 0);
	signal tx_cnt_nxt		: unsigned(to_log2(CV_BIT_DURATION_REAL)-1 downto 0);
	signal tx_cnt_reset 	: std_ulogic;
	
	signal tx_bitcnt 		: unsigned(to_log2(CV_UART_DATABITS)-1 downto 0);
	signal tx_bitcnt_nxt	: unsigned(to_log2(CV_UART_DATABITS)-1 downto 0);
	
	signal tx_data			: std_ulogic_vector(CV_UART_DATABITS-1 downto 0);
	signal tx_data_nxt		: std_ulogic_vector(CV_UART_DATABITS-1 downto 0);
	
	signal tx_parity 		: std_ulogic;
	signal tx_parity_nxt	: std_ulogic;
    
begin

	CV_BIT_DURATION		<= CV_BIT_DURATION_SIM when SIMULATION = true 	else CV_BIT_DURATION_REAL;

	cts <= '0';

	rxbuf_inst : fifo
		generic map (
			DEPTH 		=> CS_UART_BUFFER,
			WORDWIDTH 	=> CV_UART_DATABITS
		)
		port map (
			clock 		=> clock,
			reset_n  	=> reset_n,
			write_en	=> rxbuf_write_en,
			data_in		=> rxbuf_data_in,
			read_en		=> rxbuf_read_en,
			data_out	=> rxbuf_data_out,
			empty 		=> rxbuf_empty,
			full		=> rxbuf_full,
			fill_cnt 	=> open
		);
		
	txbuf_inst : fifo
		generic map (
			DEPTH 		=> CS_UART_BUFFER,
			WORDWIDTH 	=> CV_UART_DATABITS
		)
		port map (
			clock 		=> clock,
			reset_n  	=> reset_n,
			write_en	=> txbuf_write_en,
			data_in		=> txbuf_data_in,
			read_en		=> txbuf_read_en,
			data_out	=> txbuf_data_out,
			empty 		=> txbuf_empty,
			full		=> txbuf_full,
			fill_cnt 	=> open
		);


	ff : process (reset_n, clock)
	begin
		if (reset_n = '0') then
			state_rx 	<= S_IDLE;
			rxd_reg 	<= (others => '0');
			rx_cnt 		<= (others => '0');
			rx_bitcnt 	<= (others => '0');
			rx_data 	<= (others => '0');
			error_reg 	<= (others => '0');
			
			state_tx 	<= S_IDLE;
			tx_cnt 		<= (others => '0');
			tx_bitcnt 	<= (others => '0');
			tx_data		<= (others => '0');
			tx_parity 	<= '0';
			
		elsif rising_edge(clock) then
			state_rx 	<= state_rx_nxt;
			rxd_reg 	<= rxd_reg_nxt;
			rx_cnt 		<= rx_cnt_nxt;
			rx_bitcnt 	<= rx_bitcnt_nxt;
			rx_data 	<= rx_data_nxt;
			error_reg 	<= error_reg_nxt;
			
			state_tx 	<= state_tx_nxt;
			tx_cnt 		<= tx_cnt_nxt;
			tx_bitcnt 	<= tx_bitcnt_nxt;
			tx_data		<= tx_data_nxt;
			tx_parity 	<= tx_parity_nxt;
			
		end if;
	end process;
	
	
	iobus_if : process(iobus_cs, iobus_wr, iobus_addr, iobus_din, rxbuf_empty, rxbuf_full, rxbuf_data_out, txbuf_empty, txbuf_full, error_reg)
	begin
		txbuf_write_en	<= '0';
		txbuf_data_in	<= (others => '0');
		rxbuf_read_en	<= '0';
		
		iobus_irq_rx 	<= not rxbuf_empty;
		iobus_irq_tx 	<= not txbuf_full;
		
		iobus_dout <= (others => '0');
	
		-- chipselect
		if iobus_cs = '1' then
			-- write
			if iobus_wr = '1' then
				-- tx data
				if iobus_addr = CV_ADDR_UART_DATA_TX then
					-- avoid overflow
					if txbuf_full = '0' then
						txbuf_write_en 	<= '1';
						txbuf_data_in 	<= iobus_din;
					end if;
				end if;
			-- read
			else
				-- rx data
				if iobus_addr = CV_ADDR_UART_DATA_RX then
					-- avoid underflow
					if rxbuf_empty = '0' then
						rxbuf_read_en 	<= '1';
						iobus_dout 		<= rxbuf_data_out;
					end if;					
				end if;
			end if;
		end if;
	
	end process;
	
	
	rx_cnt_nxt <= (others => '0') when rx_cnt_reset = '1' 	else rx_cnt + 1;
	tx_cnt_nxt <= (others => '0') when tx_cnt_reset = '1' 	else tx_cnt + 1;
	
	-- rx fsm
	rx : process(state_rx, rxbuf_full, rxd_reg, rx_bitcnt, rx_cnt, rx_data, error_reg, rxd, CV_BIT_DURATION)
	begin
		
		state_rx_nxt 	<= state_rx;
		rxd_reg_nxt 	<= rxd_reg;
		rx_bitcnt_nxt	<= rx_bitcnt;
		rx_data_nxt 	<= rx_data;
		error_reg_nxt 	<= error_reg;
	
		rx_cnt_reset 	<= '0';
		rxbuf_write_en	<= '0';
		rxbuf_data_in	<= (others => '0');
		
		rxd_reg_nxt <= rxd & rxd_reg(rxd_reg'length-1 downto 1);
		
		
		case state_rx is 
			when S_IDLE =>
				-- falling edge on rxd
				if rxd_reg = "001" then
					rx_cnt_reset 	<= '1';
					error_reg_nxt 	<= (others => '0');
					state_rx_nxt 	<= S_HALFSTARTBIT;
				end if;
				
			when S_HALFSTARTBIT =>
				-- sync to mid of startbit
				if rx_cnt = shift_right(to_unsigned(CV_BIT_DURATION - 1, rx_cnt'length),1) then
					rx_cnt_reset 	<= '1';
					rx_bitcnt_nxt 	<= (others => '0');
					state_rx_nxt 	<= S_DATABITS;
				end if;
			
			when S_DATABITS =>
				if rx_cnt = CV_BIT_DURATION - 1 then
					rx_cnt_reset <= '1';
					rx_data_nxt  <= rxd_reg(0) & rx_data(rx_data'length-1 downto 1);
					-- last databit
					if rx_bitcnt = CV_UART_DATABITS-1 then
						rx_bitcnt_nxt 	<= (others => '0');
						-- receive parity
						if CS_UART_PARITY /= "NONE" then
							state_rx_nxt <= S_PARITY;
						-- receive stopbits
						else
							state_rx_nxt <= S_STOPBITS;
						end if;
					-- next databit
					else
						rx_bitcnt_nxt <= rx_bitcnt + 1;
					end if;
						
				end if;
			
			when S_PARITY =>
				if rx_cnt = CV_BIT_DURATION - 1 then
					rx_cnt_reset <= '1';
					state_rx_nxt <= S_STOPBITS;
					-- check parity
					if calc_parity(rx_data, CS_UART_PARITY) /= rxd_reg(0) then
						-- parity error
						error_reg_nxt(0) <= '1';
					end if;
				end if;
			
			when S_STOPBITS =>
				if rx_cnt = CV_BIT_DURATION - 1 then
					rx_cnt_reset <= '1';
					-- last stopbit
					if rx_bitcnt = CV_UART_STOPBITS-1 then
						rx_bitcnt_nxt 	<= (others => '0');
						state_rx_nxt 	<= S_IDLE;
						-- write received data to rx-fifo
						if rxbuf_full = '0' then
							rxbuf_write_en	<= '1';
							rxbuf_data_in	<= rx_data;
						else
							-- overflow error
							error_reg_nxt(1) <= '1';
						end if;
						
					-- next stopbit
					else
						rx_bitcnt_nxt <= rx_bitcnt + 1;
					end if;
						
				end if;
			
		end case;
		
	end process;
	
	
	-- tx fsm
	tx : process(state_tx, tx_cnt, tx_bitcnt, tx_data, tx_parity, txbuf_data_out, txbuf_empty, CV_BIT_DURATION)
	begin
	
		state_tx_nxt 	<= state_tx;
		tx_cnt_reset 	<= '0';
		tx_bitcnt_nxt 	<= tx_bitcnt;
		tx_data_nxt		<= tx_data;
		tx_parity_nxt 	<= tx_parity;
		
		txbuf_read_en 	<= '0';
		
		txd 			<= '1';
		
		case state_tx is 
			when S_IDLE =>
				txd <= '1';
				-- wait for data in tx-fifo
				if txbuf_empty = '0' then
					txbuf_read_en 	<= '1';
					tx_cnt_reset 	<= '1';
					tx_bitcnt_nxt 	<= (others => '0');
					tx_data_nxt 	<= txbuf_data_out;
					tx_parity_nxt 	<= calc_parity(txbuf_data_out, CS_UART_PARITY);
					state_tx_nxt 	<= S_STARTBIT;
				end if;
			
			when S_STARTBIT =>
				txd <= '0';
				-- startbit finished
				if tx_cnt = CV_BIT_DURATION - 1 then
					tx_cnt_reset <= '1';
					state_tx_nxt <= S_DATABITS;
				end if;
			
			when S_DATABITS =>
				txd <= tx_data(0);
				-- single databit finished
				if tx_cnt = CV_BIT_DURATION - 1 then
					tx_cnt_reset <= '1';
					tx_data_nxt  <= '0' & tx_data(tx_data'length-1 downto 1);
					-- last databit
					if tx_bitcnt = CV_UART_DATABITS-1 then
						tx_bitcnt_nxt 	<= (others => '0');
						-- transfer parity
						if CS_UART_PARITY /= "NONE" then
							state_tx_nxt <= S_PARITY;
						-- transfer stopbits
						else
							state_tx_nxt <= S_STOPBITS;
						end if;
					-- next databit
					else
						tx_bitcnt_nxt <= tx_bitcnt + 1;
					end if;
						
				end if;
			
			when S_PARITY =>
				txd <= tx_parity;
				-- transfer parity
				if tx_cnt = CV_BIT_DURATION - 1 then
					tx_cnt_reset 	<= '1';
					state_tx_nxt 	<= S_STOPBITS;
				end if;
			
			when S_STOPBITS =>
				txd <= '1';
				-- single stopbit finished
				if tx_cnt = CV_BIT_DURATION - 1 then
					tx_cnt_reset <= '1';
					-- last stopbit
					if tx_bitcnt = CV_UART_STOPBITS-1 then
						state_tx_nxt 	<= S_IDLE;
					-- next stopbit
					else
						tx_bitcnt_nxt 	<= tx_bitcnt + 1;
					end if;
				end if;
			
		end case;
		
	end process;

end rtl;
