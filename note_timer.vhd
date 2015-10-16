library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lpm;
use lpm.lpm_components.all;

entity note_timer is

port ( 	clk : in std_logic;
		reset : in std_logic;
		note_duration : in std_logic_vector(2 downto 0);
		triplet : in std_logic;
		tempo_enable : in std_logic;
		TRIGGER : out std_logic;
		outputCount : out unsigned(8 downto 0) );

end note_timer;

architecture implementation of note_timer is

signal count : integer range 0 to 384;
signal duration : std_logic_vector(8 downto 0);
signal duration_triplet : std_logic_vector(8 downto 0);
signal ACTUAL_duration : std_logic_vector(8 downto 0);
signal ACTUAL_duration_int : unsigned(8 downto 0);

begin

	crc_table1 : lpm_rom -- use the altera rom library macrocell
		GENERIC MAP(
		lpm_widthad => 3, -- sets the width of the ROM address bus
		lpm_numwords => 8, -- sets the words stored in the ROM
		lpm_outdata => "UNREGISTERED", -- no register on the output
		lpm_address_control => "REGISTERED", -- register on the input
		lpm_file => "mif1.mif", -- the ascii file containing the ROM data
		lpm_width => 9) -- the width of the word stored in each ROM location
		PORT MAP(inclock => clk, address => note_duration, q => duration);--;load the pin to corresponding input, clock & output

	crc_table2 : lpm_rom -- use the altera rom library macrocell
		GENERIC MAP(
		lpm_widthad => 3, -- sets the width of the ROM address bus
		lpm_numwords => 8, -- sets the words stored in the ROM
		lpm_outdata => "UNREGISTERED", -- no register on the output
		lpm_address_control => "REGISTERED", -- register on the input
		lpm_file => "mif2.mif", -- the ascii file containing the ROM data
		lpm_width => 9) -- the width of the word stored in each ROM location
		PORT MAP(inclock => clk, address => note_duration, q => duration_triplet);--;load the pin to corresponding input, clock & output

	with triplet select
		ACTUAL_duration <=
			duration when '0',
			duration_triplet when OTHERS;

	ACTUAL_duration_int <= unsigned(ACTUAL_duration);

	process1 : process (clk, reset)
	begin
		if (reset='1') then
			count <= 0;
			TRIGGER <='0';
		elsif (clk='1' and clk'event) then
			if (tempo_enable = '1') then
				count <= count + 1;
				if (count = ACTUAL_duration_int - 1) then
					count <= 0;
					TRIGGER <= '1';
				else
					TRIGGER <= '0';
				end if;
			end if;
		end if;
	end process;
	
	outputCount <= to_unsigned(count, 9);

end implementation;