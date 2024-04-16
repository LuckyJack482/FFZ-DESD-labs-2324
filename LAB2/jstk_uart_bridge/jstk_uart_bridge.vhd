library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity jstk_uart_bridge is
	generic (
		HEADER_CODE		: std_logic_vector(7 downto 0) := x"c0"; -- Header of the packet
		TX_DELAY		: positive := 1_000_000;    -- Pause (in clock cycles) between two packets
		JSTK_BITS		: integer range 1 to 7 := 7    -- Number of bits of the joystick axis to transfer to the PC 
	);
	Port ( 
		aclk 			: in	std_logic;
		aresetn			: in	std_logic;

		-- Data going TO the PC (i.e., joystick position and buttons state)
		m_axis_tvalid		: out	std_logic;
		m_axis_tdata		: out	std_logic_vector(7 downto 0);
		m_axis_tready		: in	std_logic;

		-- Data coming FROM the PC (i.e., led color)
		s_axis_tvalid		: in	std_logic;
		s_axis_tdata		: in	std_logic_vector(7 downto 0);
		s_axis_tready		: out	std_logic;

		jstk_x			: in	std_logic_vector(9 downto 0);
		jstk_y			: in	std_logic_vector(9 downto 0);
		btn_jstk		: in	std_logic;
		btn_trigger		: in	std_logic;

		led_r			: out	std_logic_vector(7 downto 0);
		led_g			: out	std_logic_vector(7 downto 0);
		led_b			: out	std_logic_vector(7 downto 0)
	);
end jstk_uart_bridge;

architecture Behavioral of jstk_uart_bridge is

	signal delay_counter : integer range 0 to TX_DELAY := 0;
	type s_state_type is (RESET, WAIT_HEADER, WAIT_RED, WAIT_GREEN, WAIT_BLUE);
	signal s_state	: s_state_type		:= RESET;
	signal led_r_reg, led_g_reg	: std_logic_vector(led_r'RANGE)	:= (Others => '0');

	type m_state_type is (RESET, WAITING, WRITE_HEADER, WRITE_X, WRITE_Y, WRITE_BTNS);
	signal m_state	: m_state_type	:= RESET;
	constant zeros			: std_logic_vector(m_axis_tdata'HIGH - JSTK_BITS downto 0) := (Others => '0');

begin
	s_FSM : process (s_state, s_axis_tvalid, s_axis_tdata, aclk, aresetn) 
	begin 
		if aresetn = '0' then 
			s_state <= RESET; 
			led_r	<= (Others => '0');
			led_g	<= (Others => '0');
			led_b	<= (Others => '0');
			s_axis_tready	<= '0';
		elsif rising_edge(aclk) then 
			case (s_state) is 
				when RESET => 
					s_axis_tready	<= '1';
					led_r_reg	<= (Others => '0');
					led_g_reg	<= (Others => '0');
					s_state <= WAIT_HEADER; 

				when WAIT_HEADER => 
					s_axis_tready	<= '1';
					if s_axis_tvalid = '1' and s_axis_tdata = HEADER_CODE then
						s_state	<= WAIT_RED;
					end if;

				when WAIT_RED => 
					s_axis_tready	<= '1';
					if s_axis_tvalid = '1' then
						led_r_reg	<= s_axis_tdata;
						s_state	<= WAIT_GREEN;
					end if;

				when WAIT_GREEN => 
					s_axis_tready	<= '1';
					if s_axis_tvalid = '1' then
						led_g_reg	<= s_axis_tdata;
						s_state	<= WAIT_BLUE;
					end if;

				when WAIT_BLUE => 
					s_axis_tready	<= '1';
					if s_axis_tvalid = '1' then
						led_r	<= led_r_reg;
						led_g	<= led_g_reg;
						led_b	<= s_axis_tdata;
						s_state	<= WAIT_HEADER;
					end if;

				when Others => 
					s_state <= RESET; -- output sincroni ad aclk
			end case; 
		end if; 
	end process s_FSM;

	m_FSM : process (m_state, m_axis_tready, aclk, aresetn) 
	begin 
		if aresetn = '0' then 
			m_state 	<= RESET; 
			m_axis_tvalid	<= '0';
			m_axis_tdata	<= (Others => '0');
		elsif rising_edge(aclk) then 
			case (m_state) is 
				when RESET => 
					delay_counter	<= 0;
					m_axis_tvalid	<= '1';
					m_axis_tdata	<= HEADER_CODE;
					m_state <= WRITE_HEADER; 

				when WRITE_HEADER => 
					m_axis_tvalid	<= '1';
					if m_axis_tready = '1' then
						m_axis_tdata	<= zeros & jstk_x(jstk_x'HIGH downto jstk_x'HIGH-JSTK_BITS+1);
						m_state	<= WRITE_X;
					end if;

				when WRITE_X => 
					m_axis_tvalid	<= '1';
					if m_axis_tready = '1' then
						m_axis_tdata	<= zeros & jstk_y(jstk_y'HIGH downto jstk_y'HIGH-JSTK_BITS+1);
						m_state	<= WRITE_Y;
					end if;

				when WRITE_Y => 
					m_axis_tvalid	<= '1';
					if m_axis_tready = '1' then
						m_axis_tdata	<= (0 => btn_jstk, 1 => btn_trigger, Others => '0');
						m_state	<= WRITE_BTNS;
					end if;

				when WRITE_BTNS => 
					m_axis_tvalid	<= '1';
					if m_axis_tready = '1' then
						m_axis_tvalid	<= '0';
						m_state	<= WAITING;
					end if;

				when WAITING => 
					m_axis_tvalid	<= '0';
					delay_counter	<= delay_counter + 1;
					if delay_counter = TX_DELAY - 1 then
						delay_counter 	<= 0;
						m_state		<= WRITE_HEADER;
						m_axis_tvalid	<= '1';
						m_axis_tdata	<= HEADER_CODE;
					end if;

				when Others => 
					m_state <= RESET; -- output sincroni ad aclk
			end case; 
		end if; 
	end process m_FSM;

end architecture;
