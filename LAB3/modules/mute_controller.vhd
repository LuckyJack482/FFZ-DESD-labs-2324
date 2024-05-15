library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mute_controller is
  Generic (
            TDATA_WIDTH   : positive  := 24
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

            mute          : in  std_logic
          );
end mute_controller;

architecture Behavioral of mute_controller is

  -- Required registsers to commuicate via AXI4-S.
  -- Furthermore, m_axis_tlast and m_axis_tvalid are basically registered
  signal data_reg : signed(s_axis_tdata'RANGE)  := (Others => '0'); -- Register
  signal data_out : signed(s_axis_tdata'RANGE);                     -- No register, only wire
  signal mute_reg : std_logic                     := '0'; -- For more complex modules, also additional filter data (e.g. volume, lfo_period, ...) should be registered
  constant MUTED  : signed(s_axis_tdata'RANGE)  := (Others => '0');



begin

  process(aclk, aresetn)
  begin
    if aresetn = '0' then
      data_reg      <= (Others => '0');
      mute_reg      <= '0';
      m_axis_tvalid <= '0';
      m_axis_tlast  <= '0';

    elsif rising_edge(aclk) then
      if (s_axis_tvalid and m_axis_tready) = '1' then
        data_reg      <= signed(s_axis_tdata);
        m_axis_tlast  <= s_axis_tlast;
        mute_reg      <= mute;
      end if;
      if m_axis_tready = '1' then
        m_axis_tvalid <= s_axis_tvalid;
      end if;
    end if;
  end process;

  with aresetn select s_axis_tready <=  -- Asynchronous propagation of the m_axis_tready backwards into the chain
    m_axis_tready when '1',
    '0'           when Others;

  with mute_reg select data_out <=
    MUTED     when '1',
    data_reg  when Others;

  m_axis_tdata  <= std_logic_vector(data_out);  -- Cast only

end Behavioral;
