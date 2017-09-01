-----------------------------------------------------------------
-- Project      : Invent a Chip
-- Module       : Generic FIFO
-- Author 		: Jan Dürre
-- Last update  : 28.11.2014
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity fifo is
	generic (
		DEPTH		: natural 	:= 64;
		WORDWIDTH	: natural 	:= 8;
		RAMTYPE		: string 	:= "auto"	-- "auto", "logic", "MLAB", "M-RAM", "M512", "M4K", "M9K", "M144K", "M10K", "M20K" (the supported memory type depends on the target device, auto & logic will always work)
	);
	port (
		-- global
		clock		: in	std_ulogic;
		reset_n 	: in	std_ulogic;
		-- data ports
		write_en	: in	std_ulogic;
		data_in		: in	std_ulogic_vector(WORDWIDTH-1 downto 0);
		read_en		: in	std_ulogic;
		data_out	: out	std_ulogic_vector(WORDWIDTH-1 downto 0);
		-- status signals
		empty		: out	std_ulogic;
		full		: out	std_ulogic;
		fill_cnt	: out	unsigned(to_log2(DEPTH+1)-1 downto 0)
	);
end fifo;


architecture rtl of fifo is

	type ram_t is array(0 to DEPTH-1) of std_logic_vector(WORDWIDTH-1 downto 0);
	signal ram : ram_t;

	attribute ramstyle 			: string;	
	attribute ramstyle of ram 	: signal is RAMTYPE;
	
	signal write_ptr, read_ptr 	: unsigned(to_log2(DEPTH)-1 downto 0);
	
	signal fill_cnt_local 		: unsigned(to_log2(DEPTH+1)-1 downto 0);
	
begin

	data_out 	<= 	std_ulogic_vector(ram(to_integer(read_ptr)));
	
	empty 		<= 	'1' when fill_cnt_local = 0 else
					'0';
					
	full		<=	'1' when fill_cnt_local = DEPTH else
					'0';
	
	fill_cnt 	<= 	fill_cnt_local;
	
	-- ram
	process(clock, reset_n)
	begin
		if reset_n = '0' then
		
			ram <= (others => (others => 'U'));
			
		elsif rising_edge(clock) then 
		
			if write_en = '1' then
				ram(to_integer(write_ptr)) 	<= std_logic_vector(data_in);
			end if;
			
		end if;
	end process;
	
	
	-- pointers & counters
	process(clock, reset_n)
	begin
		if reset_n = '0' then
		
			write_ptr 		<= (others => '0');
			read_ptr 		<= (others => '0');
			fill_cnt_local 	<= (others => '0');
			
		elsif rising_edge(clock) then 
		
			-- write pointer
			if write_en = '1' then
				if write_ptr < DEPTH-1 then
					write_ptr 	<= write_ptr + 1;
				else
					write_ptr 	<= (others => '0');
				end if;
			end if;
			
			-- read pointer
			if read_en = '1' then
				if read_ptr < DEPTH-1 then
					read_ptr 	<= read_ptr + 1;
				else
					read_ptr 	<= (others => '0');
				end if;
			end if;
			
			-- fill count
			if (write_en = '1') and (read_en = '0') then
				if fill_cnt_local < DEPTH then
					fill_cnt_local 	<= fill_cnt_local + 1;
				end if;
			elsif (write_en = '0') and (read_en = '1') then
				if fill_cnt_local > 0 then
					fill_cnt_local 	<= fill_cnt_local - 1;
				end if;
			end if;
			
		end if;
	end process;

end rtl;
