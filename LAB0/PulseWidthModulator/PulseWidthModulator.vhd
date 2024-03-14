-- 14/03/2024 12:27
-- PWM LAB0 w/ comments
-- Implementations w/out variables, w/ (probably more than required) checks
-- on data validity and data initialitation
--
-- Authors:
-- - Samuele Ferraro
-- - Giacomo Fortunato
-- - Samuele Zenoni

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


-- Entity from specifications
entity PulseWidthModulator is
  Generic(
    BIT_LENGTH  : INTEGER RANGE 1 TO 16 := 8;             -- Length of std_logic_vector of this entity
    T_ON_INIT   : POSITIVE := 64;                         -- Initial value of the register T_ON_eff
    PERIOD_INIT : POSITIVE := 128;                        -- Initial value of the register PERIOD_eff
    PWM_INIT    : STD_LOGIC:= '0'                         -- Initial value of the PWM ouput
);
Port (
       reset   : IN STD_LOGIC;
       clk     : IN STD_LOGIC;

       Ton     : IN STD_LOGIC_VECTOR(BIT_LENGTH-1 downto 0);  -- # of clk periods w/ PWM = '1'
       Period  : IN STD_LOGIC_VECTOR(BIT_LENGTH-1 downto 0);  -- # of clk period of PWM
       PWM     : OUT STD_LOGIC                                -- PWM output
     );
end PulseWidthModulator;

architecture Behavioral of PulseWidthModulator is
  -- Here the eff suffix stands for "effective". It could have been better to
  -- use a suffix like "reg", since these signals implement registers in which
  -- the Ton and Period values on the beginning of the PWM cycle are sampled.
  signal T_ON_eff : unsigned(BIT_LENGTH-1 DOWNTO 0);
  signal PERIOD_eff : unsigned(BIT_LENGTH-1 DOWNTO 0);

  -- This counter keeps track of the PWM state: 0 -> in reset; 1 -> first clk
  -- period; Ton -> last clk period w/ PWM = '1'; Period -> last clk period of
  -- the total PWM cycle 
  signal counter : unsigned(Period'RANGE) := (Others => '0');

begin

  -- The main process. A better explanatory name could be chosen.
  aritmetica : process (clk, reset)
  begin
    -- Simulation example w/ -Ton = 6; -Period = 12; PWMINIT = 0;
    -- Initial reset = '1'
    --
    -- time    reset  (start)       Ton           Period  (start)
    --           | |  |              |                 |  |
    --           v v  v              v                 v  v  
    -- PWM       0 0  1  1  1  1  1  1  0  0  0  0  0  0  1
    -- counter   0 0  1  2  3  4  5  6  7  8  9  10 11 12 1
    --          |   ||                ||              |^^|
    -- region    RST        HIGH              LOW    SAMPLE  
    -- We may call the region

    -- Asyncronous reset: reset works INDIPENDENTLY of clk domain
    -- Check if RST
    if reset = '1' then
      -- Setting the INIT values imposed by specifications
      T_ON_eff    <= to_unsigned(T_ON_INIT, T_ON_eff'LENGTH);
      PERIOD_eff  <= to_unsigned(PERIOD_INIT, PERIOD_eff'LENGTH);
      PWM         <= PWM_INIT;
      -- Resetting the counter (note that counter = 0 only when resetted)
      counter     <= (Others => '0');

    elsif rising_edge(clk) then


      -- Complete check if HIGH
      if counter < T_ON_eff and counter < PERIOD_eff then
        PWM     <= '1';
        counter <= counter + 1;
      -- elsif: complete check if LOW
      elsif counter < PERIOD_eff then
        PWM     <= '0';
        counter <= counter + 1;
      -- else: surely in SAMPLE
      else
        -- First period: counter = 1
        counter     <= to_unsigned(1, counter'LENGTH);

        -- Check for period or Ton invalidity:
        -- Case Ton or Period is invalid, then use the init
        if is_x(Period) or is_x(Ton) then
          PERIOD_eff  <= to_unsigned(PERIOD_INIT, PERIOD_eff'LENGTH);
          T_ON_eff    <= to_unsigned(T_ON_INIT, T_ON_eff'LENGTH);
          -- Check if the first period evaluated w/ init values is high or low
          -- Further analysis is required: for example if Ton = 0 or if
          -- Period = 0 ???
          if T_ON_INIT < PERIOD_INIT  and T_ON_INIT > 0 then
            PWM <= '1';
          else
            PWM <= '0';
          end if;

        -- Case both Ton and Period are valid, then sample them
        else
          PERIOD_eff  <= unsigned(Period);
          T_ON_eff    <= unsigned(Ton);
          -- Check if the first period of the sampled values is high or low
          -- Further analysis is required: for example if Ton = 0 or if
          -- Period = 0 ???
          if unsigned(Ton) < unsigned(Period) and unsigned(Ton) > 0 then
            PWM <= '1';
          else
            PWM <= '0';
          end if;

        end if; -- end validity check

      end if; -- end region check

    end if; -- end rising clk check

  end process aritmetica;

end Behavioral;
