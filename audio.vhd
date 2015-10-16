library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lpm;
use lpm.lpm_components.all;

entity audio is
	port(
	     clk, reset	:	in std_logic;
	     octave  : in unsigned (2 downto 0);
	     note  : in unsigned(3 downto 0);
		 FL_CE_N1, FL_OE_N1, FL_WE_N1,FL_RST_N1 : out std_logic;
		 FL_ADDR1  : out std_logic_vector(21 downto 0);
		 FL_DQ1 : inout std_logic_vector(7 downto 0);
	     init : in std_logic;
	     trig : in std_logic;
	     
	     loudness : IN std_logic_vector(3 downto 0);
	     
	     AUD_MCLK :             OUT std_logic; -- codec master clock input
		AUD_BCLK :             OUT std_logic; -- digital audio bit clock
		AUD_DACDAT :           OUT std_logic; -- DAC data lines
		AUD_DACLRCK :          OUT std_logic; -- DAC data left/right select
		I2C_SDAT :             OUT std_logic; -- serial interface data line
		I2C_SCLK :             OUT std_logic  -- serial interface clock
	      );
end audio;
	
architecture behavior of audio is 
	
	signal read_strt,read_dn : std_logic;
	signal flash_addr,data_size: unsigned(21 downto 0);
	signal data: std_logic_vector(7 downto 0);
	signal rip_in: std_logic;
	signal rip_out:  std_logic_vector(3 downto 0);
	signal segments: std_logic_vector(27 downto 0);
	signal random: std_logic;
	signal random3: unsigned(2 downto 0);
	signal random4: unsigned(3 downto 0);
	signal random8: std_logic_vector(7 downto 0);
	signal audio_data : std_logic_vector(23 downto 0);
	signal stp: std_logic;
	
	signal sample_before : std_logic_vector(15 downto 0);	
	signal sample_after: std_logic_vector(23 downto 0);
	      
	      component flash_read_control 
	    	PORT
	(	
		clk_50 : IN std_logic; -- clk should be 50MHz 
		rst : IN std_logic;  
		read_done : IN std_logic; -- indication from the flash memory that the read operation is complete
		step : IN std_logic; -- signal from the audio interface indicating that the next sample should be read
		odata : IN std_logic_vector(7 downto 0); -- output of the flash memory
		trigger : IN std_logic; -- trigger = 1 resets the sample address to the beginning
		note : IN unsigned(3 downto 0); -- selects the note to be played (within an octave)
		octave : IN unsigned(2 downto 0); -- the octave the note should be played at (4 octave range)
		flash_address : OUT unsigned(21 downto 0); -- address for the flash memory read operation
		read_start : OUT std_logic; -- request a read operation on the flash memory
		sample_data : OUT std_logic_vector(15 downto 0); -- a single 16 bit sample value, to be sent to the audio codec chip
		data_size_o : OUT unsigned(21 downto 0)
	);
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
	component Altera_UP_Flash_Memory_UP_Core_Standalone
	
PORT 
	(
		i_clock 		: IN 		STD_LOGIC;
		i_reset_n 	: IN 		STD_LOGIC;
		i_address 	: IN 		STD_LOGIC_VECTOR(21 DOWNTO 0);
		i_data 		: IN 		STD_LOGIC_VECTOR(7 DOWNTO 0);
		i_read,
		i_write,
		i_erase 		: IN 		STD_LOGIC;
		o_data 		: OUT 	STD_LOGIC_VECTOR(7 DOWNTO 0);
		o_done 		: OUT 	STD_LOGIC;
		
		-- Signals to be connected to Flash chip via proper I/O ports
		FL_ADDR 		: OUT 	STD_LOGIC_VECTOR(21 DOWNTO 0);
		FL_DQ 		: INOUT 	STD_LOGIC_VECTOR(7 DOWNTO 0);
		FL_CE_N,
		FL_OE_N,
		FL_WE_N,
		FL_RST_N 	: OUT 	STD_LOGIC
	);

		end component;
		
		begin 
		
--		signal sample_before : std_logic_vector(15 downto 0);
--		signal sample_before_int : integer range 0 to 65535;
	
		sample_after <= std_logic_vector(signed(sample_before) * signed(loudness)) & "0000";
		
		audio_data<= (sample_after);
		rip_in<= '0';
		
		inst1: flash_read_control 
		port map(	clk_50 => clk, rst => NOT reset,read_done => read_dn,step => stp,odata => data,trigger => trig,note => note,octave=>octave,
					flash_address => flash_addr, read_start => read_strt, sample_data => sample_before, data_size_o => data_size );
		
		inst7: audio_interface
		 PORT MAP(LDATA=>signed (audio_data),RDATA=>signed (audio_data),clk=>clk,rst=> NOT reset,INIT=>NOT init,W_EN=>'1',pulse=>stp,AUD_MCLK=>AUD_MCLK,
		AUD_BCLK =>AUD_BCLK,
		AUD_DACDAT =>AUD_DACDAT,
		AUD_DACLRCK =>AUD_DACLRCK,
		I2C_SDAT =>I2C_SDAT,
		I2C_SCLK =>I2C_SCLK);
		
		inst2: Altera_UP_Flash_Memory_UP_Core_Standalone 
		
		PORT MAP
		
	(
		-- Signals to local circuit 
		i_clock => clk,	
		i_reset_n => reset,
		i_address =>std_logic_vector(flash_addr),
		i_data => std_logic_vector(random8),
		i_read=> read_strt,
		i_write=> '0',
		i_erase => '0',
		o_data 	=> data,
		o_done => read_dn,
		
		-- Signals to be connected to Flash chip via proper I/O ports
		FL_ADDR => FL_ADDR1,
		FL_DQ 	=> FL_DQ1,
		FL_CE_N => FL_CE_N1,
		FL_OE_N => FL_OE_N1,
		FL_WE_N => FL_WE_N1,
		FL_RST_N => FL_RST_N1
	);
		
end behavior;

