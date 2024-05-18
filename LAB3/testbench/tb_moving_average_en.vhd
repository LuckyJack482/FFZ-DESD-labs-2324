library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_moving_average_filter_en is
--  Port ( );
end tb_moving_average_filter_en;


architecture Behavioral of tb_moving_average_filter_en is
  constant CLK_PER		: time	:= 10ns;
  constant RESET_PER	: time	:= 3*CLK_PER;
  constant balance_MUL : positive  := 3;
  constant N_SECTIONS : positive  := 9;
  constant I_SWITCH   : positive  := 3;

  constant  tb_TDATA_WIDTH    : positive  := 24;
  constant  tb_NUM_LEDS       : integer  := 16;
  component led_level_controller is
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
  end component;

  signal tb_aclk    : std_logic := '0';
  signal tb_aresetn	:	std_logic := '0'; 
  signal tb_led     : std_logic_vector(tb_NUM_LEDS-1 downto 0);

  signal tb_s_axis_tvalid, tb_s_axis_tlast, tb_s_axis_tready,	tb_m_axis_tvalid,	tb_m_axis_tlast, tb_m_axis_tready : std_logic	:= '0';	
	signal tb_s_axis_tdata, tb_m_axis_tdata : std_logic_vector(tb_TDATA_WIDTH-1 downto 0)	:= (Others => '0');

	-- type data_input is array (0 to 15) of integer range 0 to (2**24)-1;
 --  constant matrice_left		: data_input	:= (66780,	5780,	10930,	13560,	79680,	51810,	8710,	22920,	48160,	32690,	4220,	60160,	23420,	57380,	93000,	39440);
 --  constant matrice_right	: data_input	:= (72930,	75040,	88540,	49150,	83230,	90950,	22540,	8280,	82510,	18550,	19900,	62770,	7980,	6730,	44000,	44480);
    type axis_data_type is array (0 to 11) of integer range -(2**(tb_TDATA_WIDTH-1)) to (2**(tb_TDATA_WIDTH-1))-1;
    constant matrix_in  : axis_data_type := (46, 6,	78,	-465,	6,	971,	143,	34,	2132,	-46456,	5109,	1456141);
    constant matrix_out : axis_data_type := (0,	46,	26,	43,	-84,	-94,	147,	163,	288,	820,	-11037,	-9796);
begin

  dut_led_level_controller : led_level_controller
  Port Map(
						aclk					=> tb_aclk					,
						aresetn				=> tb_aresetn				,
            led           => tb_led           ,
						s_axis_tvalid	=> tb_s_axis_tvalid	,
						s_axis_tlast	=> tb_s_axis_tlast	,
						s_axis_tdata	=> tb_s_axis_tdata	,
						s_axis_tready	=> tb_s_axis_tready	
		  );

  tb_aclk  <= not tb_aclk	after CLK_PER/2;

  reset	: process
  begin
    tb_aresetn  <= '0';
    wait for RESET_PER;
    tb_aresetn  <= '1';
    wait;
  end process reset;

  func_test : process
  begin
    tb_enable_filter  <= '1';
    wait for RESET_PER;
    wait for CLK_PER;

    for i in matrix_out'RANGE loop
      tb_s_axis_tvalid	<= '1';
      tb_m_axis_tready	<= '1';
      tb_s_axis_tlast   <=  std_logic(to_unsigned(i mod 2, 1)(0)); -- Alternating LEFT RIGHT
      tb_s_axis_tdata   <= std_logic_vector(to_signed(matrix_in(i), tb_s_axis_tdata'LENGTH));
      if i >= 4 and i < 11 then
        assert to_integer(signed(tb_m_axis_tdata)) = matrix_out(i+1)  report "ERRORE!";
      end if;

      wait for CLK_PER;
    end loop;

    assert false report "JACK: Fine Test Bench" severity FAILURE;
    wait;
  end process func_test;

end Behavioral;
