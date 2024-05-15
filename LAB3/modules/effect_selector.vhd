--This  module updates the data to give to the controllers in a sinchronous way 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;

entity effect_selector is
  Generic (
            JSTK_BITS   : integer := 10
          );
  Port    (
            aclk        : in  std_logic;
            aresetn     : in  std_logic;
            effect      : in  std_logic; -- If effect = '1' then LFO is applied, else LFO is not applied. It is the switch on the board.
            jstck_x     : in  std_logic_vector(JSTK_BITS-1 downto 0); -- da fuk?
            jstck_y     : in  std_logic_vector(JSTK_BITS-1 downto 0); -- jstck <-
            volume      : out std_logic_vector(JSTK_BITS-1 downto 0); -- sarà un errore!
            balance     : out std_logic_vector(JSTK_BITS-1 downto 0); -- chiedi! Si ma cosa?
            jstk_y_lfo  : out std_logic_vector(JSTK_BITS-1 downto 0) -- this output is the period used by the LFO
          );
end effect_selector;

architecture Behavioral of effect_selector is

begin

process (aclk, aresetn)
begin
  if aresetn = '0' then
    
    --Resetting everything
    volume      <= (Others => '0');
    balance     <= (Others => '0');
    jstk_y_lfo  <= (Others => '0');
  
  elsif rising_edge(aclk) then 
    
    -- the module changes LFO period if effect = '1', thus if the button on the board is pushed
    if effect = '1' then
      jstk_y_lfo <= jstck_y;
    else 
      volume  <= jstck_y;
      balance <= jstck_x;
    end if;
    -- NOTA PER FERRO IN PARTICOLARE: per il loro bitstream, è chiaro che se effect = '1', NON AGGIORNA BALANCE!
    -- cioè
    -- if effect = '1' then ... else volume <= jstck_y; balance <= jstck_x; end if;

  end if;
end process;

end Behavioral;
