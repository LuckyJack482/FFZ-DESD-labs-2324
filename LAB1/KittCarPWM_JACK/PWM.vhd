library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PulseWidthModulator is
	Generic(
    BIT_LENGTH  : integer range 1 to 16 := 8;
    T_ON_INIT   : positive              := 64;
    PERIOD_INIT : positive              := 128;
    PWM_INIT    : std_logic             := '0'
  );
  Port(
    reset   : in std_logic;
    clk     : in std_logic;
    Ton     : in std_logic_vector(BIT_LENGTH-1 downto 0);
    Period  : in std_logic_vector(BIT_LENGTH-1 downto 0);
    PWM     : out std_logic                              
  );
end PulseWidthModulator;

architecture Behavioral of PulseWidthModulator is
  signal counter    : unsigned(Period'RANGE)  := (Others => '0');

  signal Ton_reg    : unsigned(Ton'RANGE)     := (Others => '0');
  signal Period_reg : unsigned(Period'RANGE)  := (Others => '0');
  --
  signal prescaler : integer := 0;
  constant PRESCALER_VALUE : integer := 10**3;
  --
begin

  timing : process(clk, reset)
  begin
    if reset = '1' then
      Ton_reg     <= to_unsigned(T_ON_INIT, Ton_reg'LENGTH);
      Period_reg  <= to_unsigned(PERIOD_INIT, Period_reg'LENGTH);
      counter     <= (Others => '0');
      prescaler		<= 0;
    elsif rising_edge(clk) then
    		prescaler <= prescaler + 1;
    		if prescaler = PRESCALER_VALUE then
    			prescaler <= 0;
					counter <= counter + 1;
					if counter >= Period_reg then
						counter     <= (Others => '0');
						Ton_reg     <= unsigned(Ton);
						Period_reg  <= unsigned(Period);
					end if;
				end if;
			end if;
  end process timing;

  PWM <= not PWM_INIT when counter >= Ton_reg else
         PWM_INIT;

end Behavioral;
