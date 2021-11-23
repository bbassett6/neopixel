
--Brendan Bassett
--ECE 2031 L03

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shiftregister is
	port(
		--clk		: in   std_logic;
		resetn   : in   std_logic;
		data     : in   std_logic_vector(15 downto 0);
		shift_en    : in   std_logic;
		shiftout_en : in	 std_logic;
		storage_out	:out	std_logic_vector(39 downto 0)
	); 

end entity;


architecture shifting of shiftregister is
 
	signal storage : std_logic_vector(39 downto 0);
 
begin
 
	process(shift_en)
	begin
		if rising_edge(shift_en) then
		
			storage <= storage(storage'high- 8 downto storage'low) & data(7 downto 0); 
		end if;
	end process;
  
	process(shiftout_en)
	begin
		if rising_edge(shiftout_en) then
			storage_out <= storage;
		end if;
	end process;
  
 
end architecture shifting;