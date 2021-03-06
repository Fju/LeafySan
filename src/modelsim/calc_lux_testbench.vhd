library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.standard.all;
use std.textio.all;
use std.env.all;

library work;
use work.iac_pkg.all;

entity calc_lux_testbench is

end calc_lux_testbench;

architecture sim of calc_lux_testbench is

	constant SYSTEM_CYCLE_TIME 	: time := 20 ns; -- 50MHz
	constant SIMULATION_TIME 	: time := 100000 * SYSTEM_CYCLE_TIME;

	signal clock, reset_n, reset : std_ulogic;
	
	signal calc_lux_start		: std_ulogic;
	signal calc_lux_busy		: std_ulogic;
	signal calc_lux_value		: unsigned(15 downto 0);
	signal calc_lux_channel0	: unsigned(15 downto 0);
	signal calc_lux_channel1	: unsigned(15 downto 0);


	type state_t is (S_START, S_WAIT_BUSY);
	signal state, state_nxt : state_t;

	signal myval, myval_nxt	: unsigned(15 downto 0);

	component calc_lux is
		port(
		clock		: in  std_ulogic;
		reset		: in  std_ulogic;
		channel0	: in  unsigned(15 downto 0);
		channel1	: in  unsigned(15 downto 0);
		start		: in  std_ulogic;
		busy		: out std_ulogic;
		lux		: out unsigned(15 downto 0)
		);
	end component calc_lux;
begin

	calc_lux_inst : calc_lux
		port map (
			clock => clock,
			reset => reset,
			start => calc_lux_start,
			busy => calc_lux_busy,
			lux => calc_lux_value,
			channel0 => calc_lux_channel0,
			channel1 => calc_lux_channel1
		);

	reset <= not(reset_n);
	

	clk : process
	begin
		clock <= '1';
		wait for SYSTEM_CYCLE_TIME/2;
		clock <= '0';
		wait for SYSTEM_CYCLE_TIME/2;
	end process clk;
	
	rst : process
	begin
		reset_n <= '0';
		wait for 2*SYSTEM_CYCLE_TIME;
		reset_n <= '1';
		wait;
	end process rst;
	
	seq : process(clock, reset)
	begin
		if reset = '1' then
			state <= S_START;
			myval <= to_unsigned(4000, myval'length);
		elsif rising_edge(clock) then
			myval <= myval_nxt;
			state <= state_nxt;
		end if;
	end process seq;

	comb : process(calc_lux_busy, myval, state)
	begin
		state_nxt <= state;
		myval_nxt <= myval;

		calc_lux_start <= '0';
		calc_lux_channel0 <= (others => '0');
		calc_lux_channel1 <= (others => '0');

		case state is			
			when S_START =>
				if myval = to_unsigned(7000, myval'length) then
					myval_nxt <= to_unsigned(4000, myval'length);
				else
					myval_nxt <= myval + to_unsigned(50, myval'length);
				end if;
				
				calc_lux_start <= '1';
				calc_lux_channel0 <= to_unsigned(6300, calc_lux_channel0'length);
				calc_lux_channel1 <= myval;
				state_nxt <= S_WAIT_BUSY;
			when S_WAIT_BUSY =>
				calc_lux_start <= '1';
				if calc_lux_busy = '0' then					
					calc_lux_start <= '0';
					state_nxt <= S_START;
				end if;
		end case;
		
	end process comb;
	
end sim;
