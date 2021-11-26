-- WS2812 communication interface.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 

entity NeoPixelController is

	port(
		clk_10M  : in   std_logic;
		resetn   : in   std_logic;
		latch    : in   std_logic;								--NeoPixel_en
		data     : in   std_logic_vector(15 downto 0); 	--IO data
		mode		: in 	 std_logic_vector(9 downto 0);	--switches[9..0]
		sda      : out  std_logic;
		ledrs		: out  std_logic_vector(9 downto 0);	--DE10-lite leds
		shift_en    : in   std_logic;							--shift register enable
		shiftout_en : in	 std_logic							--storage register enable
		
	); 

end entity;

architecture internals of NeoPixelController is

	-- Signal to store the pixel's color data
	signal led_buffer			: std_logic_vector(23 downto 0);
	signal working_buffer 	: std_logic_vector(23 downto 0);
	type prime_string is array (0 to 255) of std_logic_vector(23 downto 0);
	signal primestring 		: prime_string;
	
	type STATE_TYPE is (off, white, all16, one16, all24, one24, fade, cascade, switches);
	signal state  	: STATE_TYPE;
	signal repeat 	: std_logic;
	signal analyze : std_logic; 
	signal storage 		: std_logic_vector(31 downto 0);
	signal storage_out	:	 std_logic_vector(31 downto 0);		
	--storage_out is the register you should read from if you need to get data from the shift register
	--the shift register can also be modified to be larger for dynamic effects
	--we can also add another shift register. there are really no limits, it just has to have its own enables and processes
 
begin
 
--shift register for culminating the 3 color values from scomp
--first values are added to shift register with shift_en
 
	process(shift_en, mode)
	begin
		if rising_edge(shift_en) then
		
			storage <= storage(storage'high- 8 downto storage'low) & data(7 downto 0);

-- I am going to try to make two seperate shift registers for 24 bit and 16 bit color	
		--elsif rising_edge(shift_en) and mode(9 downto 8) = "01" then
			
			--storage <= storage(storage'high- 8 downto storage'low) & data(7 downto 0);

		end if;
	end process;
 
--then values are added to storage register with shiftout_en
 
	process(shiftout_en)
	begin
		if rising_edge(shiftout_en) then
			storage_out <= storage;
		end if;
	end process;
  
  
  
  
				
	process (clk_10M, resetn)
		-- protocol timing values (in 100s of ns)
		constant t1h : integer := 8;
		constant t1l : integer := 4;
		constant t0h : integer := 3;
		constant t0l : integer := 9;

		-- which bit in the 24 bits is being sent
		variable bit_count   : integer range 0 to 6143;
		-- which led in the string we are altering
		variable led_count	: integer range 0 to 255;
		-- counter to count through the bit encoding
		variable enc_count   : integer range 0 to 31;
		-- counter for the reset pulse
		variable reset_count : integer range 0 to 1000;
		
		
	begin
		
		if resetn = '0' then
			-- reset all counters
			bit_count := 0;
			led_count := 0;
			enc_count := 0;
			reset_count := 1000;
			-- set sda inactive
			sda <= '0';

		elsif (rising_edge(clk_10M)) and analyze = '1' then

			
			-- This IF block controls the various counters
			if reset_count > 0 then
				-- during reset period, ensure other counters are reset
				bit_count := 0;
				enc_count := 0;
				-- decrement the reset count
				reset_count := reset_count - 1;
				
				
			else -- not in reset period (i.e. currently sending data)
				-- handle reaching end of a bit
				if primestring(bit_count/24)(bit_count mod 24) = '1' then -- current bit is 1
					if enc_count = (t1h+t1l-1) then -- is end of the bit?
						enc_count := 0;
						if bit_count = 6143 then -- is end of the LED's data?
							reset_count := 1000;
						else
							bit_count := bit_count + 1;
						end if;
					else
						-- within a bit, count to achieve correct pulse widths
						enc_count := enc_count + 1;
					end if;
				else -- current bit is 0
					if enc_count = (t0h+t0l-1) then -- is end of the bit?
						enc_count := 0;
						if bit_count = 6143 then -- is end of the LED's data?
								reset_count := 1000;
							-- if not end of data, decrement count
						else
							bit_count := bit_count + 1;
						end if;
					else
						-- within a bit, count to achieve correct pulse widths
						enc_count := enc_count + 1;
					end if;
				end if;
			end if;
			
			-- This IF block controls sda
			if reset_count > 0 then
				-- sda is 0 during reset/latch
				sda <= '0';
			elsif 
				-- sda is 1 if it's the first part of a bit, which depends on if it's 1 or 0
				( ((primestring(bit_count/24)(bit_count mod 24) = '1') and (enc_count < t1h))
				or
				((primestring(bit_count/24)(bit_count mod 24) = '0') and (enc_count < t0h)) )
				then sda <= '1';
			else
				sda <= '0';
			end if;
			
		end if;
	end process;
	
	
	
--	state machine to determine the demo mode to be in --
	
	process (clk_10M, resetn, latch, storage_out)

	begin
		
		if resetn = '0' then		--all states stay until you reset. to change state: lower switches, key 0, raise desired switch
			state <= off;
			
		elsif rising_edge(clk_10M) then
			case state IS
				when off =>
					if mode =    "0000000001" then  	--switch 0 is one pixel at 24 bit color
						state <= one24;
						
					elsif mode = "0000000010" then	--switch 1 is all pixels at 24 bit color
						state <= all24;
						
					elsif mode = "0000000100" then	--switch 2 is one pixel at 16 bit color
						state <= one16;
						
					elsif mode = "0000001000" then	--switch 3 is all pixels at 16 bit color
						state <= all16;
						
					elsif mode = "0000010000" then	--switch 4 is all full brightness white
						state <= white;
						
					elsif mode = "0000100000" then	--switch 5 is not functional but will be a rainbow fade effect
						state <= fade;
						
					elsif mode = "0001000000" then	--switch 6 is not functional but will be a single led "looping" around
						state <= cascade;
						
					elsif mode(9) = '1' then			--switch 9 allows you to control the color of the strip with 3-3-3 bit depth using sw(8 downto 0)
						state <= switches;
						
					end if;
				when white =>
					state <= white;
				when all16 =>
					state <= all16;
				when one16 =>
					state <= one16;
				when all24 =>
					state <= all24;
				when one24 =>
					state <= one24;
				when fade =>
					state <= fade;
				when cascade =>
					state <= cascade;
				when switches =>
					state <= switches;
				
			end case;
		end if;
	end process;

	
-- here we define led_buffer and whether or not we are going to define the whole string,
--	and we set the leds on the board to reflect the state we are in
	
	process (state, storage_out, mode)
	
	begin

		case state is
			when off =>
				led_buffer <= (others => '0');
				repeat <= '1';
				ledrs <= "0000000000";	
				
			when white =>
				led_buffer <= (others => '1');
				repeat <= '1';
				ledrs <= "0000010000";
				
				
		-- these need tuning
			when all16 =>
				led_buffer <= (storage_out(23 downto 18) &"00" & storage_out(17 downto 13) & "000" & storage_out(12 downto 8) & "000");
				repeat <= '1';
				ledrs <= "0000001000";
				
			when one16 =>
				led_buffer <= (storage_out(23 downto 18) &"00" & storage_out(17 downto 13) & "000" & storage_out(12 downto 8) & "000");
				repeat <= '0';
				ledrs <= "0000000100";
		-- ^^^^^^^
		
			when all24 => 
				led_buffer <= storage_out(23 downto 0);
				repeat <= '1';
				ledrs <= "0000000010";
				
			when one24 =>
				led_buffer <= storage_out(23 downto 0);
				repeat <= '0';
				ledrs <= "0000000001";
				
			when fade =>
				led_buffer <= (others => '1');
				repeat <= '1';
				ledrs <= "0000100000";
				
			when cascade =>
				led_buffer <= (others => '1');
				repeat <= '1';
				ledrs <= "0001000000";
				
			when switches =>
				led_buffer <= (mode(2 downto 0) &"00000" & mode(5 downto 3) & "00000" & mode(8 downto 6) & "00000");
				repeat <= '1';
				ledrs <= "1000000000";
				
		end case;
	end process;
	
	
	process(led_buffer, latch)
		
		variable selection 	: 	integer range 0 to 255;

	begin
	
		selection := to_integer(unsigned(storage_out(31 downto 24)));
		
		if rising_edge(latch) then		
		
			-- if repeat is 0 it means we only want to change an individual led at a certain index
			if repeat = '0' then		
				primestring(selection) <= led_buffer;
				analyze <= '1';
				
			-- if repeat is 1, we want to write to the whole string
			elsif repeat = '1' then
				for led in 0 to 255 loop
					primestring(led) <= led_buffer;
				end loop;
				analyze <= '1';
				
			end if;
			
		end if;

	end process;
	
end internals;
		