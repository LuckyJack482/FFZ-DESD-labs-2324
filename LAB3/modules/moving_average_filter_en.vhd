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

  -- Required signals to commuicate via AXI4-S
  signal data_reg           : signed(s_axis_tdata'RANGE)  := (Others => '0'); -- Register
  signal data_out           : signed(s_axis_tdata'RANGE);                     -- Wire
  signal data_out_reg       : signed(s_axis_tdata'RANGE)  := (Others => '0'); -- Register
  signal enable_filter_reg  : std_logic                   := '0';             -- Register
  signal m_axis_tlast_out   : std_logic                   := '0';             -- Register
  signal m_axis_tlast_reg   : std_logic                   := '0';             -- Register
  signal m_axis_tvalid_reg  : std_logic                   := '0';             -- Register
  -- Output port m_axis_tvalid is registered

  -- MAF = Moving Average Filter
  constant PERIOD_MAF       :	positive	:= 2**FILTER_ORDER_POWER;             -- Period Moving Average Filter
  type fifo_type is array (PERIOD_MAF-1 downto 0) of signed(s_axis_tdata'RANGE); 
  signal left_fifo          : fifo_type	:= (Others => (Others => '0'));       -- Registers in a FIFO configuration
  signal right_fifo         : fifo_type	:= (Others => (Others => '0'));       -- Registers in a FIFO configuration

  signal left_sum           : signed(TDATA_WIDTH+FILTER_ORDER_POWER-1 downto 0) := (Others => '0'); -- Register
  signal left_maf           : signed(left_sum'HIGH downto left_sum'HIGH-TDATA_WIDTH+1);             -- Wire (to slice left_sum)
  signal right_sum          : signed(TDATA_WIDTH+FILTER_ORDER_POWER-1 downto 0) := (Others => '0'); -- Register
  signal right_maf          : signed(right_sum'HIGH downto right_sum'HIGH-TDATA_WIDTH+1);           -- Wire (to slice right_sum)

begin

  -- Slice of sum's MSBs to execute division by 32
  left_maf      <= left_sum(left_maf'RANGE);
  right_maf     <= right_sum(right_maf'RANGE);

  
  -- Logic to select data_out depending on filter enable (registered) and tlast (registered), to decide if left or right data
  data_out  <=
  right_maf when (enable_filter_reg and m_axis_tlast_out) = '1'     else
  left_maf  when (enable_filter_reg and not m_axis_tlast_out) = '1' else
  data_out_reg;
  
  -- Direct connection of register tlast_out to output port tlast
  m_axis_tlast  <= m_axis_tlast_out;

  -- Process to handle AXI4-S communication
  axis : process(aclk, aresetn)
  begin
    if aresetn = '0' then -- Async reset
      data_reg          <= (Others => '0');
      data_out_reg      <= (Others => '0');
      left_sum          <= (Others => '0');
      right_sum         <= (Others => '0');
      right_fifo        <= (Others => (Others => '0'));
      left_fifo		      <= (Others => (Others => '0'));
      enable_filter_reg <= '0';
      m_axis_tlast_out  <= '0';
      m_axis_tlast_reg  <= '0';
      m_axis_tvalid_reg <= '0';
      m_axis_tvalid     <= '0';

    elsif rising_edge(aclk) then
      if (s_axis_tvalid and m_axis_tready) = '1' then -- Data propagation with valid transaction
        data_reg          <= signed(s_axis_tdata);
        m_axis_tlast_reg  <= s_axis_tlast;
        m_axis_tlast_out  <= m_axis_tlast_reg;
        enable_filter_reg <= enable_filter;
        data_out_reg      <= data_reg;
        if m_axis_tlast_reg = '1' then  -- Elaborate right data if input is right data
          right_fifo	    <= right_fifo(right_fifo'HIGH-1 downto 0) & data_reg;
          right_sum       <= right_sum + (data_reg - right_fifo(right_fifo'HIGH));  -- Update right sum
        elsif m_axis_tlast_reg = '0' then -- Elaborate left data if input is left data
          left_fifo	      <= left_fifo(left_fifo'HIGH-1 downto 0) & data_reg;
          left_sum        <= left_sum + (data_reg - left_fifo(left_fifo'HIGH));     -- Update left sum
        end if;
      end if;
      if m_axis_tready = '1' then -- Propagation of tvalid, regardless of valid transaction
        m_axis_tvalid <= s_axis_tvalid;
      end if;
    end if;
  end process axis;

  with aresetn select s_axis_tready <=  -- Asynchronous propagation of the m_axis_tready backwards into the chain
  m_axis_tready when '1',
  '0'           when Others;

  m_axis_tdata  <= std_logic_vector(data_out);  -- Cast only

end Behavioral;
