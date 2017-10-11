library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.standard.all;
use std.textio.all;
use std.env.all;

library work;
use work.iac_pkg.all;

entity uart_testbench is

end uart_testbench;

architecture sim of uart_testbench is

	constant SYSTEM_CYCLE_TIME 	: time := 20 ns; -- 50MHz
	constant SIMULATION_TIME 	: time := 100000 * SYSTEM_CYCLE_TIME;

	constant UART_BYTE_COUNT	: natural := 13;
	constant UART_CLOCK_TICKS	: natural := 50;
	constant UART_DATA_WIDTH	: natural := 6; -- 6-bits

	signal clock, reset_n, reset : std_ulogic;

	-- UART registers
	signal uart_clock, uart_clock_nxt		: unsigned(to_log2(UART_CLOCK_TICKS) - 1 downto 0);
	signal uart_sent_bytes, uart_sent_bytes_nxt	: unsigned(to_log2(UART_BYTE_COUNT) - 1 downto 0);
	type uart_protocol_entry_t is record
		cmd	: std_ulogic_vector(1 downto 0);
		data	: std_ulogic_vector(5 downto 0);
	end record;
	type uart_protocol_array is array (natural range <>) of uart_protocol_entry_t;
	signal uart_protocol, uart_protocol_nxt	: uart_protocol_array(0 to UART_BYTE_COUNT - 1);

	type uart_state_t is (S_UART_WAIT, S_UART_START, S_UART_DATA, S_UART_END);
	signal uart_state, uart_state_nxt	: uart_state_t;
	
	signal uart_cs 	 	 	: std_ulogic;
	signal uart_wr 	 	 	: std_ulogic;
	signal uart_addr  	 	: std_ulogic_vector(CW_ADDR_UART-1 downto 0);
	signal uart_din  	 	: std_ulogic_vector(CW_DATA_UART-1 downto 0);
	signal uart_dout 	 	: std_ulogic_vector(CW_DATA_UART-1 downto 0);
	signal uart_irq_rx	 	: std_ulogic;
	signal uart_irq_tx	 	: std_ulogic;
	signal uart_ack_rx	 	: std_ulogic;
	signal uart_ack_tx	 	: std_ulogic;

	signal uart_rts, uart_cts, uart_rxd, uart_txd	: std_ulogic;


	component uart is
		generic (
			SIMULATION 		: boolean := true
		);
        	port (
        		-- global signals
			clock		: in  std_ulogic;
			reset_n		: in  std_ulogic;
			-- bus interface
			iobus_cs	: in  std_ulogic;
			iobus_wr	: in  std_ulogic;
			iobus_addr	: in  std_ulogic_vector(CW_ADDR_UART-1 downto 0);
			iobus_din	: in  std_ulogic_vector(CW_DATA_UART-1 downto 0);
			iobus_dout	: out std_ulogic_vector(CW_DATA_UART-1 downto 0);
			-- IRQ handling
			iobus_irq_rx  	: out  std_ulogic;
			iobus_irq_tx  	: out  std_ulogic;
			iobus_ack_rx  	: in   std_ulogic;
			iobus_ack_tx  	: in   std_ulogic;
			-- pins to outside 
			rts		: in  std_ulogic;
			cts		: out std_ulogic;
			rxd		: in  std_ulogic;
			txd		: out std_ulogic
        	);
	end component uart;
begin

	uart_inst : uart
		generic map (
			SIMULATION 	=> true
		)
		port map (
			-- global signals
			clock		=> clock,
			reset_n		=> reset_n,
			-- bus interface
			iobus_cs	=> uart_cs,
			iobus_wr	=> uart_wr,
			iobus_addr	=> uart_addr,
			iobus_din	=> uart_dout, -- caution!
			iobus_dout	=> uart_din,  -- caution!
			-- IRQ handling
			iobus_irq_rx	=> uart_irq_rx,
			iobus_irq_tx	=> uart_irq_tx,
			iobus_ack_rx	=> uart_ack_rx,
			iobus_ack_tx	=> uart_ack_tx,
			-- pins to outside 
			rts		=> uart_rts,
			cts		=> uart_cts,
			rxd		=> uart_rxd,
			txd		=> uart_txd
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
			uart_state	<= S_UART_WAIT;
			uart_protocol	<= (others => (others => (others => '0')));
			uart_clock	<= (others => '0');
			uart_sent_bytes	<= (others => '0');			
		elsif rising_edge(clock) then
			uart_state	<= uart_state_nxt;
			uart_protocol	<= uart_protocol_nxt;
			uart_clock	<= uart_clock_nxt;
			uart_sent_bytes	<= uart_sent_bytes_nxt;
		end if;
	end process seq;

	comb : process(uart_state, uart_protocol, uart_clock, uart_sent_bytes, uart_irq_tx)
		constant VALUE_COUNT		: natural := 5; -- amount of data segments (four segments for each sensor + one segment including all states (on/off) of peripherals)
		constant SEGMENT_COUNT		: natural := 3; -- 3 bytes per "segment"
		variable i, j			: natural := 0; -- loop variables
		variable segment_cmd		: std_ulogic_vector(1 downto 0);
		variable segment_data		: unsigned(SEGMENT_COUNT * UART_DATA_WIDTH - 1 downto 0);
		variable item			: uart_protocol_entry_t;
	begin
		uart_cs		<= '0';
		uart_wr		<= '0';
		uart_addr	<= (others => '0');
		uart_dout	<= (others => '0');
		uart_ack_rx  	<= '0';
		uart_ack_tx  	<= '0';
		
		-- hold values		
		uart_state_nxt		<= uart_state;
		uart_sent_bytes_nxt	<= uart_sent_bytes;
		
		-- assign sensor values to protocol
		for i in 0 to VALUE_COUNT - 1 loop
			if i = 0 then
				segment_cmd	:= "10";
				segment_data	:= to_unsigned(150, segment_data'length - 2) & "00"; -- replace with lux
			elsif i = 1 then
				segment_cmd	:= "11";
				segment_data	:= to_unsigned(300, segment_data'length - 2) & "01"; -- replace with moisture
			elsif i = 2 then
				segment_cmd	:= "10";
				segment_data	:= to_unsigned(271, segment_data'length - 2) & "10"; -- replace with temp
			elsif i = 3 then
				segment_cmd	:= "11";
				segment_data	:= to_unsigned(3000, segment_data'length - 2) & "11"; -- replace with co2
			else
				segment_cmd	:= "10";
				segment_data	:= (others => '0'); -- replace with peripherals
			end if;
			for j in 0 to SEGMENT_COUNT - 1 loop
				if i < 4 or j = 0 then
					uart_protocol_nxt(j + i * SEGMENT_COUNT) <= (
						segment_cmd, -- cmd
						std_ulogic_vector(resize(shift_right(segment_data, (2 - j) * UART_DATA_WIDTH), UART_DATA_WIDTH)) -- data
					);
				end if;
			end loop;
		end loop; 
		
		-- increment clock independent of state to guarantee stable 1s cycle
		uart_clock_nxt		<= uart_clock + to_unsigned(1, uart_clock'length);		
		case uart_state is
			when S_UART_WAIT =>
				if uart_clock >= to_unsigned(UART_CLOCK_TICKS - 1, uart_clock'length) then
					-- switch to `send` state
					uart_state_nxt	<= S_UART_START;
					uart_clock_nxt	<= (others => '0');
				end if;
			when S_UART_START =>
				if uart_irq_tx = '1' then
					-- start transmission
					uart_cs		<= '1';
					uart_addr	<= CV_ADDR_UART_DATA_TX;
					uart_wr		<= '1';
					
					uart_dout(7 downto 0)	<= "01000000";
					
					uart_state_nxt <= S_UART_DATA;
				end if;
			when S_UART_DATA =>
				if uart_irq_tx = '1' then
					uart_cs		<= '1';
					uart_addr	<= CV_ADDR_UART_DATA_TX;
					uart_wr		<= '1';
					
					item := uart_protocol(to_integer(uart_sent_bytes));
					uart_dout(7 downto 0)	<= item.cmd & item.data;									
					
					if uart_sent_bytes = to_unsigned(UART_BYTE_COUNT - 1, uart_sent_bytes'length) then
						-- last byte sent
						uart_sent_bytes_nxt	<= (others => '0'); -- reset counter
						uart_state_nxt		<= S_UART_END;						
					else
						-- increment counter
						uart_sent_bytes_nxt	<= uart_sent_bytes + to_unsigned(1, uart_sent_bytes'length);
					end if;
				end if;
			when S_UART_END =>
				if uart_irq_tx = '1' then
					uart_cs		<= '1';
					uart_addr	<= CV_ADDR_UART_DATA_TX;
					uart_wr		<= '1';
					
					uart_dout(7 downto 0)	<= "00111111";
					
					uart_state_nxt <= S_UART_WAIT;
				end if;
		end case;
		
	end process comb;
	
end sim;