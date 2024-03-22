library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- use IEEE.math.real."ceil";
-- use IEEE.math.real."log2";


entity KittCar_SR is
	Generic (
	
		CLK_PERIOD_NS			:	positive	range	1	to	100     := 10; 	
		MIN_KITT_CAR_STEP_MS	:	positive	range	1	to	2000    := 1;	
		NUM_OF_SWS		:	integer	range	1 to 16 := 16;	-- Number of input switches
		NUM_OF_LEDS		:	integer	range	1 to 16 := 16	-- Number of output LEDs
	
	);
	Port (
	
		reset	:	in	std_logic;
		clk		:	in	std_logic;

		sw		:	in	std_logic_vector(NUM_OF_SWS-1 downto 0);
		leds	:	out	std_logic_vector(NUM_OF_LEDS-1 downto 0)	
	
	);
end KittCar_SR;

architecture Behavioral of KittCar_SR is
	--Import of the shift register with an "enable" implementend: if en = '1' then it shift, if en = '0' it freeze
	component ShiftRegister is
	    Generic(
        SR_DEPTH : positive := NUM_OF_LEDS;
        SR_INIT : std_logic := '0'
    );
    Port (
		reset 	: in 	std_logic;
        clk 	: in 	std_logic;
		en		: in	std_logic;

        din 	: in 	std_logic;
        dout 	: out 	std_logic_vector(SR_DEPTH-1 downto 0)--we need a parallel output
    );
	end component;
	
	signal sw_reg	: unsigned(NUM_OF_SWS-1 downto 0);
	
	signal en   	: std_logic := '0';
	signal in_sr	: std_logic := '0';
	
	signal out_sr		: std_logic_vector(NUM_OF_LEDS-2 downto 0);
	signal out_invert	: std_logic_vector(NUM_OF_LEDS-2 downto 0);
	--sel_out = '1' the led moves from left to right, if sel_out = '0' the led moves from right to left
	signal sel_out	: std_logic := '0';
	--start is a selector used to insert the first '1' in che shift register
	signal start	: std_logic := '1';
	--counters used to count k*DELTA_T
	signal counter 	 	: unsigned(31 downto 0) := (Others => '0'); --- FA SCHIFO IL RANGE A MANO JACK BESTIA
	signal counter_sw	: unsigned(31 downto 0) := (Others => '0'); --- FA SCHIFO IL RANGE A MANO JACK BESTIA
	--Total minimum steps which are going to be count
	constant DELTA_T : unsigned (31 downto 0) := to_unsigned((MIN_KITT_CAR_STEP_MS*1000000/CLK_PERIOD_NS), 32);

begin
    single_led : if NUM_OF_LEDS = 1 generate
        leds <= (0 => '1', Others => '1');
    end generate single_led;
    
    more_leds : if NUM_OF_LEDS > 1 generate
        SR_inst : ShiftRegister Generic Map(
            SR_DEPTH	=> NUM_OF_LEDS-1,
            SR_INIT		=> '0'
        )
        Port Map(
            reset 	=> reset,
            clk 	=> clk,
            en		=> en,
            din 	=> in_sr,
            dout 	=> out_sr
        );
        
        --process used to manage the logic behind enable 
        process(clk, reset)
        begin
            if reset = '1' then
                counter 	<= (Others => '0');
                counter_sw 	<= (Others => '0');
                sw_reg 		<= unsigned(sw);
                
                en 			<= '1';
                start		<= '1';
                sel_out 	<= '0';
                
            elsif rising_edge(clk) then
                
                if en = '1' then
                    en <= '0';
                    if out_sr(out_sr'HIGH) = '1' then
                        sel_out <= not sel_out;
                    end if;
                    if start = '1' then
                        start 	<= '0';
                    end if;			
                end if;
                
                counter <= counter + 1;			
                if counter = DELTA_T then
                    counter 	<= (Others => '0');
                    counter_sw 	<= counter_sw + 1;
                    sw_reg 		<= unsigned(sw);
                
                    if counter_sw >= sw_reg then
                        counter_sw <= (Others => '0');
                        en <= '1';
                        
                    end if;					
                    
                end if;
                
            end if;
        end process;
        
        with start select in_sr <=	'1' when '1',
                                    out_sr(out_sr'HIGH) when Others;
    
        invert_gen : for I in out_sr'LOW to out_sr'HIGH generate
            out_invert(I) <= out_sr(out_sr'HIGH - I);
        end generate;
        
        leds  <=	(0 => '1', Others => '0') when start = '1' else 
                    (out_sr & '0') when sel_out = '0' else
                    ('0' & out_invert) when sel_out = '1' else
                    (Others => '0');
                    
    end generate more_leds;                
end Behavioral;
