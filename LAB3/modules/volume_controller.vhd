library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL."log2";
use IEEE.MATH_REAL."ceil";

entity volume_controller is
  Generic (
            TDATA_WIDTH   : positive  := 24;
            VOLUME_WIDTH  : positive  := 10;
            VOLUME_STEP_2 : positive  := 6;       -- i.e., volume_values_per_step = 2**VOLUME_STEP_2
            HIGHER_BOUND  : integer   := 2**23-1; -- Inclusive
            LOWER_BOUND   : integer   := -(2**23)   -- Inclusive
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
end volume_controller;

architecture Behavioral of volume_controller is

  -- Required registsers to commuicate via AXI4-S.
  -- Furthermore, m_axis_tlast and m_axis_tvalid are basically registered
  signal data_reg             : signed(s_axis_tdata'RANGE)  := (Others => '0'); -- Register
  signal data_out             : signed(s_axis_tdata'RANGE);                     -- No register, only wire
  signal volume_reg           : unsigned(volume'RANGE)      := (Others => '0');
  -- signal amplification_factor : signed(VOLUME_WIDTH-VOLUME_STEP_2 downto 0); -- Non c'è "- 1" poiché (credo) che può essere anche 8, quindi il bit in più è necessario.
  -- signal amplification_factor : integer range -8 to 8; -- Non c'è "- 1" poiché (credo) che può essere anche 8, quindi il bit in più è necessario.
  constant BITS_OF_AMP_FACTOR : positive := integer(ceil(log2(real(2**VOLUME_WIDTH/2**(VOLUME_STEP_2-1) - 2**VOLUME_WIDTH/2**VOLUME_STEP_2 )))) + 1;
  signal amplification_factor : signed(BITS_OF_AMP_FACTOR-1 downto 0); -- Non c'è "- 1" poiché (credo) che può essere anche 8, quindi il bit in più è necessario.

begin
  -- https://opensource.ieee.org/vasg/Packages/-/raw/69e193881d23c76ceaa9f1efeb2c90ebc4b1b515/ieee/numeric_std.vhdl per il sra e il resize

  amplification_factor <=
  -- to_signed((to_integer(volume_reg) / (2**(VOLUME_STEP_2-1))) - (to_integer(volume_reg) / (2**VOLUME_STEP_2)) - (2**(VOLUME_WIDTH - VOLUME_STEP_2 - 1)), amplification_factor'LENGTH);
  -- (to_integer(volume_reg) / (2**(VOLUME_STEP_2-1))) - (to_integer(volume_reg) / (2**VOLUME_STEP_2)) - (2**(VOLUME_WIDTH - VOLUME_STEP_2 - 1));
  to_signed((to_integer(volume_reg) / (2**(VOLUME_STEP_2-1))) - (to_integer(volume_reg) / (2**VOLUME_STEP_2)) - (2**(VOLUME_WIDTH - VOLUME_STEP_2 - 1)), amplification_factor'LENGTH);

  data_out <=
  to_signed(HIGHER_BOUND, data_out'LENGTH)  when to_integer(shift_left(resize(data_reg, data_reg'LENGTH + 2**(VOLUME_WIDTH-VOLUME_STEP_2)), to_integer(amplification_factor))) >= HIGHER_BOUND else
  to_signed( LOWER_BOUND, data_out'LENGTH)  when to_integer(shift_left(resize(data_reg, data_reg'LENGTH + 2**(VOLUME_WIDTH-VOLUME_STEP_2)), to_integer(amplification_factor))) <= LOWER_BOUND else
  shift_right(data_reg, to_integer(- amplification_factor)) when amplification_factor < 0 else
  shift_left(data_reg, to_integer(amplification_factor)); 

  process(aclk, aresetn)
  begin
    if aresetn = '0' then
      data_reg      <= (Others => '0');
      volume_reg    <= (Others => '0');
      m_axis_tvalid <= '0';
      m_axis_tlast  <= '0';

    elsif rising_edge(aclk) then
      if (s_axis_tvalid and m_axis_tready) = '1' then
        data_reg      <= signed(s_axis_tdata);
        m_axis_tlast  <= s_axis_tlast;
        volume_reg    <= unsigned(volume);
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

