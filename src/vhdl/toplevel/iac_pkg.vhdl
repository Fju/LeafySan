-----------------------------------------------------------------------------------------
-- Project      : 	Invent a Chip
-- Module       : 	Package File Constants
-- Author 		: 	Jan Dürre
-- Last update  : 	21.05.2015
-- Description	: 	-
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package iac_pkg is
	
	-- other constants
	constant CV_SYS_CLOCK_RATE 			: natural := 50000000; --50 MHz
	
	-- addresses
	-- seven seg
	constant CW_DATA_SEVENSEG 			: natural := 16;
	constant CW_ADDR_SEVENSEG 			: natural := 5;
	constant CV_ADDR_SEVENSEG_DEC 		: std_ulogic_vector(CW_ADDR_SEVENSEG-1 downto 0) := std_ulogic_vector(to_unsigned( 1, CW_ADDR_SEVENSEG));
	constant CV_ADDR_SEVENSEG_HEX4 		: std_ulogic_vector(CW_ADDR_SEVENSEG-1 downto 0) := std_ulogic_vector(to_unsigned( 2, CW_ADDR_SEVENSEG));
	constant CV_ADDR_SEVENSEG_HEX5 		: std_ulogic_vector(CW_ADDR_SEVENSEG-1 downto 0) := std_ulogic_vector(to_unsigned( 4, CW_ADDR_SEVENSEG));
	constant CV_ADDR_SEVENSEG_HEX6 		: std_ulogic_vector(CW_ADDR_SEVENSEG-1 downto 0) := std_ulogic_vector(to_unsigned( 8, CW_ADDR_SEVENSEG));
	constant CV_ADDR_SEVENSEG_HEX7 		: std_ulogic_vector(CW_ADDR_SEVENSEG-1 downto 0) := std_ulogic_vector(to_unsigned(16, CW_ADDR_SEVENSEG));
	-- adc/dac
	constant CW_DATA_ADC_DAC 			: natural := 12;
	constant CW_ADDR_ADC_DAC 			: natural := 4;
	constant CV_ADDR_ADC0 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 0, CW_ADDR_ADC_DAC));
	constant CV_ADDR_ADC1 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 1, CW_ADDR_ADC_DAC));
	constant CV_ADDR_ADC2 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 2, CW_ADDR_ADC_DAC));
	constant CV_ADDR_ADC3 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 3, CW_ADDR_ADC_DAC));
	constant CV_ADDR_ADC4 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 4, CW_ADDR_ADC_DAC));
	constant CV_ADDR_ADC5 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 5, CW_ADDR_ADC_DAC));
	constant CV_ADDR_ADC6 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 6, CW_ADDR_ADC_DAC));
	constant CV_ADDR_ADC7 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 7, CW_ADDR_ADC_DAC));
	constant CV_ADDR_DAC0 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 8, CW_ADDR_ADC_DAC));
	constant CV_ADDR_DAC1 				: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned( 9, CW_ADDR_ADC_DAC));
	constant CV_ADDR_ADC_DAC_CTRL		: std_ulogic_vector(CW_ADDR_ADC_DAC-1 downto 0) := std_ulogic_vector(to_unsigned(10, CW_ADDR_ADC_DAC));
	-- audio
	constant CW_DATA_AUDIO				: natural := 16;
	constant CW_ADDR_AUDIO 				: natural := 2;
	constant CV_ADDR_AUDIO_LEFT_IN		: std_ulogic_vector(CW_ADDR_AUDIO-1 downto 0) := std_ulogic_vector(to_unsigned(0, CW_ADDR_AUDIO));
	constant CV_ADDR_AUDIO_RIGHT_IN		: std_ulogic_vector(CW_ADDR_AUDIO-1 downto 0) := std_ulogic_vector(to_unsigned(1, CW_ADDR_AUDIO));
	constant CV_ADDR_AUDIO_LEFT_OUT		: std_ulogic_vector(CW_ADDR_AUDIO-1 downto 0) := std_ulogic_vector(to_unsigned(0, CW_ADDR_AUDIO));
	constant CV_ADDR_AUDIO_RIGHT_OUT	: std_ulogic_vector(CW_ADDR_AUDIO-1 downto 0) := std_ulogic_vector(to_unsigned(1, CW_ADDR_AUDIO));
	constant CV_ADDR_AUDIO_CONFIG		: std_ulogic_vector(CW_ADDR_AUDIO-1 downto 0) := std_ulogic_vector(to_unsigned(2, CW_ADDR_AUDIO));
	constant CW_AUDIO_SAMPLE 			: natural := 16;
	-- infrared
	constant CW_DATA_IR 				: natural := 8;
	constant CW_ADDR_IR 				: natural := 1;
	constant CV_ADDR_IR_DATA 			: std_ulogic_vector(CW_ADDR_IR-1 downto 0) := std_ulogic_vector(to_unsigned(0, CW_ADDR_IR));
	constant C_IR_BUTTON_A				: std_ulogic_vector(7 downto 0) := x"0F";
	constant C_IR_BUTTON_B				: std_ulogic_vector(7 downto 0) := x"13";
	constant C_IR_BUTTON_C				: std_ulogic_vector(7 downto 0) := x"10";
	constant C_IR_BUTTON_POWER			: std_ulogic_vector(7 downto 0) := x"12";
	constant C_IR_BUTTON_1				: std_ulogic_vector(7 downto 0) := x"01";
	constant C_IR_BUTTON_2				: std_ulogic_vector(7 downto 0) := x"02";
	constant C_IR_BUTTON_3				: std_ulogic_vector(7 downto 0) := x"03";
	constant C_IR_BUTTON_4				: std_ulogic_vector(7 downto 0) := x"04";
	constant C_IR_BUTTON_5				: std_ulogic_vector(7 downto 0) := x"05";
	constant C_IR_BUTTON_6				: std_ulogic_vector(7 downto 0) := x"06";
	constant C_IR_BUTTON_7				: std_ulogic_vector(7 downto 0) := x"07";
	constant C_IR_BUTTON_8				: std_ulogic_vector(7 downto 0) := x"08";
	constant C_IR_BUTTON_9				: std_ulogic_vector(7 downto 0) := x"09";
	constant C_IR_BUTTON_0				: std_ulogic_vector(7 downto 0) := x"00";
	constant C_IR_BUTTON_CHANNEL_UP		: std_ulogic_vector(7 downto 0) := x"1A";
	constant C_IR_BUTTON_CHANNEL_DOWN	: std_ulogic_vector(7 downto 0) := x"1E";
	constant C_IR_BUTTON_VOLUME_UP		: std_ulogic_vector(7 downto 0) := x"1B";
	constant C_IR_BUTTON_VOLUME_DOWN	: std_ulogic_vector(7 downto 0) := x"1F";
	constant C_IR_BUTTON_MUTE			: std_ulogic_vector(7 downto 0) := x"0C";
	constant C_IR_BUTTON_MENU			: std_ulogic_vector(7 downto 0) := x"11";
	constant C_IR_BUTTON_RETURN			: std_ulogic_vector(7 downto 0) := x"17";
	constant C_IR_BUTTON_PLAY			: std_ulogic_vector(7 downto 0) := x"16";
	constant C_IR_BUTTON_LEFT			: std_ulogic_vector(7 downto 0) := x"14";
	constant C_IR_BUTTON_RIGHT			: std_ulogic_vector(7 downto 0) := x"18";
	-- lcd
	constant CW_DATA_LCD 				: natural := 8;
	constant CW_ADDR_LCD 				: natural := 1;
	constant CV_ADDR_LCD_DATA			: std_ulogic_vector(CW_ADDR_LCD-1 downto 0) := std_ulogic_vector(to_unsigned(0, CW_ADDR_LCD));
	constant CV_ADDR_LCD_STATUS			: std_ulogic_vector(CW_ADDR_LCD-1 downto 0) := std_ulogic_vector(to_unsigned(0, CW_ADDR_LCD));
	constant CS_LCD_BUFFER				: natural := 32;
	constant C_LCD_CLEAR				: std_ulogic_vector(7 downto 0) := "00000000";
	constant C_LCD_CURSOR_ON			: std_ulogic_vector(7 downto 0) := "00000001";
	constant C_LCD_CURSOR_OFF			: std_ulogic_vector(7 downto 0) := "00000010";
	constant C_LCD_BLINK_ON				: std_ulogic_vector(7 downto 0) := "00000011";
	constant C_LCD_BLINK_OFF			: std_ulogic_vector(7 downto 0) := "00000100";
	constant C_LCD_CURSOR_LEFT			: std_ulogic_vector(7 downto 0) := "00000101";
	constant C_LCD_CURSOR_RIGHT			: std_ulogic_vector(7 downto 0) := "00000110";
	-- sram
	constant CW_DATA_SRAM 				: natural := 16;
	constant CW_ADDR_SRAM 				: natural := 20;
	-- uart
	constant CW_DATA_UART				: natural := 8;
	constant CW_ADDR_UART 				: natural := 1;
	constant CV_ADDR_UART_DATA_RX		: std_ulogic_vector(CW_ADDR_UART-1 downto 0) := std_ulogic_vector(to_unsigned(0, CW_ADDR_UART));
	constant CV_ADDR_UART_DATA_TX		: std_ulogic_vector(CW_ADDR_UART-1 downto 0) := std_ulogic_vector(to_unsigned(0, CW_ADDR_UART));
	constant CS_UART_BUFFER				: natural := 256;
	constant CV_UART_BAUDRATE			: natural := 115200;
	constant CV_UART_DATABITS 			: natural := 8;
	constant CV_UART_STOPBITS 			: natural := 1;
	constant CS_UART_PARITY 			: string  := "NONE";
	
	-- modules enable (0/1)
	constant CV_EN_SEVENSEG : natural := 1;
	constant CV_EN_ADC_DAC 	: natural := 1;
	constant CV_EN_AUDIO 	: natural := 1;
	constant CV_EN_IR 		: natural := 1;
	constant CV_EN_LCD		: natural := 1;
	constant CV_EN_SRAM 	: natural := 1;
	constant CV_EN_UART 	: natural := 1;	
	
	
	
	-- functions
	
	-- generic
	-- constant integer log to base 2
	function to_log2 (constant input : natural) return natural;
	-- constant integer log to base 16
	function to_log16 (constant input : natural) return natural;
	-- bcd decode
	function to_bcd (binary : std_ulogic_vector; constant no_dec_digits : natural) return std_ulogic_vector;
	-- vector generation from single bit
	function to_vector(single_bit : std_ulogic; constant size : natural) return std_ulogic_vector;
	function to_vector(single_bit : std_logic; constant size : natural) return std_logic_vector;
	-- min / max
	function max(a, b: integer) return integer;
	function max(a, b: unsigned) return unsigned;
	function max(a, b, c: integer) return integer;
	function max(a, b, c: unsigned) return unsigned;
	function min(a, b: integer) return integer;
	function min(a, b: unsigned) return unsigned;
	function min(a, b, c: integer) return integer;
	function min(a, b, c: unsigned) return unsigned;
	
	-- lcd
	-- convert character or string to ascii binary vector
	function ascii(input_char : character) return std_ulogic_vector;
	-- additional LUT just for numbers (0 to 9), to prevent a large complete ASCII-LUT when only numbers are required
	function ascii(input_number : unsigned(3 downto 0)) return std_ulogic_vector;
	function asciitext(constant input_string : string) return std_ulogic_vector;
	-- generate hex-string from binary numbers (length of binary vector has to be multiple of 4)
	function hex(input_vector : std_ulogic_vector) return string;
	-- convert std_ulogic_vector to array of commands for LCD-display
	type lcd_commands_t is array (natural range <>) of std_ulogic_vector(7 downto 0);
	function lcd_cmd(input_vector : std_ulogic_vector) return lcd_commands_t;
	-- convert coordinate into bit-command for lcd-display
	function lcd_cursor_pos(row : natural; col : natural) return std_ulogic_vector;
	
	-- uart
	function calc_parity(data : std_ulogic_vector; parity : string) return std_ulogic;
	
	
end;

package body iac_pkg is

	-- generic
	-- constant integer log to base 2
	function to_log2 (constant input : natural) return natural is
		variable temp : natural := 2;
		variable res  : natural := 1;
	begin

		if temp < input then
			while temp < input loop
				temp	:= temp * 2;
				res		:= res + 1;
			end loop;
		end if;
		
		return res;
	end function;
	
	-- constant integer log to base 16
	function to_log16 (constant input : natural) return natural is
		variable temp : natural := 16;
		variable res  : natural := 1;
	begin

		if temp < input then
			while temp < input loop
				temp	:= temp * 16;
				res		:= res + 1;
			end loop;
		end if;
		
		return res;
	end function;
	
	-- bcd decode, returns n 4-bit-bcd packages (implemented with double daddle algorithm http://en.wikipedia.org/wiki/Double_dabble), fully synthezisable
	function to_bcd (binary : std_ulogic_vector; constant no_dec_digits : natural) return std_ulogic_vector is
		variable tmp : std_ulogic_vector(binary'length + 4*no_dec_digits -1 downto 0) := (others => '0');
	begin
		tmp(binary'length-1 downto 0) := binary;
		-- loop for n times
		for i in 0 to binary'length-1 loop
			
			-- check if any of the 3 bcd digits is greater than 4
			for j in no_dec_digits-1 downto 0 loop
				if unsigned(tmp((j+1)*4 -1 + binary'length downto j*4+ binary'length)) > to_unsigned(4, 4) then
					-- add 3
					tmp((j+1)*4 - 1 + binary'length downto j*4+ binary'length) := std_ulogic_vector(unsigned(tmp((j+1)*4 - 1 + binary'length downto j*4+ binary'length)) + to_unsigned(3, 4));
				end if;
			end loop;
			
			-- shift left
			tmp := tmp(tmp'length-2 downto 0) & '0';
		end loop;
		
		return tmp(tmp'length-1 downto binary'length);
		
	end function;
	
	-- vector generation from single bit: returns a vector, each bit consists of single_bit
	function to_vector(single_bit : std_ulogic; constant size : natural) return std_ulogic_vector is
		variable tmp : std_ulogic_vector(size-1 downto 0);
	begin
		for i in 0 to size-1 loop
			tmp(i) := single_bit;
		end loop;
		return tmp;
	end function;
	
	function to_vector(single_bit : std_logic; constant size : natural) return std_logic_vector is
		variable tmp : std_logic_vector(size-1 downto 0);
	begin
		for i in 0 to size-1 loop
			tmp(i) := single_bit;
		end loop;
		return tmp;
	end function;
	
	-- min / max
	function max(a, b: integer) return integer is
	begin
		if a > b then
			return a;
		else
			return b;
		end if;
	end function;
	
	function max(a, b: unsigned) return unsigned is
	begin
		if a > b then
			return a;
		else
			return b;
		end if;
	end function;
	
	function max(a, b, c: integer) return integer is
	begin
		return max(max(a,b),c);
	end function;
	
	function max(a, b, c: unsigned) return unsigned is
	begin
		return max(max(a,b),c);
	end function;
	
	function min(a, b: integer) return integer is
	begin
		if a < b then
			return a;
		else
			return b;
		end if;
	end function;
	
	function min(a, b: unsigned) return unsigned is
	begin
		if a < b then
			return a;
		else
			return b;
		end if;
	end function;
	
	function min(a, b, c: integer) return integer is
	begin
		return min(min(a,b),c);
	end function;
	
	function min(a, b, c: unsigned) return unsigned is
	begin
		return min(min(a,b),c);
	end function;

	-- lcd
	-- convert character or string to ascii binary vector
	function ascii(input_char : character) return std_ulogic_vector is
	begin
		return std_ulogic_vector(to_unsigned(character'pos(input_char),8));
	end function;
	
	-- additional LUT just for numbers (0 to 9), to prevent a large complete ASCII-LUT when only numbers are required
	function ascii(input_number : unsigned(3 downto 0)) return std_ulogic_vector is
	begin
		if 		input_number = "0000" then	return "0011" & std_ulogic_vector(input_number);	-- 0
		elsif 	input_number = "0001" then	return "0011" & std_ulogic_vector(input_number);	-- 1
		elsif 	input_number = "0010" then	return "0011" & std_ulogic_vector(input_number);	-- 2
		elsif 	input_number = "0011" then	return "0011" & std_ulogic_vector(input_number);	-- 3
		elsif 	input_number = "0100" then	return "0011" & std_ulogic_vector(input_number);	-- 4
		elsif 	input_number = "0101" then	return "0011" & std_ulogic_vector(input_number);	-- 5
		elsif 	input_number = "0110" then	return "0011" & std_ulogic_vector(input_number);	-- 6
		elsif 	input_number = "0111" then	return "0011" & std_ulogic_vector(input_number);	-- 7
		elsif 	input_number = "1000" then	return "0011" & std_ulogic_vector(input_number);	-- 8
		elsif 	input_number = "1001" then	return "0011" & std_ulogic_vector(input_number);	-- 9
		else 								return "01011000";									-- unexpected: return X
		end if;
	end function;
	
	function asciitext(constant input_string : string) return std_ulogic_vector is
		variable returntext : std_ulogic_vector((8*input_string'length)-1 downto 0);
	begin
		for i in 0 to input_string'length-1 loop
			returntext((i+1)*8 -1 downto i*8) := std_ulogic_vector(to_unsigned(character'pos(input_string(input_string'length-i)),8));
		end loop;
		
		return returntext;
	end function;
	
	-- generate hex-string from binary numbers (length of binary vector has to be multiple of 4)
	function hex(input_vector : std_ulogic_vector) return string is
		variable tempchar 		: character;
		variable four_block 	: std_ulogic_vector(3 downto 0);
		variable returnstring 	: string(1 to input_vector'length/4);
	begin
		for i in 0 to input_vector'length/4 -1 loop
		
			four_block := input_vector((i+1)*4 -1 downto i*4);
		
			case four_block is
				when "0000" => tempchar := '0';
				when "0001" => tempchar := '1';
				when "0010" => tempchar := '2';
				when "0011" => tempchar := '3';
				when "0100" => tempchar := '4';
				when "0101" => tempchar := '5';
				when "0110" => tempchar := '6';
				when "0111" => tempchar := '7';
				when "1000" => tempchar := '8';
				when "1001" => tempchar := '9';
				when "1010" => tempchar := 'A';
				when "1011" => tempchar := 'B';
				when "1100" => tempchar := 'C';
				when "1101" => tempchar := 'D';
				when "1110" => tempchar := 'E';
				when "1111" => tempchar := 'F';
				when others => tempchar := 'U';
			end case;
			
			returnstring(input_vector'length/4 - i) := tempchar;
			
		end loop;
  		
		return returnstring;
	end function;
	
	-- convert std_ulogic_vector to array of commands for LCD-display
	function lcd_cmd(input_vector : std_ulogic_vector) return lcd_commands_t is
		variable input_vector_dirnorm 	: std_ulogic_vector(input_vector'length-1 downto 0);
		variable return_array 			: lcd_commands_t(0 to (input_vector'length/8)-1);
	begin
		input_vector_dirnorm := input_vector;
		
		for i in 0 to (input_vector'length/8)-1 loop
			for j in 0 to 7 loop
				return_array(i)(7-j) := input_vector_dirnorm(input_vector'length -1 -i*8 - j);
			end loop;
		end loop;
	
		return return_array;
	end function;
	
	-- convert coordinate into bit-command for lcd-display
	function lcd_cursor_pos(row : natural; col : natural) return std_ulogic_vector is
	begin
		if row = 0 then 
			return "1000" & std_ulogic_vector(to_unsigned(col, 4));
		else 
			return "1001" & std_ulogic_vector(to_unsigned(col, 4));
		end if;
	end function;
	
	
	-- uart
	function calc_parity(data : std_ulogic_vector; parity : string) return std_ulogic is
		variable v : std_ulogic;
	begin
		for i in 0 to data'length-1 loop
			v := v xor data(i);
		end loop;
	
		if parity = "EVEN" then
			return v;
		else
			return not v;
		end if;
	end function;
	
	
end iac_pkg;
