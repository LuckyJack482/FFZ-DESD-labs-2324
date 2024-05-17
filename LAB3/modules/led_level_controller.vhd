library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real."log2";
use IEEE.math_real."ceil";

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

-- Clock cycles that have to be waited for refresh the leds
constant N_CLK_CYCLES : positive := (refresh_time_ms * 10**6) / clock_period_ns ; 

-- Counter used for the refresh time
signal counter_cycles : integer range 0 to N_CLK_CYCLES := 0;

-- number of bits necessary to represent NUM_LEDS in binary
-- constant BITS_OF_LED : integer := integer(ceil(log2(real(NUM_LEDS)))); 

--Signals used to read the data coming from the master
signal data_left  : unsigned(CHANNEL_LENGTH - 1 downto 0) := (others => '0');
signal data_right : unsigned(CHANNEL_LENGTH - 1 downto 0) := (others => '0');

-- signal used to store the average between left and right
signal average    : unsigned(CHANNEL_LENGTH - 1 downto 0) := (Others => '0');

signal sum : unsigned(CHANNEL_LEGTH downto 0 ) := (Others => '0');
 -- signal used to adapt a CHANNEL_LENGTH bit std_logic_vector data in a NUM_LEDS one, in order to match the data size with the led that can be used on the board. 
signal data_reallocated      : unsigned(led'RANGE);

--signal used to synchronize the value of led every refresh_time_ms as specified in the Generic
signal pre_led    : std_logic_vector(led'RANGE);

begin

--This establish which leds have to be turned on: 
--The leds are turned on according to the position of the MSB, thus if the MSB of data_reallocated is in the highest position,
--then all the leds are turned on.: this idea is implemented by a chain of OR (check the RTL schematic) 
led_on : for i in data_reallocated'range generate
  high_led : if i = data_reallocated'HIGH generate
    pre_led(i) <= data_reallocated(i);
  end generate high_led;
  others_led : if i /= data_reallocated'HIGH generate
    pre_led(i) <= data_reallocated(i) or pre_led(i+1);
  end generate others_led;  
end generate led_on;

--The relationship between s_axis_tready and aresetn should be:
-- with aresetn select s_axis_tready <= '1' when '1',
--                                      '0' when Others; 
--Thus:
s_axis_tready <= aresetn; 

--Slave communication: from AXIS_broadcaster to led_level_controller
--It gets s_axis_tdata and assigns it to data_left or data_right depending on the value of tlast:
-- If tlast= '1' then s_axis_tdata is a left data.
axis: process (aclk, aresetn)
begin 
  if aresetn = '0' then
    --reset    
    data_left  <= (others => '0');
    data_right <= (others => '0');
  
  elsif rising_edge(aclk) then
    if s_axis_tvalid = '1' then
      if s_axis_tlast = '0' then     
        data_left <= unsigned(abs signed(s_axis_tdata));
      else
        data_right <= unsigned( abs signed(s_axis_tdata));
      end if;
    end if;
   end if;
end process axis;

sum <= data_left + data_right;
-- The average is calculated between the last left packet and the last right one
average <= resize(shift_right(sum, 1), average'LENGTH);

--The reallocation of the data is done by saving the MSBs
data_reallocated <= average(average'HIGH - 1 downto average'HIGH - NUM_LEDS - 1);

--Process used to synchronize the refresh rate of the volume bar depending on the generic refresh_time_ms
delay: process(aclk, aresetn)
begin
  if aresetn = '0' then
    led             <= (Others => '0');
    counter_cycles  <= 0;
  elsif rising_edge(aclk) then
    counter_cycles <= counter_cycles + 1;
    if counter_cycles = N_CLK_CYCLES - 1 then
      counter_cycles  <= 0;  
      led <= pre_led;
    end if;
  end if;
end process delay;

end Behavioral;

