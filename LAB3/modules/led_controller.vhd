library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity led_controller is
  Generic (
            LED_WIDTH     : positive := 8
          );
  Port    (
            mute_enable   : in  std_logic;
            filter_enable : in  std_logic;

            led_r         : out std_logic_vector(LED_WIDTH-1 downto 0);
            led_g         : out std_logic_vector(LED_WIDTH-1 downto 0);
            led_b         : out std_logic_vector(LED_WIDTH-1 downto 0)
          );
end led_controller;

architecture Behavioral of led_controller is

constant LED_ON   : std_logic_vector(LED_WIDTH-1 downto 0)  := (Others => '1');
constant LED_OFF  : std_logic_vector(LED_WIDTH-1 downto 0)  := (Others => '0');

begin

  -- Choosing LED color according to the slide
  led_r <=  LED_ON when mute_enable = '1' else
            LED_OFF;
  led_b <=  LED_ON when mute_enable = '0' and filter_enable = '1' else
            LED_OFF;
  led_g <=  LED_ON when mute_enable = '0' and filter_enable = '0' else
            LED_OFF;

end Behavioral;
