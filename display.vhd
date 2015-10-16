--
-- entity name: sine
--
-- Copyright (C) 2015 your name goes here
-- Version 1.0
-- Author: designer name(s); designer email address
-- Date: February 11, 2015
library ieee; -- allows use of the std_logic_vector and signed, unsigned types
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lpm; -- allows use of the Altera library modules
use lpm.lpm_components.all;

entity display is
PORT (
	input: in std_logic_vector(7 downto 0);
	reset: in std_logic;
	ripple: in std_logic;
	clock: in std_logic;
	beat: out std_logic;
	tempo: out std_logic;
	output: out std_logic_vector( 20 downto 0)
);

end entity;

architecture behaviour of display is
signal segs: std_logic_vector(20 downto 0);
signal binary: std_logic_vector(11 downto 0);
signal rippleOut: std_logic_vector(3 downto 0);



component 7_segment_decoder
port (	code : in std_logic_vector(3 downto 0);
	RippleBlank_In : in std_logic;
	RippleBlank_Out : out std_logic;
	segments : out std_logic_vector(0 to 6));
end component;

component Tempo2
	port( bpm	:	in std_logic_vector(7 downto 0);
	      clk, reset	:	in std_logic;
	      beat_gate		:	out std_logic;
	      tempo_enable  :	out std_logic
	      );
	end component;
begin
crc_table : lpm_rom -- use the altera rom library macrocell
	GENERIC MAP(
	lpm_widthad => 8, -- sets the width of the ROM address bus
	lpm_numwords => 256, -- sets the words stored in the ROM
	lpm_outdata => "UNREGISTERED", -- no register on the output
	lpm_address_control => "REGISTERED", -- register on the input
	lpm_file => "plus45.mif", -- the ascii file containing the ROM data
	lpm_width => 12) -- the width of the word stored in each ROM location
	PORT MAP(inclock => clock,address => input, q => binary);--;load the pin to corresponding input, clock & output


inst1: 7_segment_decoder port map(code=>binary(3 downto 0),RippleBlank_In=>ripple,RippleBlank_Out=>rippleOut(0),segments=>segs(6 downto 0));
inst2: 7_segment_decoder port map(code=>binary(7 downto 4),RippleBlank_In=>ripple,RippleBlank_Out=>rippleOut(1),segments=>segs(13 downto 7));
inst3: 7_segment_decoder port map(code=>binary(11 downto 8),RippleBlank_In=>ripple,RippleBlank_Out=>rippleOut(2),segments=>segs(20 downto 14));
inst4: Tempo2 port map(bpm=>input,clk=>clock,reset=>reset,beat_gate=>beat,tempo_enable=>tempo);
output <=segs; 
end behaviour;