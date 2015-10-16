library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lpm;
use lpm.lpm_components.all;

entity board_test is
	port( 
	      clk, reset	:	in std_logic;
		  note_duration : in std_logic_vector(2 downto 0);
		  triplet : in std_logic;
		  TRIGGER : out std_logic;
		 outputCnt : out unsigned(8 downto 0)
	      );
	end board_test;
	
	architecture behavior of board_test is 
	
	signal tempo,beat : std_logic;
	signal bpm	:	std_logic_vector(7 downto 0);
	
	
	component g13_Tempo2 
	      port ( bpm	:	in std_logic_vector(7 downto 0);
	      clk, reset	:	in std_logic;
	      beat_gate		:	out std_logic;
	      tempo_enable  :	out std_logic
	      );
	      end component;
	component g13_note_timer  
port ( 	clk : in std_logic;
		reset : in std_logic;
		note_duration : in std_logic_vector(2 downto 0);
		triplet : in std_logic;
		tempo_enable : in std_logic;
		TRIGGER : out std_logic;
		outputCount : out unsigned(8 downto 0) );
		end component;
		
		begin 
		bpm<="01001011";
		tempo_genartor: g13_Tempo2 PORT MAP ( bpm => bpm,clk => clk, reset =>reset, beat_gate=>beat, tempo_enable => tempo);
note_timer: g13_note_timer PORT MAP ( clk => clk, reset =>reset, note_duration => note_duration,triplet=>triplet,tempo_enable=>tempo,TRIGGER=>TRIGGER,outputCount=>outputCnt );

		
end behavior;

