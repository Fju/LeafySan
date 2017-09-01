-----------------------------------------------------------------------------------------
-- Project      : 	Invent a Chip
-- Module       : 	7-Segment Display
-- Author 		: 	Jan Dürre
-- Last update  : 	22.07.2014
-- Description	: 	-
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity seven_seg is
	port(
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
end seven_seg;

architecture rtl of seven_seg is

	-- array for easier use of hex0_n to hex7_n
	type seg_t is array (0 to 3) of std_ulogic_vector(6 downto 0);
	signal hex_seg, dec_seg : seg_t;
	
	--	7-Segment Displays
	--	[][] [][]	|	[][][][]
	--	hex-display	|	decimal-display (-999 to 999)
	--	A4A3A2A1	|	A0
	
	-- +-----+
	-- |  0  |
	-- | 5 1 |
	-- |  6  |
	-- | 4 2 |
	-- |  3  |
	-- +-----+

	-- register for each hex-display
	type hex_display_t is array (0 to 3) of std_ulogic_vector(3 downto 0);
	signal hex_display, hex_display_nxt : hex_display_t;
	
	-- register for decimal-display and sign-symbol
	signal dec_display, dec_display_nxt : std_ulogic_vector(to_log2(1000)-1 downto 0); -- 0...999
	signal dec_sign, dec_sign_nxt 		: std_ulogic;
	
	-- register to active 7-seg-displays
	signal display_active, display_active_nxt 	: std_ulogic_vector(4 downto 0);
	
begin

	-- connect and invert signal seg to output
	hex0_n <= not dec_seg(0);
	hex1_n <= not dec_seg(1);
	hex2_n <= not dec_seg(2);
	hex3_n <= not dec_seg(3);
	hex4_n <= not hex_seg(0);
	hex5_n <= not hex_seg(1);
	hex6_n <= not hex_seg(2);
	hex7_n <= not hex_seg(3);
	

	-- sequential process
	process(clock, reset_n)
	begin
		-- async reset
		if reset_n = '0' then 
			hex_display 	<= (others => (others => '0'));
			dec_display 	<= (others => '0');
			dec_sign		<= '0';
			display_active 	<= (others =>'0');
		elsif rising_edge(clock) then
			hex_display 	<= hex_display_nxt;
			dec_display 	<= dec_display_nxt;
			dec_sign		<= dec_sign_nxt;
			display_active	<= display_active_nxt;
		end if;
	end process;
	
	
	-- bus interface
	process(hex_display, dec_display, dec_sign, iobus_cs, iobus_addr, iobus_din, iobus_wr, display_active)
	begin
		-- standard: hold register values
		hex_display_nxt 	<= hex_display;
		dec_display_nxt 	<= dec_display;
		dec_sign_nxt		<= dec_sign;
		display_active_nxt 	<= display_active;
		
		-- dout always "0..0", no readable registers available
		iobus_dout <= (others => '0');
	
		-- chip select
		if iobus_cs = '1' then 
		
			-- write (no read allowed)
			if iobus_wr = '1' then 
			
				-- decode LSB: choose if hex_display or dec_display is changed
				if iobus_addr(0) = '1' then
				-- dec
					-- check MSB for positive or negative number
					if iobus_din(iobus_din'length-1) = '0' then
						dec_display_nxt <= iobus_din(dec_display'length-1 downto 0);
						dec_sign_nxt 	<= '0';
					else
						-- save positive value
						dec_display_nxt <= std_ulogic_vector(-signed(iobus_din(dec_display'length-1 downto 0)));
						dec_sign_nxt 	<= '1';
					end if;
					-- activate dec-display
					display_active_nxt(0) <= '1';
				else
				-- hex
					-- check bits 1 to 4 of iobus_addr
					for i in 0 to 3 loop
						-- check if register should be changed
						if iobus_addr(i+1) = '1' then
							-- write date to array
							hex_display_nxt(i) <= iobus_din(i*4 + 3 downto i*4);
							-- activate display
							display_active_nxt(i+1) <= '1';
						end if;
					end loop;

				end if;
			
			end if;
		
		end if;
	
	end process;
	
	
	-- decode LUT for hex-displays
	process(hex_display, display_active)
	begin
		
		-- for each hex-display
		for i in 0 to 3 loop
			-- check if display is active / has been written to
			if display_active(i+1) = '1' then 
				case hex_display(i) is 
					when "0000" => hex_seg(i) <= "0111111"; -- 0
					when "0001" => hex_seg(i) <= "0000110"; -- 1
					when "0010" => hex_seg(i) <= "1011011"; -- 2
					when "0011" => hex_seg(i) <= "1001111"; -- 3
					when "0100" => hex_seg(i) <= "1100110"; -- 4
					when "0101" => hex_seg(i) <= "1101101"; -- 5
					when "0110" => hex_seg(i) <= "1111101"; -- 6
					when "0111" => hex_seg(i) <= "0000111"; -- 7
					when "1000" => hex_seg(i) <= "1111111"; -- 8
					when "1001" => hex_seg(i) <= "1101111"; -- 9
					when "1010" => hex_seg(i) <= "1110111"; -- A
					when "1011" => hex_seg(i) <= "1111100"; -- b
					when "1100" => hex_seg(i) <= "0111001"; -- C
					when "1101" => hex_seg(i) <= "1011110"; -- d
					when "1110" => hex_seg(i) <= "1111001"; -- E
					when "1111" => hex_seg(i) <= "1110001"; -- F
					when others => hex_seg(i) <= "1111001"; -- wrong value: display E
				end case;
			-- deactivate display
			else 
				hex_seg(i) <= (others => '0');
			end if;
		end loop;
	
	end process;
		
		
	-- decode LUT for dec-display
	process(dec_display, dec_sign, display_active)
		variable bcd : std_ulogic_vector(11 downto 0);
	begin
		-- check if display is active / has been written to
		if display_active(0) = '1' then 
			-- if value is too big
			if unsigned(dec_display) > to_unsigned(999, dec_display'length) then
				-- display E (for "Error")
				dec_seg(0) <= "1111001";
				dec_seg(1) <= "0000000";
				dec_seg(2) <= "0000000";
				dec_seg(3) <= "0000000";
			
			else
			
				-- convert binary to bcd
				bcd := to_bcd(dec_display, 3);
			
				-- for each bcd digit
				for i in 0 to 2 loop
					if 		bcd((i+1)*4 -1 downto i*4) = "0000" then 	dec_seg(i) <= "0111111"; -- 0
					elsif 	bcd((i+1)*4 -1 downto i*4) = "0001" then 	dec_seg(i) <= "0000110"; -- 1
					elsif 	bcd((i+1)*4 -1 downto i*4) = "0010" then 	dec_seg(i) <= "1011011"; -- 2
					elsif 	bcd((i+1)*4 -1 downto i*4) = "0011" then 	dec_seg(i) <= "1001111"; -- 3
					elsif 	bcd((i+1)*4 -1 downto i*4) = "0100" then 	dec_seg(i) <= "1100110"; -- 4
					elsif 	bcd((i+1)*4 -1 downto i*4) = "0101" then 	dec_seg(i) <= "1101101"; -- 5
					elsif 	bcd((i+1)*4 -1 downto i*4) = "0110" then 	dec_seg(i) <= "1111101"; -- 6
					elsif 	bcd((i+1)*4 -1 downto i*4) = "0111" then 	dec_seg(i) <= "0000111"; -- 7
					elsif 	bcd((i+1)*4 -1 downto i*4) = "1000" then 	dec_seg(i) <= "1111111"; -- 8
					elsif 	bcd((i+1)*4 -1 downto i*4) = "1001" then 	dec_seg(i) <= "1101111"; -- 9
					else 												dec_seg(i) <= "1111001"; -- wrong value: display E
					end if;
				end loop;
				
				-- sign-symbol
				if dec_sign = '1' then
					dec_seg(3) <= "1000000";
				else
					-- turn off sign-symbol
					dec_seg(3) <= (others => '0');
				end if;
			
			end if;
			
		-- deactivate display
		else
			dec_seg(0) <= (others => '0');
			dec_seg(1) <= (others => '0');
			dec_seg(2) <= (others => '0');
			dec_seg(3) <= (others => '0');
		end if;
	
	end process;

end rtl;