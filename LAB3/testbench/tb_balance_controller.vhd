library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_balance_controller is
--  Port ( );
end tb_balance_controller;


architecture Behavioral of tb_balance_controller is
  constant CLK_PER		: time	:= 10ns;
  constant RESET_PER	: time	:= 3*CLK_PER;
  constant balance_MUL : positive  := 3;
  constant N_SECTIONS : positive  := 9;
  constant I_SWITCH   : positive  := 3;

  constant  tb_TDATA_WIDTH    : positive  := 24;
  constant  tb_balance_WIDTH   : positive  := 10;
  constant  tb_balance_STEP_2  : positive  := 6;       -- i.e., balance_values_per_step = 2**balance_STEP_2
  constant  tb_HIGHER_BOUND   : integer   := 2**(tb_TDATA_WIDTH-1)-1; -- Inclusive
  constant  tb_LOWER_BOUND    : integer   := -2**(tb_TDATA_WIDTH-1);  -- Inclusive

  component balance_controller is
    Generic (
              TDATA_WIDTH   : positive  := tb_TDATA_WIDTH;
              balance_WIDTH  : positive  := tb_balance_WIDTH ;
              balance_STEP_2 : positive  := tb_balance_STEP_2  -- i.e., balance_values_per_step = 2**balance_STEP_2
            );
    Port    (
              aclk          : in  std_logic;
              aresetn       : in  std_logic;

              s_axis_tvalid : in  std_logic;
              s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
              s_axis_tlast  : in  std_logic;
              s_axis_tready : out std_logic;

              m_axis_tvalid : out std_logic;
              m_axis_tdata  : out std_logic_vector(TDATA_WIDTH-1 downto 0);
              m_axis_tlast  : out std_logic;
              m_axis_tready : in  std_logic;

              balance        : in  std_logic_vector(balance_WIDTH-1 downto 0)
            );
  end component;

  signal tb_aclk    : std_logic := '0';
  signal tb_aresetn	:	std_logic := '0'; 
  signal tb_balance  : std_logic_vector(tb_balance_WIDTH-1 downto 0);

  signal tb_s_axis_tvalid, tb_s_axis_tlast, tb_s_axis_tready,	tb_m_axis_tvalid,	tb_m_axis_tlast, tb_m_axis_tready : std_logic	:= '0';	
	signal tb_s_axis_tdata, tb_m_axis_tdata : std_logic_vector(tb_TDATA_WIDTH-1 downto 0)	:= (Others => '0');

	-- type data_input is array (0 to 15) of integer range 0 to (2**24)-1;
 --  constant matrice_left		: data_input	:= (66780,	5780,	10930,	13560,	79680,	51810,	8710,	22920,	48160,	32690,	4220,	60160,	23420,	57380,	93000,	39440);
 --  constant matrice_right	: data_input	:= (72930,	75040,	88540,	49150,	83230,	90950,	22540,	8280,	82510,	18550,	19900,	62770,	7980,	6730,	44000,	44480);
  
	-- type balance_input_type is array (0 to 15) of integer range 0 to (2**tb_balance_WIDTH)-1;
 --  constant matrice        : balance_input_type := ()
  -- signal input     : unsigned(tb_TDATA_WIDTH-1 downto 0)  := (Others => '0');
begin

  dut_balance_controller : balance_controller
  Port Map(
						aclk					=> tb_aclk					,
						aresetn				=> tb_aresetn				,
						balance	      => tb_balance       	,
						s_axis_tvalid	=> tb_s_axis_tvalid	,
						s_axis_tlast	=> tb_s_axis_tlast	,
						s_axis_tdata	=> tb_s_axis_tdata	,
						s_axis_tready	=> tb_s_axis_tready	,
						m_axis_tvalid	=> tb_m_axis_tvalid	,
						m_axis_tlast	=> tb_m_axis_tlast	,
						m_axis_tdata	=> tb_m_axis_tdata	,
						m_axis_tready	=> tb_m_axis_tready	
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
    tb_balance   <= (9 => '1', balance_MUL downto 0 => '1', Others => '0'); -- 512 to start at mid point, e.g. joystick initial position
    wait for RESET_PER;
    wait for CLK_PER;


    for i in 0 to N_SECTIONS*(2**(tb_balance_WIDTH-balance_MUL) - 1) loop
      tb_s_axis_tvalid	<= '1';
      tb_m_axis_tready	<= '1';
      tb_s_axis_tlast   <=  std_logic(to_unsigned(i mod 2, 1)(0)); -- Alternating LEFT RIGHT

      tb_balance         <= std_logic_vector(unsigned(tb_balance) + 2**balance_MUL);

      case i / (2**(tb_balance_WIDTH-balance_MUL) - 1) is
        when 0 =>
          tb_s_axis_tdata   <= std_logic_vector(to_signed(128, tb_s_axis_tdata'LENGTH));              -- Normal test

        when 1 =>
          tb_s_axis_tdata   <= std_logic_vector(to_signed(2**18, tb_s_axis_tdata'LENGTH));            -- HIGHER_BOUND test

        when 2 =>
          tb_s_axis_tdata   <= std_logic_vector(to_signed(-2**18, tb_s_axis_tdata'LENGTH));           -- LOWER_BOUND test

        when 3 =>
          tb_s_axis_tdata   <= std_logic_vector(to_signed(0, tb_s_axis_tdata'LENGTH));                -- Zero test

        when 4 =>
          tb_s_axis_tdata   <= std_logic_vector(to_signed(-1, tb_s_axis_tdata'LENGTH));               -- -1 test

        when 5 =>
          tb_s_axis_tdata   <= std_logic_vector(to_signed(tb_HIGHER_BOUND, tb_s_axis_tdata'LENGTH));  -- HIGH_BOUND as data test

        when 6 =>
          tb_s_axis_tdata   <= std_logic_vector(to_signed(tb_LOWER_BOUND, tb_s_axis_tdata'LENGTH));   -- LOWER_BOUND as data test

        when 7 =>
          tb_s_axis_tdata   <= std_logic_vector(to_signed(2**12, tb_s_axis_tdata'LENGTH));            -- Normal test

        when 8 =>
          tb_s_axis_tdata   <= std_logic_vector(to_signed(-2**12, tb_s_axis_tdata'LENGTH));           -- Normal test

        when Others =>
      end case;

      wait for CLK_PER;
    end loop;

    assert false report "JACK: Fine Test Bench" severity FAILURE;
    wait;
  end process func_test;

end Behavioral;
