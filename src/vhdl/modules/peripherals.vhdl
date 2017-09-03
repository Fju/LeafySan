library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.iac_pkg.all;

entity peripherals is
	generic (
		LIGHTING_THRESHOLD	: natural := 400;	-- 400lx
		HEATING_THRESHOLD	: natural := 260;	-- 26.0°C
		WATERING_THRESHOLD	: natural := 420	-- no unit
	);
	port(
		clock			: in  std_ulogic;
		reset			: in  std_ulogic;
		temperature		: in  unsigned(11 downto 0);
		brightness		: in  unsigned(15 downto 0);
		moisture		: in  unsigned(15 downto 0);
		
		lighting_on		: out std_ulogic;
		heating_on		: out std_ulogic;
		watering_on		: out std_ulogic;
		ventilation_on	: out std_ulogic
	);
end peripherals;

architecture rtl of peripherals is
	
	constant TIMER_CLOCK_COUNT				: natural := 50000000;	-- 1s
	constant LIGHTING_CYCLE_CLOCK_COUNT		: natural := 5;		-- 5s
	constant HEATING_DELAY_CLOCK_COUNT		: natural := 5;		-- 5s
	constant HEATING_TIMEOUT_CLOCK_COUNT	: natural := 180; 	-- 3min
	constant WATERING_DELAY_CLOCK_COUNT		: natural := 60; 	-- 60s
	constant WATERING_TIMEOUT_CLOCK_COUNT	: natural := 180; 	-- 3min	
	constant VENTILATION_DELAY_COUNT		: natural := 900;	-- 15min
	constant VENTILATION_TIMEOUT_COUNT		: natural := 300;	-- 5min

	type timer_state_t is (S_TIMER_RUNNING, S_TIMER_FINISHED);
	-- no need for lighting state
	type heating_state_t is (S_HEATING_OFF, S_HEATING_ON, S_HEATING_DELAY);
	type watering_state_t is (S_WATERING_OFF, S_WATERING_ON, S_WATERING_DELAY);	
	type ventilation_state_t is (S_VENTILATION_ON, S_VENTILATION_OFF);
	signal timer_state, timer_state_nxt				: timer_state_t;
	signal heating_state, heating_state_nxt			: heating_state_t;
	signal watering_state, watering_state_nxt		: watering_state_t;
	signal ventilation_state, ventilation_state_nxt	: ventilation_state_t;
	
	signal timer_clock, timer_clock_nxt : unsigned(to_log2(TIMER_CLOCK_COUNT) - 1 downto 0);
	signal timer_pulse	: std_ulogic;
	
	signal lighting_clock, lighting_clock_nxt		: unsigned(to_log2(LIGHTING_CYCLE_CLOCK_COUNT) - 1 downto 0);
	signal watering_clock, watering_clock_nxt		: unsigned(to_log2(max(WATERING_DELAY_CLOCK_COUNT, WATERING_TIMEOUT_CLOCK_COUNT)) - 1 downto 0);
	signal heating_clock, heating_clock_nxt			: unsigned(to_log2(max(HEATING_DELAY_CLOCK_COUNT, HEATING_TIMEOUT_CLOCK_COUNT)) - 1 downto 0);
	signal ventilation_clock, ventilation_clock_nxt	: unsigned(to_log2(max(VENTILATION_DELAY_COUNT, VENTILATION_TIMEOUT_COUNT)) - 1 downto 0);
	
	signal lighting_next, lighting_next_nxt			: std_ulogic;
	signal lighting_current, lighting_current_nxt	: std_ulogic;
begin	

	-- sequential process
	process(clock, reset)
	begin
		if reset = '1' then
			timer_state			<= S_TIMER_RUNNING;
			heating_state		<= S_HEATING_OFF;
			watering_state 		<= S_WATERING_OFF;
			ventilation_state	<= S_VENTILATION_OFF;			
			timer_clock			<= (others => '0');
			lighting_clock		<= (others => '0');
			watering_clock		<= (others => '0');
			heating_clock		<= (others => '0');
			ventilation_clock	<= (others => '0');			
			lighting_next		<= '0';
			lighting_current	<= '0';
		elsif rising_edge(clock) then
			timer_state			<= timer_state_nxt;
			heating_state		<= heating_state_nxt;
			watering_state 		<= watering_state_nxt;
			ventilation_state	<= ventilation_state_nxt;			
			timer_clock			<= timer_clock_nxt;
			lighting_clock		<= lighting_clock_nxt;
			watering_clock		<= watering_clock_nxt;
			heating_clock		<= heating_clock_nxt;
			ventilation_clock	<= ventilation_clock_nxt;			
			lighting_next		<= lighting_next_nxt;
			lighting_current	<= lighting_current_nxt;
		end if;
	end process;
	
	-- generate a timer that sets pulse to high every second
	process(timer_state, timer_clock, timer_pulse)
	begin
		-- hold previous values
		timer_state_nxt	<= timer_state;
		timer_clock_nxt	<= timer_clock;
		
		case timer_state is
			when S_TIMER_RUNNING =>
				timer_pulse <= '0';
				if timer_clock = to_unsigned(TIMER_CLOCK_COUNT, timer_clock'length) then
					timer_clock_nxt	<= (others => '0');
					timer_state_nxt	<= S_TIMER_FINISHED;
				else
					timer_clock_nxt	<= timer_clock + to_unsigned(1, timer_clock'length);
				end if;
			when S_TIMER_FINISHED =>
				timer_pulse <= '1';
				timer_state_nxt	<= S_TIMER_RUNNING;
		end case;
	end process;
	
	process(temperature, timer_pulse, heating_state, heating_clock)
	begin
		-- hold previous values
		heating_state_nxt		<= heating_state;
		heating_clock_nxt		<= heating_clock;
		-- `off` by default
		heating_on	<= '0';
		case heating_state is
			when S_HEATING_OFF =>
				-- power on heating only if temperature is 1 degree celsius below the desired value
				if temperature < to_unsigned(HEATING_THRESHOLD - 10, temperature'length) then
					heating_state_nxt <= S_HEATING_ON;
				end if;
			when S_HEATING_ON =>
				heating_on	<= '1';
				-- power off heating if temperature is 1 degree above the desired value
				if temperature >= to_unsigned(HEATING_THRESHOLD + 10, temperature'length) then
					heating_state_nxt	<= S_HEATING_DELAY;
					heating_clock_nxt	<= (others => '0');
				end if;
				if timer_pulse = '1' then					
					if heating_clock = to_unsigned(HEATING_TIMEOUT_CLOCK_COUNT - 1, heating_clock'length) then
						-- in case heating hasn't reach desired temperature after certain time, power off automatically
						heating_state_nxt	<= S_HEATING_DELAY;
						heating_clock_nxt	<= (others => '0');
					else
						heating_clock_nxt <= heating_clock + to_unsigned(1, heating_clock'length);
					end if;
				end if;
			when S_HEATING_DELAY =>				
				if timer_pulse = '1' then								
					if heating_clock = to_unsigned(HEATING_DELAY_CLOCK_COUNT - 1, heating_clock'length) then
					-- end delay
						heating_state_nxt <= S_HEATING_OFF;
						heating_clock_nxt <= (others => '0');
					else
						heating_clock_nxt <= heating_clock + to_unsigned(1, heating_clock'length);
					end if;
				end if;
		end case;
	end process;
	
	process(timer_pulse, lighting_clock, lighting_current, lighting_next, brightness)
	begin
		-- hold previous values
		lighting_clock_nxt		<= lighting_clock;
		lighting_next_nxt		<= lighting_next;
		lighting_current_nxt	<= lighting_current;
		
		-- `off` by default
		lighting_on <= lighting_current;		
		if timer_pulse = '1' then
			if lighting_clock = to_unsigned(LIGHTING_CYCLE_CLOCK_COUNT - 1, lighting_clock'length) then
				-- reset clock and update registers
				lighting_clock_nxt	<= (others => '0');
				lighting_current_nxt	<= lighting_next;
				lighting_next_nxt		<= not(lighting_current);
			else
				-- increment clock register and update/hold next state register value
				lighting_clock_nxt	<= lighting_clock + to_unsigned(1, lighting_clock'length);				
				if lighting_current = '0' then
					-- lighting is turned off currently
					if brightness >= to_unsigned(LIGHTING_THRESHOLD, temperature'length) then
						-- next lighting state will be `off` again, because not all values were below threshold (too bright)
						lighting_next_nxt <= '0';					
					end if;
					-- otherwise the next lighting state will be `on`, see `not(lighting_current)` line 158
				else
					-- lighting is turned on currently
					if brightness <= to_unsigned(LIGHTING_THRESHOLD, temperature'length) then
						-- next lighting state will be `on` again, because not all values were above threshold (too dark)
						lighting_next_nxt	<= '1';
					end if;
					-- otherwise the next lighting state will be `off`, see `not(lighting_current)` line 158
				end if;					
			end if;
		end if;
	end process;
	
	process(timer_pulse, watering_state, watering_clock, moisture)
	begin
		-- hold previous values
		watering_state_nxt		<= watering_state;
		watering_clock_nxt		<= watering_clock;
		
		-- `off` by default
		watering_on	<= '0';
		case watering_state is
			when S_WATERING_OFF =>
				-- power on watering only if moisture value is 10 steps below threshold
				if moisture < to_unsigned(WATERING_THRESHOLD - 10, moisture'length) then
					watering_state_nxt <= S_WATERING_ON;
				end if;
			when S_WATERING_ON =>
				watering_on	<= '1';
				-- power off watering if moisture is above threshold
				if moisture >= to_unsigned(WATERING_THRESHOLD, moisture'length) then
					watering_state_nxt	<= S_WATERING_DELAY;
					watering_clock_nxt	<= (others => '0');
				end if;
				if timer_pulse = '1' then					
					if watering_clock = to_unsigned(WATERING_TIMEOUT_CLOCK_COUNT - 1, watering_clock'length) then
						-- in case watering hasn't reach desired moisture after certain time, power off automatically
						-- in order to prevent permanent watering
						watering_state_nxt	<= S_WATERING_DELAY;
						watering_clock_nxt	<= (others => '0');
					else
						watering_clock_nxt <= watering_clock + to_unsigned(1, watering_clock'length);
					end if;
				end if;
			when S_WATERING_DELAY =>				
				if timer_pulse = '1' then								
					if watering_clock = to_unsigned(WATERING_DELAY_CLOCK_COUNT - 1, watering_clock'length) then
						-- end delay
						watering_state_nxt <= S_WATERING_OFF;
						watering_clock_nxt <= (others => '0');
					else
						watering_clock_nxt <= watering_clock + to_unsigned(1, watering_clock'length);
					end if;
				end if;				
		end case;
	end process;
	
	process(timer_pulse, ventilation_state, ventilation_clock)
	begin
		-- hold previous values
		ventilation_state_nxt	<= ventilation_state;
		ventilation_clock_nxt	<= ventilation_clock;
		
		-- `off` by default
		ventilation_on <= '0';		
		case ventilation_state is
			when S_VENTILATION_OFF =>
				if timer_pulse = '1' then
					if ventilation_clock = to_unsigned(VENTILATION_DELAY_COUNT - 1, ventilation_clock'length) then
						ventilation_clock_nxt	<= (others => '0');
						ventilation_state_nxt	<= S_VENTILATION_ON;
					else
						ventilation_clock_nxt	<= ventilation_clock + to_unsigned(1, ventilation_clock'length);
					end if;
				end if;
			when S_VENTILATION_ON =>
				ventilation_on <= '1';
				if timer_pulse = '1' then
					if ventilation_clock = to_unsigned(VENTILATION_TIMEOUT_COUNT - 1, ventilation_clock'length) then
						ventilation_clock_nxt	<= (others => '0');
						ventilation_state_nxt	<= S_VENTILATION_OFF;
					else
						ventilation_clock_nxt	<= ventilation_clock + to_unsigned(1, ventilation_clock'length);
					end if;
				end if;
		end case;
	end process;
end rtl;
