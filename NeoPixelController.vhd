-- WS2812 communication interface.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 

entity NeoPixelController is

	port(
		clk_10M  : in   std_logic;
		resetn   : in   std_logic;
		latch    : in   std_logic;
		data     : in   std_logic_vector(31 downto 0);
		mode		: in 	 std_logic_vector(9 downto 0);
--		activate	: in	 std_logic;
		sda      : out  std_logic;
		ledrs		: out  std_logic_vector(9 downto 0)
		
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
	
	
		
begin
				
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
--			analyze 	 <= '0';
			reset_count := 1000;
			-- set sda inactive
			sda <= '0';
--		for index in 0 to 255 loop
--			working_buffer <= primestring(index);
--		end loop;

		elsif (rising_edge(clk_10M)) and analyze = '1' then

--			working_buffer <= primestring(led_count);
			
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
	
	process (clk_10M, resetn, latch, data)

	begin
		
		if resetn = '0' then
			state <= off;
			
		elsif rising_edge(clk_10M) then
			case state IS
				when off =>
					if mode =    "0000000001" then
						state <= one24;
						
					elsif mode = "0000000010" then
						state <= all24;
						
					elsif mode = "0000000100" then
						state <= one16;
						
					elsif mode = "0000001000" then
						state <= all16;
						
					elsif mode = "0000010000" then
						state <= white;
						
					elsif mode = "0000100000" then
						state <= fade;
						
					elsif mode = "0001000000" then
						state <= cascade;
						
					elsif mode = "1XXXXXXXXX" then
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

	process (state, data)
	
	
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
				
			when all16 =>
				led_buffer <= (data(23 downto 18) &"00" & data(17 downto 13) & "000" & data(12 downto 8) & "000");
				repeat <= '1';
				ledrs <= "0000001000";
				
			when one16 =>
				led_buffer <= (data(23 downto 18) &"00" & data(17 downto 13) & "000" & data(12 downto 8) & "000");
				repeat <= '0';
				ledrs <= "0000000100";
				
			when all24 => 
				led_buffer <= data(23 downto 0);
				repeat <= '1';
				ledrs <= "0000000010";
				
			when one24 =>
				led_buffer <= data(23 downto 0);
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
				led_buffer <= (data(23 downto 21) &"00000" & data(20 downto 18) & "00000" & data(17 downto 5) & "00000");
				repeat <= '1';
				ledrs <= "1000000000";
				
		end case;
	end process;
	
	
	process(led_buffer, latch)
		
		variable selection 	: 	integer range 0 to 255;

	begin
	
		selection := to_integer(unsigned(data(31 downto 24)));
		
		if rising_edge(latch) then		
			if repeat = '0' then
				primestring(selection) <= led_buffer;
				analyze <= '1';
				
			elsif repeat = '1' then
				for led in 0 to 255 loop
					primestring(led) <= led_buffer;
				end loop;
				analyze <= '1';
				
			end if;
			
		end if;

	end process;
	
end internals;
		
		
		-- make an if else-if chain for all the different modes based on the meta index. ie. if meta = "0000010" then do this mode
		-- meta is  -- data(39 downto 32) -- 
		