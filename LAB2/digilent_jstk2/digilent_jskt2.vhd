library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity digilent_jstk2 is
	Generic (
		DELAY_US		: integer := 25;    -- Delay (in us) between two packets
		CLKFREQ		 	: integer := 100_000_000;  -- Frequency of the aclk signal (in Hz)
		SPI_SCLKFREQ 		: integer := 5_000 -- Frequency of the SPI SCLK clock signal (in Hz)
	);
	Port ( 
		aclk 			: in	std_logic;
		aresetn			: in	std_logic;

		-- Data going TO the SPI IP-Core (and so, to the JSTK2 module)
		m_axis_tvalid		: out	std_logic;
		m_axis_tdata		: out	std_logic_vector(7 downto 0);
		m_axis_tready		: in	std_logic;

		-- Data coming FROM the SPI IP-Core (and so, from the JSTK2 module)
		-- There is no tready signal, so you must be always ready to accept and use the incoming data, or it will be lost!
		s_axis_tvalid		: in	std_logic;
		s_axis_tdata		: in	std_logic_vector(7 downto 0);

		-- Joystick and button values read from the module
		jstk_x			: out	std_logic_vector(9 downto 0);
		jstk_y			: out	std_logic_vector(9 downto 0);
		btn_jstk		: out	std_logic;
		btn_trigger		: out	std_logic;

		-- LED color to send to the module
		led_r			: in	std_logic_vector(7 downto 0);
		led_g			: in	std_logic_vector(7 downto 0);
		led_b			: in	std_logic_vector(7 downto 0)
	);
end digilent_jstk2;

architecture Behavioral of digilent_jstk2 is
	-- Code for the SetLEDRGB command, see the JSTK2 datasheet.
	constant CMDSETLEDRGB		: std_logic_vector(7 downto 0) := x"84";
	-- Do not forget that you MUST wait a bit between two packets. See the JSTK2 datasheet (and the SPI IP-Core README).
	------------------------------------------------------------
	constant DELAY_CYCLES 		: integer := DELAY_US * (CLKFREQ / 1_000_000) + CLKFREQ / SPI_SCLKFREQ;


	signal delay_counter 		: integer range 0 to DELAY_CYCLES 	:= 0;
	signal jstk_x_reg, jstk_y_reg	: std_logic_vector(jstk_x'RANGE) 	:= (Others => '0');
	--signal btns_reg			: std_logic_vector(1 downto 0)		:= (Others => '0');

	type s_state_type is (RESET, READING_X_L, READING_X_H, READING_Y_L, READING_Y_H, READING_FSB);
	signal s_state	: s_state_type	:= RESET;
	type m_state_type is (RESET, WAITING, WRITE_CMD, WRITE_R, WRITE_G, WRITE_B, WRITE_DUMMY);
	signal m_state	: m_state_type	:= RESET;

	--constant zeros			: std_logic_vector(m_axis_tdata'HIGH - JSTK_BITS downto 0) := (Others => '0');

begin
	s_FSM : process (s_state, s_axis_tvalid, s_axis_tdata, aclk, aresetn) 
	begin 
		if aresetn = '0' then 
			s_state <= RESET; 
			jstk_x		<= (Others => '0');
			jstk_y		<= (Others => '0');
			btn_jstk   	<= '0';
                        btn_trigger	<= '0';
		elsif rising_edge(aclk) then 
			case (s_state) is 
				when RESET => 
					jstk_x_reg	<= (Others => '0');
					jstk_y_reg	<= (Others => '0');
					--btns_reg	<= (Others => '0');
					s_state <= READING_X_L; 

				when READING_X_L => 
					if s_axis_tvalid = '1' then
						jstk_x_reg(7 downto 0)	<= s_axis_tdata;
						s_state	<= READING_X_H;
					end if;

				when READING_X_H => 
					if s_axis_tvalid = '1' then
						jstk_x_reg(9 downto 8)	<= s_axis_tdata(1 downto 0);
						s_state	<= READING_X_H;
					end if;

				when READING_Y_L => 
					if s_axis_tvalid = '1' then
						jstk_y_reg(7 downto 0)	<= s_axis_tdata;
						s_state	<= READING_Y_H;
					end if;

				when READING_Y_H => 
					if s_axis_tvalid = '1' then
						jstk_y_reg(9 downto 8)	<= s_axis_tdata(1 downto 0);
						s_state	<= READING_FSB;
					end if;

				when READING_FSB =>
					if s_axis_tvalid = '1' then
						s_state	<= READING_X_L;
						jstk_x		<= jstk_x_reg;     
						jstk_y		<= jstk_y_reg;     
						btn_jstk   	<= s_axis_tdata(0);   
						btn_trigger	<= s_axis_tdata(1);
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
					m_axis_tdata	<= CMDSETLEDRGB;
					m_state <= WRITE_CMD; 

				when WRITE_CMD => 
					m_axis_tvalid	<= '1';
					if m_axis_tready = '1' then
						m_axis_tdata	<= led_r;
						m_state	<= WRITE_R;
					end if;

				when WRITE_R => 
					m_axis_tvalid	<= '1';
					if m_axis_tready = '1' then
						m_axis_tdata	<= led_g;
						m_state	<= WRITE_G;
					end if;

				when WRITE_G => 
					m_axis_tvalid	<= '1';
					if m_axis_tready = '1' then
						m_axis_tdata	<= led_b;
						m_state	<= WRITE_B;
					end if;

				when WRITE_B => 
					m_axis_tvalid	<= '1';
					if m_axis_tready = '1' then
						m_axis_tdata	<= (Others => '0');
						m_state	<= WAITING;
					end if;

				when WRITE_DUMMY => 
					m_axis_tvalid	<= '1';
					if m_axis_tready = '1' then
						m_axis_tvalid	<= '0';
						m_state	<= WAITING;
					end if;

				when WAITING => 
					m_axis_tvalid	<= '0';
					delay_counter	<= delay_counter + 1;
					if delay_counter = DELAY_CYCLES - 1 then
						delay_counter 	<= 0;
						m_state		<= WRITE_CMD;
						m_axis_tvalid	<= '1';
						m_axis_tdata	<= CMDSETLEDRGB;
					end if;

				when Others => 
					m_state <= RESET; -- output sincroni ad aclk
			end case; 
		end if; 
	end process m_FSM;

end architecture;
