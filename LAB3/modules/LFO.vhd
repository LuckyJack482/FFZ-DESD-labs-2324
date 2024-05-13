library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LFO is
    Generic (
              CHANNEL_LENGTH            : integer := 24;
              JOYSTICK_LENGTH           : integer := 10;
              CLK_PERIOD_NS             : integer := 10;
              TRIANGULAR_COUNTER_LENGTH : integer := 10 -- Triangular wave period length
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
  constant LFO_COUNTER_BASE_PERIOD_US : integer := 1000;  -- Base period of the LFO counter in us (when the joystick is at the center)
  constant ADJUSTMENT_FACTOR          : integer := 90;    -- Multiplicative factor to scale the LFO period properly with the joystick y position

  --lfo_period := LFO_COUNTER_BASE_PERIOD - ADJUSTMENT_FACTOR*joystick_y

-- Required registsers to commuicate via AXI4-S.
  -- Furthermore, m_axis_tlast and m_axis_tvalid are basically registered
  signal data_reg : unsigned(s_axis_tdata'RANGE)  := (Others => '0'); -- Register
  signal data_out : unsigned(s_axis_tdata'RANGE);                     -- No register, only wire
  signal lfo_enable_reg   : std_logic              := '0';

  signal triangle : unsigned(TRIANGULAR_COUNTER_LENGTH - 1 downto 0) := (Others => '0');
  signal direction : std_logic := '1'; --if '1' the slope is positivi, if '0' the slope is negative.

begin

  axis: process(aclk, aresetn)
  begin
    if aresetn = '0' then
      data_reg      <= (Others => '0');
      fe_reg        <= '0';
      m_axis_tvalid <= '0';
      m_axis_tlast  <= '0';

    elsif rising_edge(aclk) then
      if (s_axis_tvalid and m_axis_tready) = '1' then
        data_reg        <= unsigned(s_axis_tdata);
        m_axis_tlast    <= s_axis_tlast;
        lfo_enable_reg  <= lfo_enable;
      end if;
      if m_axis_tready = '1' then
        m_axis_tvalid <= s_axis_tvalid;
      end if;
    end if;
  end process axis;

  with aresetn select s_axis_tready <=  -- Asynchronous propagation of the m_axis_tready backwards into the chain
  m_axis_tready when '1',
  '0'           when Others;

  with lfo_enable_reg select data_out <=
  resize((data_reg + 100), data_out'LENGTH) when '1',     -- HERE the example filter is (x + 100), more complicated elaboration of the filter must be made here in datapath
  data_reg                                  when Others;

  m_axis_tdata  <= std_logic_vector(data_out);  -- Cast only

  with triangle select 

  triangle_wave: process (aclk, aresetn)
  begin 
    if aresetn = '0' then
      triangle <= (Others => '0');
      direction = '1';
    elsif rising_edge(aclk) then
      if direction = '1' then
        triangle <= triangle + 1;
      else
        triangle <= triangle - 1;
      end if;


    end if;

  end process triangle_wave;

end Behavioral;