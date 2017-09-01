-----------------------------------------------------------------------------------------
-- Project      : 	Invent a Chip
-- Module       : 	SRAM-Interface
-- Author 		: 	Jan Dürre
-- Last update  : 	22.07.2014
-- Description	: 	-
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity sram is
	port(
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
end sram;


architecture rtl of sram is
	
begin 
	-- constant
	sram_oe_n <= '0';
	sram_ub_n <= '0';
	sram_lb_n <= '0';
  
	-- chip enable only when cs = '1'
	sram_ce_n <= not(iobus_cs);
	
	-- set we only when cs = '1' and wr = '1', otherwise data might be written over
	sram_we_n <= not(iobus_wr and iobus_cs);
	
	-- always pass through address
	sram_addr <= iobus_addr(sram_addr'length-1 downto 0);
	
	-- only set data when cs and wr, else Z
	sram_dq <= std_logic_vector(iobus_din(sram_dq'length-1 downto 0)) when (iobus_cs = '1' and iobus_wr = '1') else (others => 'Z');
	
	-- pass out data when cs = '1'
	iobus_dout <= 	std_ulogic_vector(sram_dq(iobus_dout'length-1 downto 0)) when (iobus_cs = '1' and iobus_wr = '0') else
					(others => '0');
	
end rtl;
