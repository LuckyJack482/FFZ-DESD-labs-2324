library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL."log2";
use IEEE.MATH_REAL."ceil";

entity LFO is
  Generic (
            CHANNEL_LENGTH            : integer := 24;
            JOYSTICK_LENGTH           : integer := 10;
            CLK_PERIOD_NS             : integer := 10;
            TRIANGULAR_COUNTER_LENGTH : integer := 10 -- Triangular wave period length * lfo_period
          );
  Port    (
            aclk                      : in  std_logic;
            aresetn                   : in  std_logic;

            jstk_y                    : in  std_logic_vector(JOYSTICK_LENGTH-1 downto 0);

            lfo_enable                : in  std_logic;

            s_axis_tvalid             : in  std_logic;
            s_axis_tdata              : in  std_logic_vector(CHANNEL_LENGTH-1 downto 0);
            s_axis_tlast              : in  std_logic;
            s_axis_tready             : out std_logic;

            m_axis_tvalid             : out std_logic;
            m_axis_tdata              : out std_logic_vector(CHANNEL_LENGTH-1 downto 0);
            m_axis_tlast              : out std_logic;
            m_axis_tready             : in  std_logic
          );
end entity LFO;

architecture Behavioral of LFO is

  constant LFO_COUNTER_BASE_PERIOD_US : integer   := 1000;  -- Base period of the LFO counter in us (when the joystick is at the center)
  constant ADJUSTMENT_FACTOR          : integer   := 90;    -- Multiplicative factor to scale the LFO period properly with the joystick y position
  constant LFO_COUNTER_BASE_PERIOD    : integer   := (LFO_COUNTER_BASE_PERIOD_US*1000) / CLK_PERIOD_NS;
  constant MIDDLE_JSTK                : unsigned(JOYSTICK_LENGTH - 1 downto 0)  := (JOYSTICK_LENGTH-1 => '1', Others => '0'); -- Joystick y at rest
  constant BITS_OF_PERIOD             : positive  := integer(ceil(log2(real(LFO_COUNTER_BASE_PERIOD))));  -- Based on the max value reachable
  constant BITS_OF_PROD_JSTK          : positive  := integer(ceil(log2(real( ADJUSTMENT_FACTOR * (2**JOYSTICK_LENGTH - 1) ))));

  signal lfo_period_reg     : unsigned (BITS_OF_PERIOD-1 downto 0)                    := (Others => '0'); -- Register
  signal jstk_y_reg         : unsigned(jstk_y'RANGE)                                  := (Others => '0'); -- Register
  signal triangle           : unsigned(TRIANGULAR_COUNTER_LENGTH-1 downto 0)          := (Others => '0'); -- Register
  signal direction          : std_logic                                               := '1';             -- Register: if '1' the slope is positive, if '0' the slope is negative
  signal time_counter       : unsigned (BITS_OF_PERIOD-1 downto 0)                    := (Others => '0'); -- Register: counter used to create the steps of the triangle wave

  -- Required signals to commuicate via AXI4-S
  signal data_reg1          : signed(s_axis_tdata'RANGE)                              := (Others => '0'); -- Register
  signal data_reg2          : signed(s_axis_tdata'RANGE)                              := (Others => '0'); -- Register
  signal product            : signed((triangle'LENGTH+1+data_reg1'LENGTH-1) downto 0) := (Others => '0'); -- Register
  signal product_jstk       : unsigned(BITS_OF_PROD_JSTK - 1 downto 0)                := (Others => '0'); -- Register
  signal data_out           : signed(s_axis_tdata'RANGE);                                                 -- Wire
  signal lfo_enable_reg1    : std_logic                                               := '0';             -- Pipeline register
  signal lfo_enable_reg2    : std_logic                                               := '0';             -- Pipeline register
  signal m_axis_tlast_reg   : std_logic                                               := '0';             -- Pipeline register
  signal m_axis_tvalid_reg  : std_logic                                               := '0';             -- Pipeline register
  -- Output port m_axis_tvalid is registered
  -- Output port m_axis_tlast is registered

begin
  
  with lfo_enable_reg2 select data_out <=
  resize(shift_right(product, TRIANGULAR_COUNTER_LENGTH), data_out'LENGTH)  when '1',
  data_reg2                                                                 when Others;

  triangle_wave : process(aclk, aresetn)
  begin 
    if aresetn = '0' then -- Async reset
      triangle        <= (Others => '0');
      direction       <= '1';
      time_counter    <= to_unsigned(1, time_counter'LENGTH);
      jstk_y_reg      <= MIDDLE_JSTK;
      lfo_period_reg  <= resize(LFO_COUNTER_BASE_PERIOD - ADJUSTMENT_FACTOR*MIDDLE_JSTK, lfo_period_reg'LENGTH); 
      product_jstk    <= (Others => '0');

    elsif rising_edge(aclk) and lfo_enable_reg2 = '1' then -- Logic to generate the triagle wave
      if time_counter = lfo_period_reg then
        lfo_period_reg  <= resize(LFO_COUNTER_BASE_PERIOD - product_jstk, lfo_period_reg'LENGTH);
        time_counter    <= to_unsigned(1, time_counter'LENGTH);
        jstk_y_reg      <= unsigned(jstk_y);

        if direction = '1' then
          triangle <= triangle + 1;
        else
          triangle <= triangle - 1;
        end if;

        if triangle = 1 then
          direction <= '1';
        elsif triangle = (2**(TRIANGULAR_COUNTER_LENGTH) - 2) then
          direction <= '0';
        end if;

      else
        time_counter  <= time_counter + 1;
        product_jstk  <= resize(ADJUSTMENT_FACTOR*jstk_y_reg, product_jstk'LENGTH);
      end if;

    end if;
  end process triangle_wave;

  axis : process(aclk, aresetn)
  begin
    if aresetn = '0' then -- Async reset
      data_reg1         <= (Others => '0');
      data_reg2         <= (Others => '0');
      lfo_enable_reg1   <= '0';
      lfo_enable_reg2   <= '0';
      m_axis_tvalid     <= '0';
      m_axis_tvalid_reg <= '0';
      m_axis_tlast      <= '0';
      m_axis_tlast_reg  <= '0';
      product           <= (Others => '0');

    elsif rising_edge(aclk) then
      if (s_axis_tvalid and m_axis_tready) = '1' then -- Data propagation with valid transaction
        data_reg1         <= signed(s_axis_tdata);
        data_reg2         <= data_reg1;
        m_axis_tlast_reg  <= s_axis_tlast;
        m_axis_tlast      <= m_axis_tlast_reg;
        lfo_enable_reg1   <= lfo_enable;
        lfo_enable_reg2   <= lfo_enable_reg1;
        product           <= signed('0' & triangle) * data_reg1;
      end if;
      if m_axis_tready = '1' then -- Propagation of tvalid, regardless of valid transaction
        m_axis_tvalid_reg <= s_axis_tvalid;
        m_axis_tvalid     <= m_axis_tvalid_reg;
      end if;
    end if;
  end process axis;

  with aresetn select s_axis_tready <=  -- Asynchronous propagation of the m_axis_tready backwards into the chain
  m_axis_tready when '1',
  '0'           when Others;

  m_axis_tdata  <= std_logic_vector(data_out);  -- Cast only

end Behavioral;
