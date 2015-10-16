library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library lpm;
use lpm.lpm_components.all;

entity final is
	port(
	     clk, reset,select_song,read_mode,start_song,pause,stop,pitch:	in std_logic;
	     bpm : in std_logic_vector(5 downto 0);
	     
		 FL_CE_N1, FL_OE_N1, FL_WE_N1,FL_RST_N1 : out std_logic;
		 FL_ADDR1  : out std_logic_vector(21 downto 0);
		 FL_DQ1 : inout std_logic_vector(7 downto 0);
		 segments_fin: out std_logic_vector(27 downto 0);
	     init : in std_logic;
	     
	     AUD_MCLK :             OUT std_logic; -- codec master clock input
		AUD_BCLK :             OUT std_logic; -- digital audio bit clock
		AUD_DACDAT :           OUT std_logic; -- DAC data lines
		AUD_DACLRCK :          OUT std_logic; -- DAC data left/right select
		I2C_SDAT :             OUT std_logic; -- serial interface data line
		I2C_SCLK :             OUT std_logic  -- serial interface clock
	      );
end final;
	
architecture behavior of final is 
	
	signal read_strt,read_dn : std_logic;
	signal flash_addr,data_size: unsigned(21 downto 0);
	signal trigger: std_logic;
	signal tempo:std_logic;
	signal data: std_logic_vector(7 downto 0);
	signal sample_data: std_logic_vector(15 downto 0);
	signal address: unsigned(7 downto 0);
	signal rip_out:  std_logic_vector(3 downto 0);
	signal segments: std_logic_vector(27 downto 0);
	signal audio_data : std_logic_vector(23 downto 0);
	signal stp: std_logic;
	signal outputcnt: unsigned(8 downto 0);
	signal beat: std_logic;
	signal state : integer range 0 to 10;
	signal note_duration,octave,volume,note_nbr : std_logic_vector(3 downto 0);
	component 7_segment_decoder
		port (	code : in std_logic_vector(3 downto 0);
		RippleBlank_In : in std_logic;
		RippleBlank_Out : out std_logic;
		segments : out std_logic_vector(6 downto 0));
		
	end component; 
	      
	      
	      
	 component audio_interface
     	PORT
	(	
		LDATA, RDATA	:      IN signed(23 downto 0); -- parallel external data inputs
		clk : IN std_logic; -- clk should be 50MHz 
		rst : IN std_logic;  
		INIT : IN std_logic;  
		W_EN : IN std_logic;
		pulse :          	   OUT std_logic; -- sample sync pulse
		AUD_MCLK :             OUT std_logic; -- codec master clock input
		AUD_BCLK :             OUT std_logic; -- digital audio bit clock
		AUD_DACDAT :           OUT std_logic; -- DAC data lines
		AUD_DACLRCK :          OUT std_logic; -- DAC data left/right select
		I2C_SDAT :             OUT std_logic; -- serial interface data line
		I2C_SCLK :             OUT std_logic  -- serial interface clock
	);
	end component;
	component note_timer
	port ( 	clk : in std_logic;
		reset : in std_logic;
		note_duration : in std_logic_vector(2 downto 0);
		triplet : in std_logic;
		tempo_enable : in std_logic;
		TRIGGER : out std_logic;
		outputCount : out unsigned(8 downto 0) );
		end component;
		
		component Tempo2 
	port( bpm	:	in std_logic_vector(7 downto 0);
	      clk, reset	:	in std_logic;
	      beat_gate		:	out std_logic;
	      tempo_enable  :	out std_logic
	      );
	end component;
		
		
		begin
		note_nbr <= sample_data(3 downto 0);
		octave <=  "0" & sample_data(6 downto 4);
		note_duration <= "0"&sample_data(9 downto 7);
		volume<=sample_data(14 downto 11);
		audio_data<= (sample_data & "00000000");
		song_table : lpm_rom -- use the altera rom library macrocell
	GENERIC MAP(
	lpm_widthad => 16, -- sets the width of the ROM address bus
	lpm_numwords => 256, -- sets the words stored in the ROM
	lpm_outdata => "UNREGISTERED", -- no register on the output
	lpm_address_control => "REGISTERED", -- register on the input
	lpm_file => "g00_demo_song.mif", -- the ascii file containing the ROM data
	lpm_width => 16) -- the width of the word stored in each ROM location
	PORT MAP(inclock => clk, address => std_logic_vector(address), q => sample_data);--;load the pin to corresponding input, clock & output
	tempo_gen: Tempo2
	PORT MAP( bpm=>bpm,
	      clk=>clk, reset=>reset,
	      beat_gate	=>beat,
	      tempo_enable  =>tempo
	      );
	timer: note_timer
	port map( 	clk => clk,
		reset =>reset,
		note_duration =>sample_data(9 downto 7),
		triplet => sample_data(10),
		tempo_enable =>tempo,
		TRIGGER => trigger,
		outputCount => outputcnt );
	audio_player: audio_interface
		 PORT MAP(LDATA=>signed (audio_data),RDATA=>signed (audio_data),clk=>clk,rst=> reset,INIT=>NOT init,W_EN=>'1',pulse=>stp,AUD_MCLK=>AUD_MCLK,
		AUD_BCLK =>AUD_BCLK,
		AUD_DACDAT =>AUD_DACDAT,
		AUD_DACLRCK =>AUD_DACLRCK,
		I2C_SDAT =>I2C_SDAT,
		I2C_SCLK =>I2C_SCLK);
		
		
		note_nbr1 : 7_segment_decoder
		port map (code=> note_nbr,RippleBlank_In=>'1',RippleBlank_Out=>rip_out(0),segments=>segments(6 downto 0));
		
		
		octave1 : 7_segment_decoder
		port map (code=> octave,RippleBlank_In=>'1',RippleBlank_Out=>rip_out(1),segments=>segments(13 downto 7));
		
		note_duration1 : 7_segment_decoder
		port map (code=>note_duration,RippleBlank_In=>'1',RippleBlank_Out=>rip_out(2),segments=>segments(20 downto 14));
		
		volume1 : 7_segment_decoder
		port map (code=> volume,RippleBlank_In=>'1',RippleBlank_Out=>rip_out(3),segments=>segments(27 downto 21));
		
		
		play_song :	process(reset, clk)
begin
		if reset = '1' then
			read_strt <= '0';
			address <= "00000000"; -- start off reading the file size
			state <= 0;
			
		elsif rising_edge(clk) then
			case state is
			when 0 =>
				read_strt <= '1';
				state <= 1;
			when 1 =>
				if read_dn = '1' then
					
	
		if(stop='1') then 
				state <=10;
				end if;
					--if(trigger='1') then
					--address <= address + 1;
					--end if;
					read_strt <= '0';
					state <= 2;
				end if;			
			when 2 =>	
				if read_dn = '0' then -- wait for memory to become ready for the next read
					read_strt <= '1';
					if(stop='1') then 
				state <=10;
				end if;
				
				
					state <= 3;
				end if;	
				
				
				when 3 => 
	if trigger='0' then 
	state<= 4;
	
	end if;
				
		when 4 => if trigger ='1' then 	
			if (address = "11111111" AND read_mode = '1') then
				address <= "00000000"; -- start off reading the file size
				state <= 0;
				end if;
				if (address = "11111111" AND read_mode = '0') then
				address <= "00000000"; -- start off reading the file size
				state <= 10;
				end if;
				
				address <= address + 1;
				state <= 1;
				end if;		
	
	when 10 => -- DO NOTHING
				
			when others =>
				state <= 0;
			end case;	
		end if;
	end process;
		
		
		
		
	
	segments_fin <= segments;
		
end behavior;

