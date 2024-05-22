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
            LOWER_BOUND   : integer   := -(2**23) -- Inclusive
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

  -- Required signals to commuicate via AXI4-S
  signal data_reg             : signed(s_axis_tdata'RANGE)  := (Others => '0'); -- Register
  signal data_out_reg         : signed(s_axis_tdata'RANGE)  := (Others => '0'); -- Register
  signal volume_reg           : unsigned(volume'RANGE)      := (Others => '0'); -- Register
  signal m_axis_tlast_reg     : std_logic                   := '0';             -- Register
  signal m_axis_tvalid_reg    : std_logic                   := '0';             -- Register
  -- Output port m_axis_tvalid is registered
  -- Output port m_axis_tlast is registered

  constant BITS_OF_AMP_FACTOR : positive := integer(ceil(log2(real(2**VOLUME_WIDTH/2**(VOLUME_STEP_2-1) - 2**VOLUME_WIDTH/2**VOLUME_STEP_2 )))) + 1;
  signal amplification_factor : signed(BITS_OF_AMP_FACTOR-1 downto 0);          -- Wire

begin

  -- Conversion from the joystick y to the amplification factor (2^amp_factor)
  amplification_factor <= to_signed((to_integer(volume_reg) / (2**(VOLUME_STEP_2-1))) - (to_integer(volume_reg) / (2**VOLUME_STEP_2)) - (2**(VOLUME_WIDTH - VOLUME_STEP_2 - 1)), amplification_factor'LENGTH);

  -- Logic to select data_out depending on saturation and the sign of amplification_factor (shift left w/ amplification_factor > 0 otherwise shift right w/ amplification_factor < 0)
  data_out_reg <=
  -- HIGHER_BOUND when (data_reg << amp_factor) >= HIGHER_BOUND else
  to_signed(HIGHER_BOUND, data_out_reg'LENGTH)  when shift_left(data_reg, to_integer(amplification_factor)) >= HIGHER_BOUND else
  -- LOWER_BOUND when (data_reg << amp_factor) <= HIGHER_BOUND else
  to_signed( LOWER_BOUND, data_out_reg'LENGTH)  when shift_left(data_reg, to_integer(amplification_factor)) <= LOWER_BOUND else
  -- (data_reg >> -amp_factor) when amp_factor < 0 else
  shift_right(data_reg, to_integer(- amplification_factor)) when amplification_factor < 0 else
  -- (data_reg << amp_factor);
  shift_left(data_reg, to_integer(amplification_factor)); 

  -- Process to handle AXI4-S communication
  axis : process(aclk, aresetn)
  begin
    if aresetn = '0' then -- Async reset
      data_reg          <= (Others => '0');
      volume_reg        <= (Others => '0');
      m_axis_tdata      <= (Others => '0');
      m_axis_tvalid     <= '0';
      m_axis_tlast      <= '0';
      m_axis_tlast_reg  <= '0';
      m_axis_tvalid_reg <= '0';

    elsif rising_edge(aclk) then
      if (s_axis_tvalid and m_axis_tready) = '1' then -- Data propagation with valid transaction
        data_reg          <= signed(s_axis_tdata);
        m_axis_tdata      <= std_logic_vector(data_out_reg);  -- Cast only
        m_axis_tlast_reg  <= s_axis_tlast;
        m_axis_tlast      <= m_axis_tlast_reg;
        volume_reg        <= unsigned(volume);
      end if;
      if m_axis_tready = '1' then -- Propagation of tvalid, regardless of valid transaction
        m_axis_tvalid_reg <= s_axis_tvalid;
        m_axis_tvalid     <= m_axis_tvalid_reg;
      end if;
    end if;
  end process axis;

  with aresetn select s_axis_tready <=  -- Asynchronous propagation of the tready backwards in the pipeline
  m_axis_tready when '1',
  '0'           when Others;


end Behavioral;

