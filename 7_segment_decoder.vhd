library ieee;
use ieee.std_logic_1164.all;

entity 7_segment_decoder is
port (	code : in std_logic_vector(3 downto 0);
	RippleBlank_In : in std_logic;
	RippleBlank_Out : out std_logic;
	segments : out std_logic_vector(6 downto 0));
end 7_segment_decoder;

architecture implementation1 of 7_segment_decoder is
signal inter : std_logic_vector (4 downto 0);
	begin
		inter <= RippleBlank_In & code;
		with inter select
		segments <= 
			"1111111" when "10000",
			"0000001" when "00000",
			"1001111" when "00001",
			"1001111" when "10001",
			"0010010" when "00010", 
			"0010010" when "10010",
			"0000110" when "00011", 
			"0000110" when "10011",
			"1001100" when "00100", 
			"1001100" when "10100",
			"0100100" when "00101",
			"0100100" when "10101",	
			"0100000" when "00110", 
			"0100000" when "10110",	
			"0001111" when "00111",
			"0001111" when "10111",	
			"0000000" when "01000",
			"0000000" when "11000",
			"0001100" when "01001",
			"0001100" when "11001",
			"0001000" when "01010", 
			"0001000" when "11010",
			"1100000" when "01011",
			"1100000" when "11011",
			"1110010" when "01100",
			"1110010" when "11100",
			"1000010" when "01101",
			"1000010" when "11101",
			"0110000" when "01110",
			"0110000" when "11110",
			"0111000" when "01111",
			"0111000" when "11111",
			"1111110" when others;
		with inter select RippleBlank_Out <= '1' when "10000", '0' when others;
end implementation1;