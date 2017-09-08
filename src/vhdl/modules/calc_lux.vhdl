----------------------------------------------------------------------
-- Project		:	LeafySan
-- Module		:	Lux Calculation Module
-- Authors		:	Florian Winkler
-- Lust update	:	03.09.2017
-- Description	:	Calculates and returns lux value according to the value of the two light channels
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity calc_lux is
	port(
		clock		: in  std_ulogic;
		reset		: in  std_ulogic;
		channel0	: in  unsigned(15 downto 0);
		channel1	: in  unsigned(15 downto 0);
		start		: in  std_ulogic;
		busy		: out std_ulogic;
		lux			: out unsigned(15 downto 0)
	);
end calc_lux;

architecture rtl of calc_lux is
	type state_t is (S_IDLE, S_RATIO, S_SUBSTRACT, S_SHIFT, S_DONE);
	signal state, state_nxt : state_t;
	
	-- factor look up table
	type ratio_factor_t is record
		k	: natural;
		b	: natural;
		m	: natural;
	end record;
	type ratio_factor_array is array (natural range <>) of ratio_factor_t;
	constant RATIO_FACTORS_LENGTH : natural := 7;
	constant RATIO_FACTORS : ratio_factor_array(0 to RATIO_FACTORS_LENGTH - 1) := (
		-- k, b, m
		(64, 498, 446), 	-- 0x0040 , 0x01f2 , 0x01be
		(128, 532, 721), 	-- 0x0080 , 0x0214 , 0x02d1
		(192, 575, 891),	-- 0x00c0 , 0x023f , 0x037b
		(256, 624, 1022),	-- 0x0100 , 0x0270 , 0x03fe
		(312, 367, 508),	-- 0x0138 , 0x016f , 0x01fc
		(410, 210, 251),	-- 0x019a , 0x00d2 , 0x00fb
		(666, 24, 18)		-- 0x029a , 0x0018 , 0x0012
	);		
	
	signal b, b_nxt 		: unsigned(10 downto 0);
	signal m, m_nxt 		: unsigned(10 downto 0);
	signal l, l_nxt			: unsigned(15 downto 0);
	signal ch0, ch0_nxt		: unsigned(34 downto 0);
	signal ch1, ch1_nxt		: unsigned(34 downto 0);
	signal temp, temp_nxt	:   signed(34 downto 0);
begin

	-- sequential process
	process(clock, reset)
	begin
		if reset = '1' then
			state		<= S_IDLE;
			b			<= (others => '0');
			m			<= (others => '0');
			l			<= (others => '0');
			ch0			<= (others => '0');
			ch1			<= (others => '0');
			temp		<= (others => '0');
		elsif rising_edge(clock) then
			state		<= state_nxt;
			b			<= b_nxt;
			m			<= m_nxt;
			l			<= l_nxt;
			ch0			<= ch0_nxt;
			ch1			<= ch1_nxt;
			temp		<= temp_nxt;
		end if;
	end process;
	
	process(state, start, b, m, l, temp, ch0, ch1, channel0, channel1)
		variable x : unsigned(33 downto 0) := (others => '0');
	begin
		-- hold previous values by default
		state_nxt	<= state;
		b_nxt		<= b;
		m_nxt		<= m;
		l_nxt		<= l;
		ch0_nxt		<= ch0;
		ch1_nxt		<= ch1;
		temp_nxt	<= temp;
		
		-- default assignments for output signals;
		busy 	<= '1';
		lux		<= l;
		case state is
			when S_IDLE =>
				if start = '1' then
					state_nxt	<= S_RATIO;
					ch0_nxt		<= resize(shift_right(resize(channel0, 31) * 4071, 10), ch0'length);
					ch1_nxt		<= resize(shift_right(resize(channel1, 31) * 4071, 10), ch1'length);					
				end if;
			when S_RATIO =>
				x := resize(ch1 & "000000000", x'length); -- shift ch1 left by 9 bits
				-- find coefficients based on ratio of ch1/ch0
				-- to avoid division `x/ch0 <= k` was changed to `x <= ch0 * k`
				if x >= 0 and x <= RATIO_FACTORS(0).k * ch0 then
					b_nxt <= to_unsigned(RATIO_FACTORS(0).b, b'length);
					m_nxt <= to_unsigned(RATIO_FACTORS(0).m, m'length);
				elsif x <= RATIO_FACTORS(1).k * ch0 then
					b_nxt <= to_unsigned(RATIO_FACTORS(1).b, b'length);
					m_nxt <= to_unsigned(RATIO_FACTORS(1).m, m'length);
				elsif x <= RATIO_FACTORS(2).k * ch0 then
					b_nxt <= to_unsigned(RATIO_FACTORS(2).b, b'length);
					m_nxt <= to_unsigned(RATIO_FACTORS(2).m, m'length);
				elsif x <= RATIO_FACTORS(3).k * ch0 then
					b_nxt <= to_unsigned(RATIO_FACTORS(3).b, b'length);
					m_nxt <= to_unsigned(RATIO_FACTORS(3).m, m'length);
				elsif x <= RATIO_FACTORS(4).k * ch0 then
					b_nxt <= to_unsigned(RATIO_FACTORS(4).b, b'length);
					m_nxt <= to_unsigned(RATIO_FACTORS(4).m, m'length);
				elsif x <= RATIO_FACTORS(5).k * ch0 then
					b_nxt <= to_unsigned(RATIO_FACTORS(5).b, b'length);
					m_nxt <= to_unsigned(RATIO_FACTORS(5).m, m'length);
				elsif x <= RATIO_FACTORS(6).k * ch0 then
					b_nxt <= to_unsigned(RATIO_FACTORS(6).b, b'length);
					m_nxt <= to_unsigned(RATIO_FACTORS(6).m, m'length);
				else
					b_nxt <= to_unsigned(0, b'length);
					m_nxt <= to_unsigned(0, m'length);
				end if;
				state_nxt <= S_SUBSTRACT;
			when S_SUBSTRACT =>
				-- substract both channels with their coefficients
				temp_nxt		<= signed(resize(ch0 * b, temp'length)) - signed(resize(ch1 * m, temp'length));
				state_nxt		<= S_SHIFT;
			when S_SHIFT =>
				-- no values below zero
				if temp > to_signed(0, temp'length) then
					-- shift right by 14 bits
					-- add 8192 (2^13) to ceil integer value (forced round up)
					l_nxt	<= unsigned(resize(shift_right(temp + 8192, 14), l'length));
				else
					l_nxt 	<= (others => '0');
				end if;
				state_nxt	<= S_DONE;
			when S_DONE =>
				-- finished calculation, set busy to '0'
				busy	<= '0';
				if start = '0' then
					-- received acknowledgement signal
					-- go back to idle state
					state_nxt	<= S_IDLE;
				end if;
		end case;	
	end process;
	
end rtl;
