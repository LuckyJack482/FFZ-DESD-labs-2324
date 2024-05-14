library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity moving_average_filter_en is
  Generic (
    -- Filter order expressed as 2^(FILTER_ORDER_POWER)
    FILTER_ORDER_POWER    : integer := 5;

    TDATA_WIDTH           : positive := 24
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

            enable_filter : in  std_logic
          );
end moving_average_filter_en;

architecture Behavioral of moving_average_filter_en is

  -- Required registsers to commuicate via AXI4-S.
  -- Furthermore m_axis_tvalid is basically registered
  signal data_out           : signed(s_axis_tdata'RANGE);                     -- No register, only wire
  signal enable_filter_reg  : std_logic                   := '0';             -- Register
  signal m_axis_tlast_reg   : std_logic := '0';

  constant PERIOD_MAF       :	positive	:= 2**FILTER_ORDER_POWER;
  type fifo_type is array (PERIOD_MAF-1 downto 0) of signed(s_axis_tdata'RANGE);

  signal left_fifo          : fifo_type	:= (Others => (Others => '0')); -- Registers in a FIFO configuration
  signal right_fifo         : fifo_type	:= (Others => (Others => '0')); -- Registers in a FIFO configuration

  signal left_sum           : signed(TDATA_WIDTH+FILTER_ORDER_POWER-1 downto 0) := (Others => '0');
  signal left_maf           : signed(left_sum'HIGH downto left_sum'HIGH-TDATA_WIDTH+1);
  signal right_sum          : signed(TDATA_WIDTH+FILTER_ORDER_POWER-1 downto 0) := (Others => '0');
  signal right_maf          : signed(right_sum'HIGH downto right_sum'HIGH-TDATA_WIDTH+1);
  -- Nell'eventualità in cui è necessario effettuare medie separate tra campioni
  -- di sinistra e di destra, de commentare i codici richiusi dai trattini

begin

  ----- THIS IS THE FIXED POINT IDEA
  -- We can try not lose information by having the moving_average_filter as a signed TDATA_WIDTH+FILTER_ORDER_POWER bit long

  left_maf  <= left_sum(left_maf'RANGE);
  right_maf <= right_sum(right_maf'RANGE);

  data_out  <=
  right_maf     when (enable_filter_reg and m_axis_tlast_reg) = '1'     else
  left_maf      when (enable_filter_reg and not m_axis_tlast_reg) = '1' else
  right_fifo(0) when (not enable_filter_reg and m_axis_tlast_reg) = '1' else
  left_fifo(0);
  
  m_axis_tlast  <= m_axis_tlast_reg;

  axis : process(aclk, aresetn)
  begin
    if aresetn = '0' then
      right_fifo        <= (Others => (Others => '0'));
      left_fifo		      <= (Others => (Others => '0'));
      enable_filter_reg <= '0';
      m_axis_tvalid     <= '0';
      m_axis_tlast_reg  <= '0';

    elsif rising_edge(aclk) then
      if (s_axis_tvalid and m_axis_tready) = '1' then
        if s_axis_tlast = '1' then
          right_fifo	<= right_fifo(right_fifo'HIGH-1 downto 0) & signed(s_axis_tdata);
          right_sum   <= right_sum + (signed(s_axis_tdata) - right_fifo(right_fifo'HIGH));
        elsif s_axis_tlast = '0' then
          left_fifo	  <= left_fifo(left_fifo'HIGH-1 downto 0) & signed(s_axis_tdata);
          left_sum    <= left_sum + (signed(s_axis_tdata) - left_fifo(left_fifo'HIGH));
        end if;
        m_axis_tlast_reg   <= s_axis_tlast;
        enable_filter_reg <= enable_filter;
      end if;
      if m_axis_tready = '1' then
        m_axis_tvalid <= s_axis_tvalid;
      end if;
    end if;
  end process axis;

  with aresetn select s_axis_tready <=  -- Asynchronous propagation of the m_axis_tready backwards into the chain
  m_axis_tready when '1',
  '0'           when Others;

  m_axis_tdata  <= std_logic_vector(data_out);  -- Cast only

end Behavioral;
