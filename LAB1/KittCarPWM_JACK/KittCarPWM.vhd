library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real."ceil";
use IEEE.math_real."log2";

entity KittCarPWM is
	Generic(
		CLK_PERIOD_NS			:	POSITIVE	RANGE	1	TO	100     := 10;	-- clk period in nanoseconds
		MIN_KITT_CAR_STEP_MS	:	POSITIVE	RANGE	1	TO	2000    := 1;	-- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)
		NUM_OF_SWS				:	INTEGER	RANGE	1 TO 16 := 16;	-- Number of input switches
		NUM_OF_LEDS				:	INTEGER	RANGE	1 TO 16 := 16;	-- Number of output LEDs
		TAIL_LENGTH				:	INTEGER	RANGE	1 TO 16	:= 6	-- Tail length
	);
	Port (
		reset	:	IN	STD_LOGIC;
		clk		:	IN	STD_LOGIC;
		sw		:	IN	STD_LOGIC_VECTOR(NUM_OF_SWS-1 downto 0);	-- Switches avaiable on Basys3
		leds	:	OUT	STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0)	-- LEDs avaiable on Basys3
	);
end KittCarPWM;

architecture Behavioral of KittCarPWM is
  -- Questo v1.5 vuole essere:
  -- - KittCar con counter e counter sw solito
  -- - PWM con # di PWM == TAIL_LENGTH
  -- - usare pochi componenti quindi
  -- - routare le uscite dei PWM sulle uscite giuste
	constant DELTA_T					: positive  := MIN_KITT_CAR_STEP_MS * 1000000 / CLK_PERIOD_NS;
	constant BITS_OF_COUNTER	: positive  := integer(ceil(log2(real(DELTA_T))));
  -- I nostri PWM hanno DC (Duty Cycle) : Ton / (Period + 1): in sintesi, se Ton è 0,
  -- l'uscita è fissa a 0. Quindi per avere TAIL_LENGTH diversi DC bisogna
  -- avere BITS_OF_PWM tale per accomodare TAIL_LENGTH+1.
	constant BITS_OF_PWM			: positive  := integer(ceil(log2(real(TAIL_LENGTH + 1))));
  constant PWM_INIT         : std_logic := '1';
  constant T_ON_INIT        : integer   := 1; -- NEL PWM QUESTO GENERIC E' POSITIVE.... MA PERCHE'? VOLEVO METTERE 0 :(
  -- Con PERIOD_INIT == (2**BITS_OF_PWM) - 2, cioè 1 in meno del max, posso
  -- impostare Ton al max per avere il LED acceso fisso
  constant PERIOD_INIT      : integer   := (2**BITS_OF_PWM) - 2;
  --constant STEP_OF_PWM      : unsigned := to_unsigned( (2**BITS_OF_PWM)/TAIL_LENGTH, BITS_OF_PWM); ---- piccolo controllo se e' necessario floor o qualche altra cazzata
  
  --SF: range <> sta a dire che il range è uncostrained, quindi non definito
	type TonPWM is array (integer range <>) of unsigned(BITS_OF_PWM-1 downto 0);

	signal counter						: unsigned(BITS_OF_COUNTER downto 0)			:= (Others => '0');
	signal counter_sw					: unsigned(sw'RANGE)							:= (Others => '0');
	signal sw_reg    					: unsigned(sw'RANGE)							:= (Others => '0');
--	signal led_reg						: unsigned(leds'RANGE)							:= (0 => '1', Others => '0');
	signal index_led					: integer range leds'RANGE						:= 0;
	signal direction					: std_logic										:= '0';

-- SF: PWMs_input contiene le info con cui vogliamo regolare i vari PWM, ovvero i vari Ton. 
--	   La lunghezza è fissata a TAIL_LENGTH seguendo il proposito del commento precendente (v1.5).
--	   Non mi è chiarissimo il perchè sia (TAIL_LENGTH downto 1) invece di (TAIL_LENGTH - 1 downto 0), ma alla fine è la stessa cosa.  
	signal PWMs_input					: TonPWM(TAIL_LENGTH downto 1)      			:= (Others => (Others => '0'));

-- SF: tail_type serve a creare un array come leds che sia in grado di contenere l'effetto "decadimento" della coda.
--     Secondo me si poteva usare il tipo TonPWM, ma il tail_type non costa nulla e rende il codice molto più leggibile.
	type tail_type is array (leds'RANGE) of unsigned(BITS_OF_PWM-1 downto 0);
  	signal tail               : tail_type 												:= (Others => (Others => '0'));
-- SF: PWMs_output sono tutte le onde quadre che escono dai PWM   	
	signal PWMs_output        : std_logic_vector(TAIL_LENGTH-1 downto 0)				:= (Others => PWM_INIT);
	 

	component PulseWidthModulator is
  Generic(
    BIT_LENGTH  : integer range 1 to 16 := 8;  -- Length of std_logic_vector of this entity
    T_ON_INIT   : positive  := 64;             -- Initial value of the register T_ON_eff
    PERIOD_INIT : positive  := 128;            -- Initial value of the register PERIOD_eff
    PWM_INIT    : std_logic := PWM_INIT        -- Initial value of the PWM ouput
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
			counter_sw		<= (Others => '0');
			index_led		<= 0;
			sw_reg			<= unsigned(sw);
			tail			<= (Others => (Others => '0'));
		elsif rising_edge(clk) then
			counter <= counter + 1;
			if counter = DELTA_T then
				counter <= (Others => '0');
				counter_sw	<= counter_sw + 1;
				if counter_sw >= sw_reg then
					counter_sw 	<= (Others => '0');
					sw_reg			<= unsigned(sw);
					
					if direction= '0' then --scorro verso sinistra
					--SF: Jack che tocco di stile con 'LEFT, stima completa
						if index_led = leds'LEFT then
							direction	<= '1';
							index_led <= index_led - 1;
						else
							index_led <= index_led + 1; --SF: +1 vuol dire andare a sinistra, va preso come riferimento la out port leds
						end if;
					else -- direction = '1', scorro verso destra
						if index_led = leds'RIGHT then
							direction	<= '0';
							index_led <= index_led + 1;
						else
							index_led <= index_led - 1;
						end if;
					end if;

					-- SF: Creazione della coda pensata come [TAIL_LENGTH, TAIL_LENGTH - 1, ...] (un po come me la avevi spiegata quando ci siamo visti)
					--     Credo che questo sia codice comune con la versione 16 PWM. 
					--     Domanda di approfondimento: si poteva fare usando operazioni vettore di VHDL secondo voi? Io non ho trovato una versione equivalente.
					for I in tail'RANGE loop
						if I = index_led then
							tail(I) <= to_unsigned(TAIL_LENGTH, BITS_OF_PWM); --JACK: Non mi piace, vorrei un attribute dell'elemento i-esimo di tail (ho letto tipo 'LENGTH(I) o 'LENGTH(1)
						elsif tail(I) /= 0 then
							tail(I) <= tail(I) - 1; --SF: Questa riga funziona usando il signal commit, assurdo
						end if;
					end loop;

				end if;
			end if;
		end if;
	end process timing;

--  tailer : process(index_led)
--  begin
--		if reset = '1' then
--			tail				<= (Others => (Others => '0'));
--		else
			
--  end process tailer;

--  inputs : process
--  begin
--    for I in PWMs_input'RANGE loop
--      if I = PWMs_input'HIGH then
--        PWMs_input(I) <= to_unsigned( ((2**BITS_OF_PWM) - 1) / I, BITS_OF_PWM );
--      else
--        PWMs_input(I) <= to_unsigned( PWMs_input(I+1) - (PWMs_input(I+1) / I), BITS_OF_PWM );
--    end loop;
--    wait;
--  end process inputs;


-- SF: qui viene creato l'array che contiene le configurazioni per i PWM: [HIGH,..., LOW] dove HIGH contiene il valore massimo della coda
  inputs_gen : for I in PWMs_input'RANGE generate
  	first_gen : if I = PWMs_input'HIGH generate
  		PWMs_input(I) <= to_unsigned( ((2**BITS_OF_PWM) - 1), BITS_OF_PWM );
  	end generate first_gen;
  	others_gen : if I /= PWMs_input'HIGH generate
	-- SF: qui c'è il decadimento dei Ton. Domanda: Questa divisione va bene? La fa vivado o Basys 3?
  		PWMs_input(I) <= to_unsigned(to_integer(PWMs_input(I+1)) - to_integer(PWMs_input(I+1) / (I+1) ), BITS_OF_PWM );
  	end generate others_gen;
  end generate inputs_gen;
  
  
		
  PWMs_gen  : for I in TAIL_LENGTH-1 downto 0 generate
    PWM_inst  : PulseWidthModulator
    Generic Map(
      BIT_LENGTH  => BITS_OF_PWM,
      T_ON_INIT   => T_ON_INIT,
      PERIOD_INIT => PERIOD_INIT,
      PWM_INIT    => PWM_INIT
    )
    Port Map(
      reset   => reset,
      clk     => clk,
	  --SF: qui si ha I+1 per rimanere coerenti il range (TAIL_LENGTH downto 1) di prima (credo)
      Ton     => std_logic_vector(PWMs_input(I+1)),
      Period  => std_logic_vector(to_unsigned(PERIOD_INIT, BITS_OF_PWM)),
      PWM     => PWMs_output(I)
    );
  end generate;

--  routing : process(tail)
--  begin
--    for I in tail'RANGE loop
--      if tail(I) = 0 then
--        leds(I) = '0';
--      else
--        leds(I) <= PWMs_ouput(tail(I));
--      end if;
--    end loop;
--  end process routing;

  routing_gen : for I in tail'RANGE generate
  	with tail(I) select leds(I) <= 	'0' 								 when to_unsigned(0, BITS_OF_PWM),
  									PWMs_output(to_integer(tail(I) - 1)) when Others;
--    leds(I) <= PWMs_output(to_integer(tail(I))) when tail(I) /= 0 else
--               '0';
  end generate;
    
end Behavioral;
