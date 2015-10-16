library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

library lpm;
use lpm.lpm_components.all;

entity Tempo2 is
	port( bpm	:	in std_logic_vector(7 downto 0);
	      clk, reset	:	in std_logic;
	      beat_gate		:	out std_logic;
	      tempo_enable  :	out std_logic
	      );
	end Tempo2;
	
architecture behavior of Tempo2 is
signal b,d : std_logic;
signal a,temp : std_logic_vector(23 downto 0);
signal c : std_logic_vector(4 downto 0);



begin
b <= NOT(or_reduce(a));
d <= NOT(or_reduce(c));

crc_table : lpm_rom -- use the altera rom library macrocell
	GENERIC MAP(
	lpm_widthad => 8, -- sets the width of the ROM address bus
	lpm_numwords => 256, -- sets the words stored in the ROM
	lpm_outdata => "UNREGISTERED", -- no register on the output
	lpm_address_control => "REGISTERED", -- register on the input
	lpm_file => "lab3.mif", -- the ascii file containing the ROM data
	lpm_width => 24) -- the width of the word stored in each ROM location
	PORT MAP(inclock => clk, address => bpm, q => temp);--;load the pin to corresponding input, clock & output

lpm_counter_24bits : lpm_counter
	GENERIC MAP (
		lpm_direction => "DOWN",
		lpm_port_updown => "PORT_UNUSED",
		lpm_type => "LPM_COUNTER",
		lpm_width => 24
	)
	PORT MAP (
		sload => b,
		aclr => reset,
		clock => clk,
		data => temp,
		cnt_en => '1',
		q => a
	);
	
		tempo_enable <= b;						 
lpm_divide_by_24 : lpm_counter
	GENERIC MAP (
		lpm_direction => "DOWN",
		lpm_modulus => 24,
		lpm_port_updown => "PORT_UNUSED",
		lpm_type => "LPM_COUNTER",
		lpm_width => 5
	)
	PORT MAP (
		sload => d AND b,
		aclr => reset,
		clock => clk,
		data => "10111",
		cnt_en => b,
		q => c
	);
	

	beat_gate<=c(4);				
end behavior; 


								 

