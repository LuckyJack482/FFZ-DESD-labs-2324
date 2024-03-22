library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


-- Shift Register Serial Input Parallel Output w/ enable
entity ShiftRegister is
    Generic(
        SR_DEPTH : positive := 4;
        SR_INIT : std_logic := '0'
    );
    Port (
		reset 	: in 	std_logic;
        clk 	: in 	std_logic;
		en		: in	std_logic;

        din 	: in 	std_logic;
        dout 	: out 	std_logic_vector(SR_DEPTH-1 downto 0)
    );
end ShiftRegister;

architecture Behavioral of ShiftRegister is
    signal dataBus : std_logic_vector(SR_DEPTH-1 downto 0);
begin

    shift : process(clk,reset)
	begin
		if reset='1' then
			dataBus <= (Others => SR_INIT);
		elsif rising_edge(clk) and en = '1' then
		
			for I in dataBus'HIGH-1  downto dataBus'LOW loop
				dataBus(I+1) <= dataBus(I);
			end loop;
			dataBus(dataBus'LOW) <= din;
		end if;
    end process shift;
	
    dout <= dataBus;
	
end Behavioral;
