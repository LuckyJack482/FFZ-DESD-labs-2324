library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity jstk_uart_bridge is
	generic (
		HEADER_CODE		: std_logic_vector(7 downto 0) := x"c0"; -- Header of the packet
		TX_DELAY		: positive := 1_000_000;    -- Pause (in clock cycles) between two packets
		JSTK_BITS		: integer range 1 to 7 := 7    -- Number of bits of the joystick axis to transfer to the PC 
	);
	Port ( 
		aclk 			: in  STD_LOGIC;
		aresetn			: in  STD_LOGIC;

		-- Data going TO the PC (i.e., joystick position and buttons state)
		m_axis_tvalid	: out STD_LOGIC;
		m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
		m_axis_tready	: in STD_LOGIC;

		-- Data coming FROM the PC (i.e., LED color)
		s_axis_tvalid	: in STD_LOGIC;
		s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);
		s_axis_tready	: out STD_LOGIC;

		jstk_x			: in std_logic_vector(9 downto 0);
		jstk_y			: in std_logic_vector(9 downto 0);
		btn_jstk		: in std_logic;
		btn_trigger		: in std_logic;

		led_r			: out std_logic_vector(7 downto 0);
		led_g			: out std_logic_vector(7 downto 0);
		led_b			: out std_logic_vector(7 downto 0)
	);
end jstk_uart_bridge;

architecture Behavioral of jstk_uart_bridge is

signal s_axis_tready_reg : std_logic := '0';
signal s_counter : integer range 0 to 3 := 0;
signal m_counter : integer range 0 to 3 := 0;
signal delay_counter : integer range 0 to TX_DELAY := 0;
signal led_r_reg, led_g_reg : std_logic_vector (led_r'RANGE) := (Others => '0');

signal m_axis_tvalid_reg : std_logic := '0';
begin
	
	s_axis_tready <= s_axis_tready_reg;

	led : process(aclk, aresetn)
  	begin
		if aresetn = '0' then 
			s_axis_tready_reg <= '0';
			
			led_r 		  <= (Others => '0');
			led_r_reg     <= (Others => '0');
			
			led_g 		  <= (Others => '0');
			led_g_reg     <= (Others => '0');

			led_b 		  <= (Others => '0');
			s_counter 	  <= 0;
		elsif rising_edge(aclk) then 
		--setting ready condition
			if s_axis_tready_reg = '0' then
				s_axis_tready_reg <= '1';
		
			--reading condition: checking for header
			elsif s_axis_tready_reg = '1' and s_axis_tvalid = '1' then
				if s_axis_tdata = HEADER_CODE then
					s_counter <= s_counter + 1;
				
				--saving the red value
				elsif s_counter = 1 then
					s_counter <= s_counter + 1;
					led_r_reg <= s_axis_tdata;
				
				--saving the green value
				elsif s_counter = 2 then
					s_counter <= s_counter + 1;
					led_g_reg <= s_axis_tdata; 
				--saving the blue value and pushing the previous colors to the output
				elsif s_counter = 3 then
					s_counter <= 0;
					led_b <= s_axis_tdata;
					led_r <= led_r_reg;
					led_g <= led_g_reg;
				end if;
			end if;
		end if;
	end process led;

	m_axis_tvalid <= m_axis_tvalid_reg;

	jstk_x_y : process(aclk, aresetn)
	begin
		if aresetn = '0' then 
			m_axis_tvalid_reg <= '0';
			m_axis_tdata <= (Others => '0');

			m_counter 	  <= 0;
			delay_counter <= 0;
		elsif rising_edge(aclk) then 
		--setting valid condition: qui contiamo anche il constraint dei 25 us per il joystick facendo un countdown
			if m_axis_tvalid_reg = '0' then
				if delay_counter = 0 then
					m_axis_tvalid_reg <= '1';
				else
					delay_counter <= delay_counter - 1;
				end if;

			--reading condition: checking for header
			elsif m_axis_tvalid_reg = '1' and m_axis_tready = '1' then
				if m_counter = 0 then
					m_counter <= m_counter + 1;
					m_axis_tdata <= HEADER_CODE;
				--saving the x cordinate value
				elsif m_counter = 1 then
					m_counter <= m_counter + 1;
					m_axis_tdata <= jstk_x(jstk_x'HIGH downto jstk_x'HIGH - JSTK_BITS);
				
				--saving the y cordinate value
				elsif m_counter = 2 then
					m_counter <= m_counter + 1;
				 	m_axis_tdata <= jstk_y(jstk_y'HIGH downto jstk_y'HIGH - JSTK_BITS);

				--saving the botton values
				elsif m_counter = 3 then
					m_counter <= 0;

					delay_counter <= TX_DELAY;

					m_axis_tdata <= (7 downto 2 => '0', 1 => btn_trigger, 0 => btn_jstk);

				end if;
			end if;

		end if;
	end process;

end architecture;
