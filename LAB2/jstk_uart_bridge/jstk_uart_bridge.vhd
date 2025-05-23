library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity jstk_uart_bridge is
	Generic (
		HEADER_CODE		: std_logic_vector(7 downto 0) := x"c0"; 	-- Header of the packet
		TX_DELAY		: positive := 1_000_000;    			-- Pause (in clock cycles) between two packets
		JSTK_BITS		: integer range 1 to 7 := 7    			-- Number of bits of the joystick axis to transfer to the PC 
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
	-- Implementation of both slave process ( receive leds data from pc to
	-- datapath ) and master process ( send joystick data from datapath to
	-- pc ) are made with a Finite State Machine (one for each task).

	-- # Slave: leds from pc to datapath
	-- Definition of the slave_FSM states in the s(lave)_state_type and
	-- declaration of s(lave)_state signal. The states' name describe their
	-- purpose.
	type s_state_type is (RESET, WAIT_HEADER, WAIT_RED, WAIT_GREEN, WAIT_BLUE);
	signal s_state	: s_state_type		:= RESET;

	-- Declaration of leds_red and leds_green registers to synchronize outputs
	signal led_r_reg	: std_logic_vector(led_r'RANGE)		:= (Others => '0');
	signal led_g_reg	: std_logic_vector(led_g'RANGE)		:= (Others => '0');

	-- # Master: joystick data from datapath to pc
	-- Definition of the master_FSM states in the m(aster)_state_type and
	-- declaration of m(aster)_state signal. The states' name describe their
	-- purpose, precisely:
	-- - WAITING is designed to comply the specification described at line 7;
	-- - the others are called WRITTEN_... since when entering the state, the
	--   output commutes to the corresponding value ( e.g. when entering 
	--   WRITTEN_Y, the m_axis_tdata is commuting simultaneously to the
	--   jstk_y value )
	type m_state_type is (RESET, WAITING, WRITTEN_HEADER, WRITTEN_X, WRITTEN_Y, WRITTEN_BTNS);
	signal m_state	: m_state_type	:= RESET;

	-- Declaration of delay_counter, which is  used to wait for TX_DELAY clock
	-- period in the WAITING m_state.
	signal delay_counter 	: integer range 0 to TX_DELAY	:= 0;
	-- Declaration of zeros, which is used to pad the m_axis_tdata in order to
	-- slice the incoming joystick coordinates ( 10 bits long ) in JSTK_BITS
	-- bits ( defined in the generic at line 8 ).
	constant zeros		: std_logic_vector(m_axis_tdata'HIGH - JSTK_BITS downto 0)	:= (Others => '0');

begin
	-- # PC Protocol: AXI4-Stream Slave, leds from pc to datapath
	-- The sensitivity list presents only aclk and aresetn since the module is
	-- synchronous with an asynchronous reset.
	s_FSM : process (aclk, aresetn) 
	begin 
		-- Asynchronous reset
		if aresetn = '0' then 
			s_state <= RESET; 		-- State reset

			led_r	<= (Others => '0');	-- Outputs reset
			led_g	<= (Others => '0');
			led_b	<= (Others => '0');

			led_r_reg	<= (Others => '0');	-- Registers reset
			led_g_reg	<= (Others => '0');

		elsif rising_edge(aclk) then 
			case s_state is 
				when RESET => 
					s_state <= WAIT_HEADER;

				when WAIT_HEADER => 
					if s_axis_tvalid = '1' and s_axis_tdata = HEADER_CODE then
						s_state	<= WAIT_RED;		-- Switching state only when valid data is HEADER_CODE
					end if;

				when WAIT_RED => 
					if s_axis_tvalid = '1' then
						led_r_reg	<= s_axis_tdata; -- Saving valid data in registers
						s_state	<= WAIT_GREEN;           -- Switching state only when data is valid
					end if;

				when WAIT_GREEN => 
					if s_axis_tvalid = '1' then
						led_g_reg	<= s_axis_tdata; -- Saving valid data in registers
						s_state	<= WAIT_BLUE;            -- Switching state only when data is valid
					end if;

				when WAIT_BLUE => 
					if s_axis_tvalid = '1' then		-- Checking blue led validity
						led_r	<= led_r_reg;		-- Writing the saved values of red and
						led_g	<= led_g_reg;		-- green leds from registers to output
						led_b	<= s_axis_tdata;	-- Writing directly (and registering at the
										-- output) the blue led
						s_state	<= WAIT_HEADER;		-- Since valid data was sent, getting ready
										-- to read next packet
					end if;

				when Others => 
					s_state <= RESET; 			-- Only for redundancy (VHDL good habit)
			end case; 
		end if; 
	end process s_FSM;

	-- Select the s_axis_tready based on current s_state: the module is
	-- always ready to read new data, but for when the module is in RESET.
	with s_state select s_axis_tready <=
		'1' when WAIT_HEADER | WAIT_RED | WAIT_GREEN | WAIT_BLUE,
		'0' when Others;

	-- # PC Protocol: AXI4-Stream Master, joystick data from datapath to pc
	-- The sensitivity list presents only aclk and aresetn since the module is
	-- synchronous with an asynchronous reset.
	m_FSM : process (aclk, aresetn) 
	begin 
		-- Asynchronous reset
		if aresetn = '0' then 
			m_state 	<= RESET; 		-- State reset

			delay_counter	<= 0;		-- Initializing the delay_counter register

		elsif rising_edge(aclk) then 
			case m_state is 
				when RESET => 

					m_state <= WRITTEN_HEADER; 

				when WRITTEN_HEADER => 
					if m_axis_tready = '1' then	-- When slave is ready to accept data:

						m_state	<= WRITTEN_X; 	-- Switching state only when a transaction happens
					end if;

				when WRITTEN_X => 
					if m_axis_tready = '1' then	-- When slave is ready to accept data:

						m_state	<= WRITTEN_Y; 	-- Switching state only when a transaction happens
					end if;

				when WRITTEN_Y => 
					if m_axis_tready = '1' then		-- When slave is ready to accept data:
						m_state	<= WRITTEN_BTNS; 	-- Switching state only when a transaction happens
					end if;

				when WRITTEN_BTNS => 
					if m_axis_tready = '1' then	-- When slave is ready to accept data:
						m_state	<= WAITING;	-- has just happenend, so data during delay will not be valid
					end if;

				when WAITING => 

					delay_counter	<= delay_counter + 1;		-- Using delay_counter to wait
					if delay_counter = TX_DELAY - 1 then		-- When delay has been accounted
						delay_counter 	<= 0;			-- Resetting delay_counter
						-- Preparing for a new packet
						m_state		<= WRITTEN_HEADER;	-- Switching state only when delay has passed	            
					end if;

				when Others => 
					m_state <= RESET;	-- Only for redundancy (VHDL good habit)
			end case; 
		end if; 
	end process m_FSM;


	-- Select the m_axis_tvalid based on current m_state: when valid data
	-- is on m_axis_tdata (see below), the tvalid must be '1' to make
	-- the trasaction
	with m_state select m_axis_tvalid <=
		'1'	when WRITTEN_HEADER | WRITTEN_X | WRITTEN_Y | WRITTEN_BTNS,
		'0' 	when Others;
	
	-- Select the m_axis_tdata based on current m_state: writing the
	-- corresponding data on tdata port in order to communicate the data to
	-- the slave 
	with m_state select m_axis_tdata <=
		-- Writing the HEADER_CODE to begin the chain of transactions
		HEADER_CODE 							when WRITTEN_HEADER,

		-- Writing sliced (to comply to JSTK_BITS) and padded x coord. with zeros to complete a byte
		zeros & jstk_x(jstk_x'HIGH downto jstk_x'HIGH-JSTK_BITS+1)	when WRITTEN_X,

		-- Writing sliced (to comply to JSTK_BITS) and padded y coord. with zeros to complete a byte
		zeros & jstk_y(jstk_y'HIGH downto jstk_y'HIGH-JSTK_BITS+1)	when WRITTEN_Y,

		-- Writing joystick button and trigger state as in specification (padded with 0s)
		(0 => btn_jstk, 1 => btn_trigger, Others => '0')		when WRITTEN_BTNS,

		(Others => '0')							when Others;

		


end architecture;
