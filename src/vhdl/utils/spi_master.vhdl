-----------------------------------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : SPI Master
-- Author 		: Jan Dürre
-- Last update  : 19.08.2014
-- Description	: SPI Master Interface
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
	port(
		-- global signals
		clock 		   : in  std_ulogic;						-- 50MHz Clock
		reset_n		   : in  std_ulogic;						-- Default High
		-- spi signals
		spi_clk 	   : out std_ulogic;						-- Signale die über den Expansion Header nach außen geführt werden
		spi_mosi 	   : out std_ulogic;
		spi_cs_n 	   : out std_ulogic_vector(1 downto 0);
		spi_miso 	   : in  std_logic;							-- Signale die über den Expansion Header rein kommen
		-- interface signals
		spi_slaveid	   : in  std_ulogic;
		spi_trenable   : in  std_ulogic;						-- Triggern der Übertragung
		spi_txdata     : in  std_ulogic_vector(15 downto 0);	-- An den uC zu sendender Befehl, wird mit dem enable Signal übernommen
		spi_rxdata     : out std_ulogic_vector(15 downto 0);	-- Vom uC erhaltenes Ergebnis, wird mit dem zurücknehmen des enable Signal übergeben
		spi_trcomplete : out std_ulogic
	);
end spi_master;


architecture rtl of spi_master is

	component clock_generator
		generic (
			GV_CLOCK_DIV	: natural
		);
		port (
			clock   		: in  std_ulogic;
			reset_n 		: in  std_ulogic;
			enable  		: in  std_ulogic;
			clock_out 		: out std_ulogic
		);
	end component clock_generator;
	
	signal rx, rx_nxt 				 : std_ulogic_vector(15 downto 0);
	signal tx, tx_nxt 				 : std_ulogic_vector(15 downto 0);
	
	signal bit_cnt, bit_cnt_nxt 	 : unsigned(3 downto 0);
	signal spi_clk_now, spi_clk_last : std_ulogic;
	
	signal spi_slave_id  , spi_slave_id_nxt	  : std_ulogic;
	signal activate_slave, activate_slave_nxt : std_ulogic;
	
	type state_t is (S_IDLE, S_CLK_FALL, S_CLK_RISE, S_END_TRANSFER);
	signal state, state_nxt : state_t;

begin

	spiclkgen : clock_generator
		generic map (
			GV_CLOCK_DIV	=> 50 -- resulting in 1MHz 
		)
		port map (
			clock   		=> clock,
			reset_n 		=> reset_n,
			enable  		=> activate_slave,
			clock_out 		=> spi_clk_now
		);

	process(clock, reset_n)
	begin
		if reset_n = '0' then
			rx  		   <= (others => '0');
			tx  		   <= (others => '0');
			bit_cnt		   <= (others => '0');
			spi_clk_last   <= '0';
			spi_slave_id   <= '0';
			activate_slave <= '0';
			state 		   <= S_IDLE;
		elsif rising_edge(clock) then
			rx  		   <= rx_nxt;
			tx  		   <= tx_nxt;
			bit_cnt		   <= bit_cnt_nxt;
			spi_clk_last   <= spi_clk_now;
			spi_slave_id   <= spi_slave_id_nxt;
			activate_slave <= activate_slave_nxt;
			state		   <= state_nxt;
		end if;
	end process;
	
	process(state, rx, tx, bit_cnt, activate_slave, spi_clk_now, spi_clk_last, spi_miso, spi_trenable, spi_slave_id, spi_txdata, spi_slaveid)
	begin
		state_nxt 	   	   <= state;
		rx_nxt	  	   	   <= rx;
		tx_nxt	  	   	   <= tx;
		bit_cnt_nxt	   	   <= bit_cnt;
		spi_slave_id_nxt   <= spi_slave_id;
		activate_slave_nxt <= activate_slave;
		spi_trcomplete	   <= '0';
		
		case state is
			when S_IDLE =>
				if spi_trenable = '1' then
					rx_nxt 			   <= (others => '0');
					tx_nxt 			   <= spi_txdata;
					spi_slave_id_nxt   <= spi_slaveid;
					activate_slave_nxt <= '1';
					bit_cnt_nxt		   <= (others => '0');
					state_nxt		   <= S_CLK_RISE;
				end if;
			
			when S_CLK_RISE =>
				if spi_clk_now = '1' and spi_clk_last = '0' then
					rx_nxt 	  	<= rx(14 downto 0) & spi_miso;
					bit_cnt_nxt <= bit_cnt + to_unsigned(1, bit_cnt'length);
					state_nxt 	<= S_CLK_FALL;
				end if;
			
			when S_CLK_FALL =>
				if spi_clk_now = '0' and spi_clk_last = '1' then
					tx_nxt 	  	<= tx(14 downto 0) & '0';
					state_nxt 	<= S_CLK_RISE;
					if bit_cnt = to_unsigned(0, bit_cnt'length) then
						state_nxt 	<= S_END_TRANSFER;
					end if;
				end if;
			
			when S_END_TRANSFER =>
				spi_trcomplete 	   <= '1';
				activate_slave_nxt <= '0';
				state_nxt		   <= S_IDLE;
				
		end case;
	end process;
	
	spi_clk		<= spi_clk_now;
	spi_mosi 	<= tx(15) when activate_slave = '1' else '0';
	spi_cs_n(0)	<= '0'	  when spi_slave_id   = '0' and activate_slave = '1' else '1';
	spi_cs_n(1)	<= '0'	  when spi_slave_id   = '1' and activate_slave = '1' else '1';
	
	spi_rxdata  <= rx	  when state = S_END_TRANSFER else (others => '0');
	
end architecture rtl;