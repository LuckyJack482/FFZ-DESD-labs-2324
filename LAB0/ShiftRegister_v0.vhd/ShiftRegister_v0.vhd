library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;

-- ShifRegister with deep of 4 bits

-- Assignement
entity ShiftRegister_v0 is
    Port (
    ---------- Reset/Clock ---------- 
        reset : IN STD_LOGIC;
        clk : IN STD_LOGIC;
    ---------------------------------
    ------------- Data -------------- 
        din : IN STD_LOGIC;
        dout : OUT STD_LOGIC
    --------------------------------- 
    );
end ShiftRegister_v0;
--


architecture Behavioral of top is

    signal dataBus : std_logic_vector(3 DOWNTO 0);

begin

    shift process (clk, reset)
    begin
        if reset = '1' then
            dataBus <= (Others => '0');
        
        elsif rising_edge(clk) then    
            for I in (dataBus'HIGH - 1 DOWNTO dataBus'LOW) then
                dataBus(i+1) <= dataBus(i);
            end loop;
            dataBus (0) <= din;
        
        end if;
    end process shift;

    dout <= dataBus(dataBus'HIGH);

end Behavioral;



