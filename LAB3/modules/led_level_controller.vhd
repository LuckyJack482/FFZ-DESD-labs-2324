library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_level_controller is
  Generic (
            NUM_LEDS        : positive := 16;
            CHANNEL_LENGTH  : positive := 24;
            refresh_time_ms : positive := 1;
            clock_period_ns : positive := 10
          );
  Port    (
            aclk            : in  std_logic;
            aresetn         : in  std_logic;

            led             : out std_logic_vector(NUM_LEDS-1 downto 0);

            s_axis_tvalid   : in  std_logic;
            s_axis_tdata    : in  std_logic_vector(CHANNEL_LENGTH-1 downto 0);
            s_axis_tlast    : in  std_logic;
            s_axis_tready   : out std_logic
          );
end led_level_controller;

architecture Behavioral of led_level_controller is

-- signal;

begin

-- <=;

end Behavioral;
