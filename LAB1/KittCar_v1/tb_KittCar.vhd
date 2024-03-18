library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_KittCar is
--  Port ( );
end tb_KittCar;

architecture Behavioral of top_sim is
  constant NUM_OF_SWS : integer := 8;
  constant NUM_OF_LEDS : integer := 8;
  
  component KittCar is
    Generic (
      -- clk period in nanoseconds (100 MHz)
      CLK_PERIOD_NS			:	POSITIVE	RANGE	1	TO	100;
      -- Minimum step period in milliseconds (i.e., value in milliseconds of DELTA_T)
      MIN_KITT_CAR_STEP_MS	:	POSITIVE	RANGE	1	TO	2000;
      NUM_OF_SWS		:	INTEGER	RANGE	1 TO 16;	-- Number of input switches
      NUM_OF_LEDS		:	INTEGER	RANGE	1 TO 16	-- Number of output 
    );
    Port (
      reset	:	IN	STD_LOGIC;
      clk		:	IN	STD_LOGIC;
      sw		:	IN	STD_LOGIC_VECTOR(NUM_OF_SWS-1 downto 0);
      leds	:	OUT	STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0)
    );
  end component;
  
  signal dut_clk    : std_logic                               := '1';
  constant CLK_PER  : time                                    := 10ns;
  signal dut_reset  : std_logic                               := '0';
  signal dut_sw     : std_logic_vector(NUM_OF_SWS-1 downto 0) := (Others => '0');
  signal dut_leds   : std_logic_vector(NUM_OF_SWS-1 downto 0) := (Others => '0');
begin


  dut_KittCar : KittCar
    Generic Map(
      CLK_PERIOD_NS			    => 100,
      MIN_KITT_CAR_STEP_MS	=> 1, 
      NUM_OF_SWS		        => NUM_OF_SWS,	
      NUM_OF_LEDS		        => NUM_OF_LEDS     
    )
    Port Map(
      clk   => dut_clk,
      reset => dut_reset,
      sw    => dut_sw,
      leds  => dut_leds
    );
  
  dut_clk <= not dut_clk after CLK_PER/2;
  
  sim : process
  begin
    dut_reset <= '1';
    
    wait for CLK_PER/2;
    dut_sw    <= "00000001";
    wait for 2*CLK_PER;
    
    dut_reset <= '0';
    wait for 200*CLK_PER;
    
    wait;
  end process sim;

end Behavioral;
