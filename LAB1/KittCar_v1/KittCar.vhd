---------- DEFAULT LIBRARY ---------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
------------------------------------

entity KittCar is
	Generic (
		-- clk period in nanoseconds (100 MHz)
		CLK_PERIOD_NS			:	POSITIVE	RANGE	1	TO	100     := 10; 	
		
		-- Minimum step period in milliseconds (i.e., value in milliseconds of DELTA_T)
		MIN_KITT_CAR_STEP_MS	:	POSITIVE	RANGE	1	TO	2000    := 1;	
		
		NUM_OF_SWS		:	INTEGER	RANGE	1 TO 16 := 16;	-- Number of input switches
		NUM_OF_LEDS		:	INTEGER	RANGE	1 TO 16 := 16	-- Number of output LEDs

	);
	Port (

		------- Reset/Clock --------
		reset	:	IN	STD_LOGIC;
		clk		:	IN	STD_LOGIC;
		----------------------------

		-------- LEDs/SWs ----------
		-- Switches avaiable on Basys3
		sw		:	IN	STD_LOGIC_VECTOR(NUM_OF_SWS-1 downto 0);
		-- LEDs avaiable on Basys3
		leds	:	OUT	STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0)	
		----------------------------

	);
end KittCar;

architecture Behavioral of KittCar is
  	
	--Total minimum steps which are going to be count
	constant DELTA_T : unsigned (31 downto 0) := to_unsigned((MIN_KITT_CAR_STEP_MS*1000000/CLK_PERIOD_NS), 32);
	--
	signal sw_reg : unsigned (sw'RANGE) := (Others => '0');
	-- counts the clock cycles in which one led is turned on
	signal counter : unsigned (DELTA_T'RANGE) := (Others => '0');
	-- count the total number of DELTA_T needed
	signal counter_sw : unsigned (sw'RANGE) := (Others => '0');
	
	-- describing the direction of the KittCar: 0 => toward left direction, 1 => toward right direction
	signal direction : std_logic := '0'; 
	-- index of the turned on led
	signal index_led : integer RANGE 0 TO NUM_OF_LEDS-1 := 0; 
begin
	led1: if NUM_OF_LEDS = 1 generate
		leds <= (Others => '1'); 
	end generate led1;
	
	normal: if NUM_OF_LEDS > 1 generate
		blink : process(clk, reset)
		begin	
			if reset = '1' then
				leds <= (0 => '1', Others => '0');
				counter <= (Others => '0');
				counter_sw <= (Others => '0');
				direction <= '1';
				sw_reg <= unsigned(sw);
				index_led <= 0;
				
			elsif rising_edge(clk) then	
				counter <= counter + 1;
					
				if counter > DELTA_T then
					counter_sw <= counter_sw + 1;
					counter <= (Others => '0');
					sw_reg <= unsigned(sw);
					
					if counter_sw >= sw_reg then 
						counter_sw <= (Others => '0');
				    leds <= (Others => '0');
						if direction = '0' then
							if index_led = NUM_OF_LEDS - 1 then 
								direction <= '1';
								index_led <= index_led - 1;
								leds(index_led - 1) <= '1';
						  else
						    index_led <= index_led + 1;
                leds(index_led + 1) <= '1';
							end if;
						
						else -- direction = '1'
							if index_led = 0 then
								direction <= '0';
								index_led <= index_led + 1;
                leds(index_led + 1) <= '1';
							else
                index_led <= index_led - 1;
                leds(index_led - 1) <= '1';
							end if;
							

						end if;
						
					end if;			
				
				end if;
				
			end if;
		end process blink;
	end generate normal;
end Behavioral;
