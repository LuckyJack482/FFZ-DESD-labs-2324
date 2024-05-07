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
            effect      : in  std_logic;
            jstck_x     : in  std_logic_vector(JSTK_BITS-1 downto 0); -- da fuk?
            jstck_y     : in  std_logic_vector(JSTK_BITS-1 downto 0); -- jstck <-
            volume      : out std_logic_vector(JSTK_BITS-1 downto 0); -- sarà un errore!
            balance     : out std_logic_vector(JSTK_BITS-1 downto 0); -- chiedi!
            jstk_y_lfo  : out std_logic_vector(JSTK_BITS-1 downto 0)
          );
end effect_selector;

architecture Behavioral of effect_selector is

-- signal;

begin

-- <=;

end Behavioral;
