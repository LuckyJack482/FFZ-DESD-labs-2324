library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_volume_controller is
--  Port ( );
end tb_volume_controller;


architecture Behavioral of tb_volume_controller is
  constant CLK_PER		: time	:= 10ns;
  constant RESET_PER	: time	:= 3*CLK_PER;
  constant VOLUME_MUL : natural  	:= 1;
  constant N_SECTIONS : positive  := 9;
  constant I_SWITCH   : positive  := 3;

  constant  tb_TDATA_WIDTH    : positive  := 24;
  constant  tb_VOLUME_WIDTH   : positive  := 10;
  constant  tb_VOLUME_STEP_2  : positive  := 6;       -- i.e., volume_values_per_step = 2**VOLUME_STEP_2
  constant  tb_HIGHER_BOUND   : integer   := 2**(tb_TDATA_WIDTH-1)-1; -- Inclusive
  constant  tb_LOWER_BOUND    : integer   := -2**(tb_TDATA_WIDTH-1);  -- Inclusive

  component volume_controller is
    Generic (
              TDATA_WIDTH   : positive  := tb_TDATA_WIDTH;
              VOLUME_WIDTH  : positive  := tb_VOLUME_WIDTH ;
              VOLUME_STEP_2 : positive  := tb_VOLUME_STEP_2;  -- i.e., volume_values_per_step = 2**VOLUME_STEP_2
              HIGHER_BOUND  : integer   := tb_HIGHER_BOUND;   -- Inclusive
              LOWER_BOUND   : integer   := tb_LOWER_BOUND     -- Inclusive
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

              volume        : in  std_logic_vector(VOLUME_WIDTH-1 downto 0)
            );
  end component;

  signal tb_aclk    : std_logic := '0';
  signal tb_aresetn	:	std_logic := '0'; 
  signal tb_volume  : std_logic_vector(tb_VOLUME_WIDTH-1 downto 0);

  signal tb_s_axis_tvalid, tb_s_axis_tlast, tb_s_axis_tready,	tb_m_axis_tvalid,	tb_m_axis_tlast, tb_m_axis_tready : std_logic	:= '0';	
	signal tb_s_axis_tdata, tb_m_axis_tdata : std_logic_vector(tb_TDATA_WIDTH-1 downto 0)	:= (Others => '0');

	-- type data_input is array (0 to 15) of integer range 0 to (2**24)-1;
 --  constant matrice_left		: data_input	:= (66780,	5780,	10930,	13560,	79680,	51810,	8710,	22920,	48160,	32690,	4220,	60160,	23420,	57380,	93000,	39440);
 --  constant matrice_right	: data_input	:= (72930,	75040,	88540,	49150,	83230,	90950,	22540,	8280,	82510,	18550,	19900,	62770,	7980,	6730,	44000,	44480);
  
	-- type volume_input_type is array (0 to 15) of integer range 0 to (2**tb_VOLUME_WIDTH)-1;
 --  constant matrice        : volume_input_type := ()
  -- signal input     : unsigned(tb_TDATA_WIDTH-1 downto 0)  := (Others => '0');
begin

  dut_volume_controller : volume_controller
  Port Map(
						aclk					=> tb_aclk					,
						aresetn				=> tb_aresetn				,
						volume	      => tb_volume       	,
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
    tb_volume   <= (9 => '1', VOLUME_MUL downto 0 => '1', Others => '0'); -- 512 to start at mid point, e.g. joystick initial position
    wait for RESET_PER;
    wait for CLK_PER;


    for i in 0 to N_SECTIONS*(2**(tb_VOLUME_WIDTH-VOLUME_MUL) - 1) loop
      tb_s_axis_tvalid	<= '1';
      tb_m_axis_tready	<= '1';
      tb_s_axis_tlast   <=  std_logic(to_unsigned(i mod 2, 1)(0)); -- Alternating LEFT RIGHT

      tb_volume         <= std_logic_vector(unsigned(tb_volume) + 2**VOLUME_MUL);

      case i / (2**(tb_VOLUME_WIDTH-VOLUME_MUL) - 1) is
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
