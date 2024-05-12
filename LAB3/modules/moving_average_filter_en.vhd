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
  signal data_out             : signed(s_axis_tdata'RANGE);                     -- No register, only wire
  signal enable_filter_reg    : std_logic                   := '0';             -- Register
--DOUBLE START------------------------------------------------------------------
  signal m_axis_tlast_reg : std_logic := '0';
--DOUBLE END--------------------------------------------------------------------

  constant PERIOD_MAF :	positive	:= 2**FILTER_ORDER_POWER;
  constant MAX_J      : positive  := 2**(FILTER_ORDER_POWER-1);
  type fifo_type is array (PERIOD_MAF-1 downto 0) of signed(s_axis_tdata'RANGE);

--SINGLE START------------------------------------------------------------------
  -- signal fifo : fifo_type	:= (Others => (Others => '0')); -- Registers in a FIFO configuration
--SINGLE END--------------------------------------------------------------------

--DOUBLE START------------------------------------------------------------------
  signal left_fifo  : fifo_type	:= (Others => (Others => '0')); -- Registers in a FIFO configuration
  signal right_fifo : fifo_type	:= (Others => (Others => '0')); -- Registers in a FIFO configuration
--DOUBLE END--------------------------------------------------------------------

  subtype sum_type is signed(TDATA_WIDTH+FILTER_ORDER_POWER-1 downto 0);
  type sum_array_type is array (0 to FILTER_ORDER_POWER-1, 0 to MAX_J-1) of sum_type;  -- The last signal could be of 24 + 5 bits, so the range of the signed is chosen like this
  signal sum_array		: sum_array_type;     -- No registers, only wires!! No waste of registers or ff
  signal last_sum     : sum_type;           -- No register, only wire
--SINGLE START------------------------------------------------------------------
  -- signal sum_array		: sum_array_type;     -- No registers, only wires!! No waste of registers or ff
  -- signal last_sum     : sum_type;           -- No register, only wire
--SINGLE END--------------------------------------------------------------------

--DOUBLE START------------------------------------------------------------------
  -- Nell'eventualità in cui è necessario effettuare medie separate tra campioni
  -- di sinistra e di destra, de commentare i codici richiusi dai trattini
  signal first_data	  : signed(s_axis_tdata'RANGE);     -- No registers, only wires!! No waste of registers or ff
  signal first_sum    : fifo_type;
--DOUBLE END--------------------------------------------------------------------

begin

--SINGLE START------------------------------------------------------------------
  -- -- Crazy only because it was a bit crazy to implement, but works fine with all generics!
  -- crazy_i : for i in 0 to FILTER_ORDER_POWER-1 generate
  --   crazy_j : for j in 0 to MAX_J-1 generate
  --     crazy_zero : if i = 0 generate
  --       sum_array(i,j)  <= to_signed(0, sum_array(i,j)'LENGTH) + fifo(2*j) + fifo(2*j + 1);
  --     end generate crazy_zero;
  --     crazy_nonzero : if i /= 0 and j < (PERIOD_MAF / 2 / (2**i)) generate
  --       sum_array(i,j)  <= sum_array(i-1, 2*j) + sum_array(i-1, 2*j + 1);
  --     end generate crazy_nonzero;
  --   end generate crazy_j;
  -- end generate crazy_i;
  -- last_sum  <= sum_array(sum_array'HIGH, 0);
  --
  -- with enable_filter_reg select data_out <= -- Selection of the outuput based on the registered enable_filter
  -- last_sum(last_sum'HIGH downto last_sum'HIGH-data_out'LENGTH+1)  when '1', -- Upper slice <=> division by 2**FILTER_ORDER_POWER. There is the rounding error when dividing negative numbers
  -- fifo(0)                                                         when Others;
--SINGLE END--------------------------------------------------------------------

--DOUBLE START------------------------------------------------------------------
  -- Crazy only because it was a bit crazy to implement, but works fine with all generics!
  -- LEFT
  first_gen : for i in first_sum'RANGE generate
    with m_axis_tlast_reg select first_sum(i) <=
    left_fifo(i)  when '0',
    right_fifo(i) when Others;
  end generate first_gen;

  crazy_i : for i in 0 to FILTER_ORDER_POWER-1 generate
    crazy_j : for j in 0 to MAX_J-1 generate
      crazy_zero : if i = 0 generate
        sum_array(i,j)  <= to_signed(0, sum_array(i,j)'LENGTH) + first_sum(2*j) + first_sum(2*j + 1);
      end generate crazy_zero;
      crazy_nonzero : if i /= 0 and j < (PERIOD_MAF / 2 / (2**i)) generate
        sum_array(i,j)  <= sum_array(i-1, 2*j) + sum_array(i-1, 2*j + 1);
      end generate crazy_nonzero;
    end generate crazy_j;
  end generate crazy_i;
  last_sum  <= sum_array(sum_array'HIGH, 0);


  with enable_filter_reg select data_out <= -- Selection of the outuput based on the registered enable_filter
  last_sum(last_sum'HIGH downto last_sum'HIGH-data_out'LENGTH+1)  when '1', -- Upper slice <=> division by 2**FILTER_ORDER_POWER. There is the rounding error when dividing negative numbers
  first_sum(0)                                                    when Others;
  
  m_axis_tlast  <= m_axis_tlast_reg;
--DOUBLE END--------------------------------------------------------------------

  axis : process(aclk, aresetn)
  begin
    if aresetn = '0' then
--SINGLE START------------------------------------------------------------------
      -- fifo		          <= (Others => (Others => '0'));
--SINGLE END--------------------------------------------------------------------
--DOUBLE START------------------------------------------------------------------
      right_fifo        <= (Others => (Others => '0'));
      left_fifo		      <= (Others => (Others => '0'));
--DOUBLE END--------------------------------------------------------------------
      enable_filter_reg <= '0';
      m_axis_tvalid     <= '0';

--SINGLE START------------------------------------------------------------------
      -- m_axis_tlast      <= '0';
--SINGLE END--------------------------------------------------------------------
--DOUBLE START------------------------------------------------------------------
      m_axis_tlast_reg  <= '0';
--DOUBLE END--------------------------------------------------------------------

    elsif rising_edge(aclk) then
      if (s_axis_tvalid and m_axis_tready) = '1' then
--SINGLE START------------------------------------------------------------------
        -- fifo	<= fifo(fifo'HIGH-1 downto 0) & signed(s_axis_tdata);
--SINGLE END--------------------------------------------------------------------
--DOUBLE START------------------------------------------------------------------
        if s_axis_tlast = '1' then
          right_fifo	<= right_fifo(right_fifo'HIGH-1 downto 0) & signed(s_axis_tdata);
        elsif s_axis_tlast = '0' then
          left_fifo	  <= left_fifo(left_fifo'HIGH-1 downto 0) & signed(s_axis_tdata);
        end if;
--DOUBLE END--------------------------------------------------------------------

--SINGLE START------------------------------------------------------------------
        -- m_axis_tlast      <= s_axis_tlast;
--SINGLE END--------------------------------------------------------------------
--DOUBLE START------------------------------------------------------------------
        m_axis_tlast_reg   <= s_axis_tlast;
--DOUBLE END--------------------------------------------------------------------
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
