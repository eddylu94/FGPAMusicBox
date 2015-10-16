library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lpm;
use lpm.lpm_components.all;

entity project is
PORT (
	clk, reset :	IN std_logic;
	FL_CE_N1 :		OUT std_logic;
	FL_OE_N1 : 		OUT std_logic;
	FL_WE_N1 : 		OUT std_logic;
	FL_RST_N1 : 	OUT std_logic;
	FL_ADDR1 : 		OUT std_logic_vector(21 downto 0);
	FL_DQ1 : 		INOUT std_logic_vector(7 downto 0);
	segments_fin: 	OUT std_logic_vector(27 downto 0);
	init : 			IN std_logic;
	AUD_MCLK :      OUT std_logic; -- codec master clock input
	AUD_BCLK :      OUT std_logic; -- digital audio bit clock
	AUD_DACDAT :    OUT std_logic; -- DAC data lines
	AUD_DACLRCK :   OUT std_logic; -- DAC data left/right select
	I2C_SDAT :      OUT std_logic; -- serial interface data line
	I2C_SCLK :      OUT std_logic;  -- serial interface clock
	
	tempo_enable :	OUT std_logic;
	
	bpm	: 			IN std_logic_vector(5 downto 0);
	beat_gate :		OUT std_logic;
	
	TRIGGER :		OUT std_logic;
	
	strt :			IN std_logic;
	stop : 			IN std_logic;
	pause :			IN std_logic;
	lp :			IN std_logic;
	
	octave_down :	IN std_logic;
	song_zero :     IN std_logic
);
end g13_project;

architecture behavior of g13_project is

signal trigger_signal : std_logic;
signal outputCount_signal : unsigned(8 downto 0);
signal tempo_enable_signal : std_logic;
signal beat_signal : std_logic;

signal read_done : std_logic;
signal address : unsigned(7 downto 0);
signal state : integer range 0 to 5;
signal sample_data: std_logic_vector(15 downto 0);
signal sample_data0: std_logic_vector(15 downto 0);
signal sample_data1: std_logic_vector(15 downto 0);

signal note : unsigned(3 downto 0);	
signal octave : unsigned(2 downto 0);
signal octave_shifted : unsigned(2 downto 0);
signal note_duration : std_logic_vector(2 downto 0);
signal triplet : std_logic;
signal end_of_song_marker : std_logic;
signal address1 : integer range 0 to 255;
signal loudness : std_logic_vector(3 downto 0);

signal no_sound : std_logic;

signal rip_in: std_logic;
signal rip_out:  std_logic_vector(3 downto 0);

component g13_audio
PORT (
	clk, reset :	IN std_logic;
	octave :		IN unsigned (2 downto 0);
	note : 			IN unsigned(3 downto 0);
	FL_CE_N1 :		OUT std_logic;
	FL_OE_N1 : 		OUT std_logic;
	FL_WE_N1 : 		OUT std_logic;
	FL_RST_N1 : 	OUT std_logic;
	FL_ADDR1 : 		OUT std_logic_vector(21 downto 0);
	FL_DQ1 : 		INOUT std_logic_vector(7 downto 0);
	init : 			IN std_logic;
	trig : 			IN std_logic;
	AUD_MCLK :      OUT std_logic; -- codec master clock input
	AUD_BCLK :      OUT std_logic; -- digital audio bit clock
	AUD_DACDAT :    OUT std_logic; -- DAC data lines
	AUD_DACLRCK :   OUT std_logic; -- DAC data left/right select
	I2C_SDAT :      OUT std_logic; -- serial interface data line
	I2C_SCLK :      OUT std_logic;  -- serial interface clock
	
	loudness :		IN std_logic_vector(3 downto 0)
);
end component;

component g13_note_timer
PORT (
	clk : 			IN std_logic;
	reset : 		IN std_logic;
	note_duration : IN std_logic_vector(2 downto 0);
	triplet : 		IN std_logic;
	tempo_enable : 	IN std_logic;
	TRIGGER : 		OUT std_logic;
	outputCount :	OUT unsigned(8 downto 0)
);
end component;

component g13_Tempo2
PORT (
	bpm : 			IN std_logic_vector(7 downto 0);
	clk, reset :	IN std_logic;
	beat_gate :		OUT std_logic;
	tempo_enable :	OUT std_logic
);
end component;

component g13_7_segment_decoder
	port (	code : in std_logic_vector(3 downto 0);
	RippleBlank_In : in std_logic;
	RippleBlank_Out : out std_logic;
	segments : out std_logic_vector(6 downto 0));
end component;

begin

audio_instance : g13_audio
PORT MAP (
	clk => clk,
	reset => reset,
	octave => octave_shifted,
	note => note,
	FL_CE_N1 =>	FL_CE_N1,
	FL_OE_N1 => FL_OE_N1,
	FL_WE_N1 => FL_WE_N1,
	FL_RST_N1 => FL_RST_N1,
	FL_ADDR1 => FL_ADDR1,
	FL_DQ1 => FL_DQ1,
	init => init,
	trig => trigger_signal,
	AUD_MCLK => AUD_MCLK,
	AUD_BCLK => AUD_BCLK,
	AUD_DACDAT => AUD_DACDAT,
	AUD_DACLRCK => AUD_DACLRCK,
	I2C_SDAT => I2C_SDAT,
	I2C_SCLK => I2C_SCLK,
	
	loudness => loudness
);

note_timer_instance : g13_note_timer
PORT MAP (
	clk => clk,
	reset => NOT reset,
	note_duration => note_duration,
	triplet => triplet,
	tempo_enable => tempo_enable_signal,
	TRIGGER => trigger_signal,
	outputCount => outputCount_signal
);

tempo_instance : g13_Tempo2
PORT MAP (
	bpm => bpm & "00",
	clk => clk,
	reset => NOT reset NOR (NOT no_sound),
	beat_gate => beat_signal,
	tempo_enable => tempo_enable_signal
);

song_table0 : lpm_rom -- use the altera rom library macrocell
GENERIC MAP (
	lpm_widthad => 8, -- sets the width of the ROM address bus
	lpm_numwords => 256, -- sets the words stored in the ROM
	lpm_outdata => "UNREGISTERED", -- no register on the output
	lpm_address_control => "REGISTERED", -- register on the input
	lpm_file => "g00_demo_song.mif", -- the ascii file containing the ROM data
	lpm_width => 16 -- the width of the word stored in each ROM location
)
PORT MAP (
	inclock => clk,
	address => std_logic_vector(address),
	q => sample_data0 -- load the pin to corresponding input, clock & output
);

song_table1 : lpm_rom -- use the altera rom library macrocell
GENERIC MAP (
	lpm_widthad => 8, -- sets the width of the ROM address bus
	lpm_numwords => 256, -- sets the words stored in the ROM
	lpm_outdata => "UNREGISTERED", -- no register on the output
	lpm_address_control => "REGISTERED", -- register on the input
	lpm_file => "g00_demo_song2.mif", -- the ascii file containing the ROM data
	lpm_width => 16 -- the width of the word stored in each ROM location
)
PORT MAP (
	inclock => clk,
	address => std_logic_vector(address),
	q => sample_data1 -- load the pin to corresponding input, clock & output
);

seg0 : g13_7_segment_decoder -- volume
PORT MAP (
	code => loudness,
	RippleBlank_In => rip_in,
	RippleBlank_Out => rip_out(3),
	segments => segments_fin(6 downto 0)
);

seg1 : g13_7_segment_decoder -- note duration
PORT MAP (
	code => '0' & note_duration,
	RippleBlank_In => rip_in,
	RippleBlank_Out => rip_out(3),
	segments => segments_fin(13 downto 7)
);

seg2 : g13_7_segment_decoder -- octave
PORT MAP (
	code => std_logic_vector('0' & octave),
	RippleBlank_In => rip_in,
	RippleBlank_Out => rip_out(3),
	segments => segments_fin(20 downto 14)
);

seg3 : g13_7_segment_decoder -- note number
PORT MAP (
	code => std_logic_vector(note),
	RippleBlank_In => rip_in,
	RippleBlank_Out => rip_out(3),
	segments => segments_fin(27 downto 21)
);

play_song :	process(reset, clk)
begin
if reset = '0' then -- if reset button is pushed, address is reset and goes to idle state
	address <= "00000000"; -- start off reading the file size
	state <= 0;
	
elsif rising_edge(clk) then
	case state is
	
	when 0 => -- idle state that awaits for start button to be pressed
		no_sound <= '1';
		if (strt = '0') then
			state <= 1;
		end if;		
	
	when 1 => -- after start button is pressed, checks for other possible state choices
		no_sound <= '0';
		if (stop = '0') then 
			state <= 4;
		elsif (pause = '1') then
			state <= 5;
		elsif (stop = '1') then
			state <= 2;
		end if;		
	
	when 2 =>
		if (trigger_signal = '1') then 	
			if (end_of_song_marker = '1') then -- reaches last musical piece byte
				if (lp = '1') then -- resets back to beginning of song for loop
					address <= "00000000";
					state <= 3;
				elsif (lp = '0') then -- does not reset and becomes idle
					state <= 4;
				end if;
			elsif (end_of_song_marker = '0') then	-- if not reach end, then continue through piece
				address <= address + 1;
				state <= 3;
			end if;
		end if;		
		
	when 3 => -- continues back to beginning of address shifting process
		if (trigger_signal = '0') then
			state <= 1;
		end if;
	
	when 4 => -- stop
		address <= "00000000";
		state <= 0;
	
	when 5 => -- pause
		no_sound <= '1';
		if (pause = '0') then
			state <= 1;
		end if;
	
	when others =>
		state <= 0;
	
	end case;	
end if;
end process;

octave_process : process(octave_down)
begin
	if (octave_down = '1' AND octave /= "000") then -- shifts octave down when switch is set to '1'
		octave_shifted <= octave - 1;
	else
		octave_shifted <= octave;
	end if;
end process;

with song_zero select sample_data <= -- selects musical piece based on song_zero switch
	sample_data0 when '0',
	sample_data1 when '1';

note <= unsigned(sample_data(3 downto 0));
octave <= unsigned(sample_data(6 downto 4));

-- allocating bytes from sample_data to other modules
note_duration <= sample_data(9 downto 7);
end_of_song_marker <= sample_data(15);
triplet <= sample_data(10);
loudness <= sample_data(14 downto 11);

tempo_enable <= tempo_enable_signal;
TRIGGER <= trigger_signal;
beat_gate <= beat_signal;

-- not using ripple blank feature from previous labs
rip_in <= '0';

end behavior;