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

	constant UART_WR_BYTE_COUNT	: natural := 13;
	constant UART_RD_BYTE_COUNT	: natural := 9;
	constant UART_DATA_WIDTH	: natural := 6; -- 6-bits

	signal clock, reset_n, reset : std_ulogic;

	-- UART registers
	signal uart_sent_bytes, uart_sent_bytes_nxt		: unsigned(to_log2(UART_WR_BYTE_COUNT) - 1 downto 0);
	signal uart_received_bytes, uart_received_bytes_nxt	: unsigned(to_log2(UART_RD_BYTE_COUNT) - 1 downto 0);
	type uart_protocol_entry_t is record
		cmd	: std_ulogic_vector(1 downto 0);
		data	: std_ulogic_vector(5 downto 0);
	end record;
	type uart_protocol_array is array (natural range <>) of uart_protocol_entry_t;
	signal uart_wr_array, uart_wr_array_nxt			: uart_protocol_array(0 to UART_WR_BYTE_COUNT - 1);
	signal uart_rd_array, uart_rd_array_nxt			: uart_protocol_array(0 to UART_RD_BYTE_COUNT);

	type uart_state_t is (S_UART_RD_WAIT_START, S_UART_RD_READ_LOOP, S_UART_WR_START, S_UART_WR_WRITE_LOOP, S_UART_WR_END);
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

	signal end_simulation		: std_ulogic;

	signal heating_thresh, heating_thresh_nxt		: unsigned(11 downto 0);
	signal lighting_thresh, lighting_thresh_nxt	: unsigned(15 downto 0);
	signal watering_thresh, watering_thresh_nxt	: unsigned(15 downto 0);


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

	component uart_model is
		generic (
			SYSTEM_CYCLE_TIME 	: time;
			FILE_NAME_COMMAND 	: string;
			FILE_NAME_DUMP 		: string;
			BAUD_RATE 		: natural;
			SIMULATION		: boolean
		);
		port (
			end_simulation	: in  std_ulogic;
			rx 				: in  std_ulogic; 
			tx 				: out std_ulogic
		);
	end component uart_model;
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

	uart_model_inst : uart_model
		generic map (
			SYSTEM_CYCLE_TIME 	=> SYSTEM_CYCLE_TIME,
			FILE_NAME_COMMAND 	=> "uart_command.txt",
			FILE_NAME_DUMP 		=> "uart_dump.txt",
			BAUD_RATE 		=> CV_UART_BAUDRATE,
			SIMULATION 		=> true
		)
		port map (
			end_simulation	=> end_simulation,
			rx 		=> uart_txd,
			tx 		=> uart_rxd
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

	end_sim : process
	begin
		end_simulation <= '0';
		wait for SIMULATION_TIME;
		end_simulation <= '1';
		wait;
	end process end_sim;
	
	seq : process(clock, reset)
	begin
		if reset = '1' then
			uart_state		<= S_UART_RD_WAIT_START;
			uart_wr_array		<= (others => (others => (others => '0')));
			uart_rd_array		<= (others => (others => (others => '0')));
			uart_sent_bytes		<= (others => '0');
			uart_received_bytes	<= (others => '0');
			heating_thresh		<= to_unsigned(240, heating_thresh'length);  -- 24,0 °C
			lighting_thresh		<= to_unsigned(400, lighting_thresh'length); -- 400 lx
			watering_thresh		<= to_unsigned(500, watering_thresh'length); -- 50,0 %
		elsif rising_edge(clock) then
			uart_state		<= uart_state_nxt;
			uart_wr_array		<= uart_wr_array_nxt;
			uart_rd_array		<= uart_rd_array_nxt;
			uart_sent_bytes		<= uart_sent_bytes_nxt;
			uart_received_bytes	<= uart_received_bytes_nxt;
			heating_thresh		<= heating_thresh_nxt;
			lighting_thresh		<= lighting_thresh_nxt;
			watering_thresh		<= watering_thresh_nxt;
		end if;
	end process seq;

	comb : process(uart_state, uart_wr_array, uart_rd_array, uart_sent_bytes, uart_received_bytes, uart_irq_tx, uart_irq_rx, uart_din, lighting_thresh, watering_thresh, heating_thresh)
		constant VALUE_COUNT		: natural := 5; -- amount of data segments (four segments for each sensor + one segment including all states (on/off) of peripherals)
		constant SEGMENT_COUNT		: natural := 3; -- 3 bytes per "segment"
		variable i, j			: natural := 0; -- loop variables
		variable segment_cmd		: std_ulogic_vector(1 downto 0);
		variable segment_data		: unsigned(SEGMENT_COUNT * UART_DATA_WIDTH - 1 downto 0);
		variable item			: uart_protocol_entry_t;
		variable segment_value		: std_ulogic_vector(15 downto 0);
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
		uart_received_bytes_nxt	<= uart_received_bytes;
		uart_rd_array_nxt	<= uart_rd_array;

		lighting_thresh_nxt	<= lighting_thresh;
		watering_thresh_nxt	<= watering_thresh;
		heating_thresh_nxt	<= heating_thresh;
		
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
					uart_wr_array_nxt(j + i * SEGMENT_COUNT) <= (
						segment_cmd, -- cmd
						std_ulogic_vector(resize(shift_right(segment_data, (2 - j) * UART_DATA_WIDTH), UART_DATA_WIDTH)) -- data
					);
				end if;
			end loop;
		end loop;
		
		case uart_state is
			when S_UART_RD_WAIT_START =>
				if uart_irq_rx = '1' then 
					uart_cs <= '1';
					uart_addr <= CV_ADDR_UART_DATA_RX;
					uart_wr	<= '0';
					-- save data
					if uart_din(7 downto 0) = "01000000" then
						uart_received_bytes_nxt <= to_unsigned(0, uart_received_bytes'length);
						uart_rd_array_nxt	<= (others => (others => (others => '0')));
						uart_state_nxt		<= S_UART_RD_READ_LOOP;
					end if;
				end if;
			when S_UART_RD_READ_LOOP =>
				if uart_irq_rx = '1' then 
					uart_cs <= '1';
					uart_addr <= CV_ADDR_UART_DATA_RX;
					uart_wr	<= '0';
					
					-- increment counter					
					if uart_din(7 downto 0) = "00111111" then
						-- received end command
						if uart_received_bytes = to_unsigned(UART_RD_BYTE_COUNT, uart_received_bytes'length) then
							for i in 0 to 2 loop
								if uart_rd_array(i*3).cmd = "10" or uart_rd_array(i*3).cmd = "11" then
									segment_value := uart_rd_array(i*3).data & uart_rd_array(i*3+1).data & uart_rd_array(i*3+2).data(5 downto 2);
									if uart_rd_array(i*3+2).data(1 downto 0) = "00" then
										lighting_thresh_nxt	<= unsigned(segment_value);
									elsif uart_rd_array(i*3+2).data(1 downto 0) = "01" then
										watering_thresh_nxt	<= unsigned(segment_value);
									elsif uart_rd_array(i*3+2).data(1 downto 0) = "10" then
										heating_thresh_nxt	<= resize(unsigned(segment_value), heating_thresh'length);
									end if;
								end if;
							end loop;
						end if;
						uart_state_nxt	<= S_UART_WR_START;
					else						
						uart_rd_array_nxt(to_integer(uart_received_bytes)) <= (
							uart_din(7 downto 6),	-- cmd
							uart_din(5 downto 0)	-- data
						);
						uart_received_bytes_nxt	<= uart_received_bytes + to_unsigned(1, uart_received_bytes'length); 
					end if;
				end if;
			when S_UART_WR_START =>
				if uart_irq_tx = '1' then					
					uart_cs		<= '1';
					uart_addr	<= CV_ADDR_UART_DATA_TX;
					uart_wr		<= '1';
					-- write `start` cmd
					uart_dout(7 downto 0)	<= "01000000";
					-- 
					uart_state_nxt <= S_UART_WR_WRITE_LOOP;
				end if;
			when S_UART_WR_WRITE_LOOP =>
				if uart_irq_tx = '1' then
					uart_cs		<= '1';
					uart_addr	<= CV_ADDR_UART_DATA_TX;
					uart_wr		<= '1';
					
					item := uart_wr_array(to_integer(uart_sent_bytes));
					uart_dout(7 downto 0)	<= item.cmd & item.data;									
					
					if uart_sent_bytes = to_unsigned(UART_WR_BYTE_COUNT - 1, uart_sent_bytes'length) then
						-- last byte sent
						uart_sent_bytes_nxt	<= (others => '0'); -- reset counter
						uart_state_nxt		<= S_UART_WR_END;						
					else
						-- increment counter
						uart_sent_bytes_nxt	<= uart_sent_bytes + to_unsigned(1, uart_sent_bytes'length);
					end if;
				end if;
			when S_UART_WR_END =>
				if uart_irq_tx = '1' then
					uart_cs		<= '1';
					uart_addr	<= CV_ADDR_UART_DATA_TX;
					uart_wr		<= '1';
					-- write `end` cmd
					uart_dout(7 downto 0)	<= "00111111";
					
					uart_state_nxt <= S_UART_RD_WAIT_START;
				end if;
		end case;
		
	end process comb;
	
end sim;