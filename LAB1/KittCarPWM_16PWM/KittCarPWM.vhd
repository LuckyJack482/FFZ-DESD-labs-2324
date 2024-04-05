library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real."ceil";
use IEEE.math_real."log2";

entity KittCarPWM is
	Generic (
		CLK_PERIOD_NS			:	POSITIVE	RANGE	1	TO	100     := 10;	-- clk period in nanoseconds
		MIN_KITT_CAR_STEP_MS	:	POSITIVE	RANGE	1	TO	2000    := 1;	-- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)
		NUM_OF_SWS				:	INTEGER	RANGE	1 TO 16 := 16;	-- Number of input switches
		NUM_OF_LEDS				:	INTEGER	RANGE	1 TO 16 := 16;	-- Number of output LEDs
		TAIL_LENGTH				:	INTEGER	RANGE	1 TO 16	:= 4	-- Tail length
	);
	Port (
		reset	:	IN	STD_LOGIC;
		clk		:	IN	STD_LOGIC;
		sw		:	IN	STD_LOGIC_VECTOR(NUM_OF_SWS-1 downto 0);	-- Switches avaiable on Basys3
		leds	:	OUT	STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0)	-- LEDs avaiable on Basys3
	);
end KittCarPWM;

architecture Behavioral of KittCarPWM is
	constant DELTA_T					: positive := MIN_KITT_CAR_STEP_MS * 1000000 / CLK_PERIOD_NS;
	constant BITS_OF_COUNTER	: positive := integer(ceil(log2(real(DELTA_T))));
	constant BITS_OF_PWM			: positive := integer(ceil(log2(real(TAIL_LENGTH))));
  constant STEP_OF_PWM      : unsigned := to_unsigned( (2**BITS_OF_PWM)/TAIL_LENGTH, BITS_OF_PWM); ---- piccolo controllo se è necessario floor o qualche altra cazzata

	type TonPWM is array (integer range <>) of unsigned(BITS_OF_PWM-1 downto 0); 
	signal counter						: unsigned(BITS_OF_COUNTER downto 0)	:= (Others => '0');
	signal counter_sw					: unsigned(sw'RANGE)									:= (Others => '0');
	signal sw_reg    					: unsigned(sw'RANGE)									:= (Others => '0');
--	signal led_reg						: unsigned(leds'RANGE)								:= (0 => '1', Others => '0');
	signal index_led					: integer range leds'RANGE						:= 0;
	signal direction					: std_logic														:= '0';
	signal PWMs_input					: TonPWM(NUM_OF_LEDS-1 downto 0) := (Others => (Others => '0'));
	
	component PulseWidthModulator is
  Generic(
    BIT_LENGTH  : integer range 1 to 16 := 8; -- Length of std_logic_vector of this entity
    T_ON_INIT   : positive  := 64;             -- Initial value of the register T_ON_eff
    PERIOD_INIT : positive  := 128;            -- Initial value of the register PERIOD_eff
    PWM_INIT    : std_logic := '0'             -- Initial value of the PWM ouput
  );
  Port (
     reset   : in   std_logic;
     clk     : in   std_logic;

     Ton     : in   std_logic_vector(BIT_LENGTH-1 downto 0);  -- # of clk periods w/ PWM = '1'
     Period  : in   std_logic_vector(BIT_LENGTH-1 downto 0);  -- # of clk period of PWM
     PWM     : out  std_logic                                 -- PWM output
   );
	end component;

begin


	timing : process(clk, reset)
	begin
		if reset = '1' then
			counter			<= (Others => '0');
			counter_sw	<= (Others => '0');
			index_led		<= 0;
			sw_reg			<= unsigned(sw);

		elsif rising_edge(clk) then
			counter <= counter + 1;
			if counter = DELTA_T then
				counter <= (Others => '0');
				counter_sw	<= counter_sw + 1;
				if counter_sw >= sw_reg then
					counter_sw 	<= (Others => '0');
					sw_reg			<= unsigned(sw);
					
					if direction= '0' then
						if index_led = leds'LEFT then
							direction	<= '1';
							index_led <= index_led - 1;
						else
							index_led <= index_led + 1;
						end if;
					else -- direction = '1'
						if index_led = leds'RIGHT then
							direction	<= '0';
							index_led <= index_led + 1;
						else
							index_led <= index_led - 1;
						end if;
					end if;

          for I in PWMs_input'REVERSE_RANGE loop
            if I = index_led then
              PWMs_input(I) <= (Others => '1');
            elsif PWMs_input(I) /= 0 then
              PWMs_input(I) <= PWMs_input(I) - STEP_OF_PWM;
            end if;
          end loop;

				end if;
			end if;
		end if;
	end process timing;
		
  PWMs_gen  : for I in leds'RANGE generate
    PWM_inst  : PulseWidthModulator Generic Map(
      BIT_LENGTH  => BITS_OF_PWM,
      T_ON_INIT   => 1,
      PERIOD_INIT => (2**(BITS_OF_PWM-1)),
      PWM_INIT    => '0'
    )
    Port Map(
      reset   => reset,
      clk     => clk,
      Ton     => std_logic_vector(PWMs_input(I)),
      Period  => std_logic_vector(to_unsigned(2**(BITS_OF_PWM-1), BITS_OF_PWM)),
      PWM     => leds(I)
    );
  end generate;

end Behavioral;
