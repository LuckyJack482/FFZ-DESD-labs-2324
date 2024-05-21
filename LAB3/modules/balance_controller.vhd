library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL."log2";
use IEEE.MATH_REAL."ceil";

entity balance_controller is
  Generic (
            TDATA_WIDTH     : positive  := 24;
            BALANCE_WIDTH   : positive  := 10;
            BALANCE_STEP_2  : positive  := 6    -- i.e., balance_values_per_step = 2**VOLUME_STEP_2
          );
  Port    (
            aclk            : in  std_logic;
            aresetn         : in  std_logic;

            s_axis_tvalid   : in  std_logic;
            s_axis_tdata    : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
            s_axis_tready   : out std_logic;
            s_axis_tlast    : in  std_logic;

            m_axis_tvalid   : out std_logic;
            m_axis_tdata    : out std_logic_vector(TDATA_WIDTH-1 downto 0);
            m_axis_tready   : in  std_logic;
            m_axis_tlast    : out std_logic;

            balance         : in  std_logic_vector(BALANCE_WIDTH-1 downto 0)
          );
end balance_controller;

architecture Behavioral of balance_controller is

  -- Required registsers to commuicate via AXI4-S.
  -- Furthermore m_axis_tvalid is basically registered
  signal m_axis_tlast_reg     : std_logic                   := '0';
  signal data_reg             : signed(s_axis_tdata'RANGE)  := (Others => '0'); -- Register
  signal data_out             : signed(s_axis_tdata'RANGE);                     -- No register, only wire
  signal balance_reg          : unsigned(balance'RANGE)     := (Others => '0');

  constant BITS_OF_AMP_FACTOR : positive := integer(ceil(log2(real(2**BALANCE_WIDTH/2**(BALANCE_STEP_2-1) - 2**BALANCE_WIDTH/2**BALANCE_STEP_2 )))) + 1;
  signal amplification_factor : signed(BITS_OF_AMP_FACTOR-1 downto 0); -- Non c'è "- 1" poiché (credo) che può essere anche 8, quindi il bit in più è necessario.
  signal left_factor          : integer range 0 to 8;
  signal right_factor         : integer range 0 to 8;
  signal currect_factor       : integer range 0 to 8;

begin

  m_axis_tlast  <= m_axis_tlast_reg;

  -- https://opensource.ieee.org/vasg/Packages/-/raw/69e193881d23c76ceaa9f1efeb2c90ebc4b1b515/ieee/numeric_std.vhdl per il sra e il resize
  amplification_factor <=
  to_signed((to_integer(balance_reg) / (2**(balance_STEP_2-1))) - (to_integer(balance_reg) / (2**balance_STEP_2)) - (2**(balance_WIDTH - balance_STEP_2 - 1)), amplification_factor'LENGTH);

  left_factor   <= to_integer(amplification_factor)   when amplification_factor >= 0 else 0;

  right_factor  <= to_integer(- amplification_factor) when amplification_factor <  0 else 0;
  
  with m_axis_tlast_reg select currect_factor <=
  left_factor  when '0',
  right_factor when Others;

  data_out  <= shift_right(data_reg, currect_factor);

  process(aclk, aresetn)
  begin
    if aresetn = '0' then
      data_reg          <= (Others => '0');
      balance_reg       <= (Others => '0');
      m_axis_tvalid     <= '0';
      m_axis_tlast_reg  <= '0';

    elsif rising_edge(aclk) then
      if (s_axis_tvalid and m_axis_tready) = '1' then
        data_reg          <= signed(s_axis_tdata);
        m_axis_tlast_reg  <= s_axis_tlast;
        balance_reg       <= unsigned(balance);
      end if;
      if m_axis_tready = '1' then
        m_axis_tvalid <= s_axis_tvalid;
      end if;
    end if;
  end process;

  with aresetn select s_axis_tready <=  -- Asynchronous propagation of the m_axis_tready backwards into the chain
  m_axis_tready when '1',
  '0'           when Others;

  m_axis_tdata  <= std_logic_vector(data_out);  -- Cast only

end Behavioral;

--   signal balance_factor : integer range 0 to 16;
--   signal left_factor          : integer range -8 to 8;
--   signal right_factor         : integer range -8 to 8;
--   signal currect_factor       : integer range -8 to 8;

--   balance_factor <=
--   (to_integer(balance_reg) / (2**(balance_STEP_2-1))) - (to_integer(balance_reg) / (2**balance_STEP_2)); --0 to 16
--   left_factor   <= 8 - balance_factor   when 8 - balance_factor > 0 else 0; -- vedere in rtl su vhdl2008 come implementa la rete di maximum
--   right_factor  <= balance_factor - 8 when balance_factor - 8 >  0 else 0;
