library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--Declaration of Entity
ENTITY size_read is
	GENERIC (
		FLASH_MEMORY_ADDRESS_WIDTH 	: INTEGER := 22;
		FLASH_MEMORY_DATA_WIDTH 		: INTEGER := 8
	);
	PORT(	clk,reset : in std_logic;
		
			step : IN std_logic;
			trigger : IN std_logic;
			
			FL_ADDR : out std_logic_vector(21 downto 0);
			FL_DQ :	inout std_logic_vector (7 downto 0);
			FL_CE_N : out std_logic;
			FL_OE_N : out std_logic;
			FL_WE_N : out std_logic;
			FL_RST_N : out std_logic;
			
			SEG0 : out std_logic_vector(0 to 6);
			SEG1 : out std_logic_vector(0 to 6);
			SEG2 : out std_logic_vector(0 to 6);
			SEG3 : out std_logic_vector(0 to 6)
		);

END size_read;

ARCHITECTURE readr of size_read is
	--Signal Declarations
	signal done_reading : std_logic;
	signal data : std_logic_vector(7 downto 0);
	signal address : unsigned(21 downto 0);
	signal data_size : unsigned(21 downto 0);
	signal start_read : std_logic;
	--Component Declarations
	component flash_read_control is 
		PORT ( 		
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
					data_size_o : OUT unsigned(21 downto 0) -- number of samples in the wave file (for display on the LEDs)
			);
	end component;
	
	component Altera_UP_Flash_Memory_UP_Core_Standalone is
		GENERIC (
			FLASH_MEMORY_ADDRESS_WIDTH 	: INTEGER := 22;
			FLASH_MEMORY_DATA_WIDTH 		: INTEGER := 8
			);
		PORT 
		(
			-- Signals to local circuit 
			i_clock 		: IN 		STD_LOGIC;
			i_reset_n 	: IN 		STD_LOGIC;
			i_address 	: IN 		STD_LOGIC_VECTOR(FLASH_MEMORY_ADDRESS_WIDTH - 1 DOWNTO 0);
			i_data 		: IN 		STD_LOGIC_VECTOR(FLASH_MEMORY_DATA_WIDTH - 1 DOWNTO 0);
			i_read,
			i_write,
			i_erase 		: IN 		STD_LOGIC;
			o_data 		: OUT 	STD_LOGIC_VECTOR(FLASH_MEMORY_DATA_WIDTH - 1 DOWNTO 0);
			o_done 		: OUT 	STD_LOGIC;
			
			-- Signals to be connected to Flash chip via proper I/O ports
			FL_ADDR 		: OUT 	STD_LOGIC_VECTOR(FLASH_MEMORY_ADDRESS_WIDTH - 1 DOWNTO 0);
			FL_DQ 		: INOUT 	STD_LOGIC_VECTOR(FLASH_MEMORY_DATA_WIDTH - 1 DOWNTO 0);
			FL_CE_N,
			FL_OE_N,
			FL_WE_N,
			FL_RST_N 	: OUT 	STD_LOGIC
		);
	end component;
	
	component 7_segment_decoder is
	PORT (	
			code : in std_logic_vector(3 downto 0);
			RippleBlank_In : in std_logic;
			RippleBlank_Out : out std_logic;
			segments : out std_logic_vector(6 downto 0));
	end component;
		
	BEGIN
	
		read_control : flash_read_control  
			PORT MAP(
						clk_50	=> clk,
						rst		=> reset,
						read_done	=> done_reading,
						odata	=> data,
						
						step	=> step,
						trigger => trigger,
						note	=> "0000",
						octave	=> "000",
						
						flash_address => address,
						data_size_o	=> data_size,
						read_start => start_read
					);
					
		flash_standalone : Altera_UP_Flash_Memory_UP_Core_Standalone
			GENERIC MAP (
							FLASH_MEMORY_ADDRESS_WIDTH => FLASH_MEMORY_ADDRESS_WIDTH,
							FLASH_MEMORY_DATA_WIDTH	=> FLASH_MEMORY_DATA_WIDTH
						)
			PORT MAP (
						i_clock	=> clk,
						i_reset_n	=> (not reset),
						i_address	=> std_logic_vector(address),
						i_data		=> "00000000",
						i_read 		=> start_read,
						i_write		=> '0',
						i_erase		=> '0',
						
						o_data		=> data,
						o_done		=> done_reading,
						
						FL_ADDR => FL_ADDR,
						FL_DQ => FL_DQ,
						FL_CE_N => FL_CE_N,
						FL_OE_N => FL_OE_N,
						FL_WE_N => FL_WE_N,
						FL_RST_N => FL_RST_N
					);
		
		
		
		digit0 : 7_segment_decoder port map	(code => std_logic_vector(data_size(3 downto 0)), RippleBlank_In => '1', segments => SEG0);
		digit1 : 7_segment_decoder port map	(code => std_logic_vector(data_size(7 downto 4)), RippleBlank_In => '1', segments => SEG1);
		digit2 : 7_segment_decoder port map	(code => std_logic_vector(data_size(11 downto 8)), RippleBlank_In => '1', segments => SEG2);
		digit3 : 7_segment_decoder port map	(code => std_logic_vector(data_size(15 downto 12)), RippleBlank_In => '1', segments => SEG3);

	
END readr;