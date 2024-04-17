library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity digilent_jstk2 is
	Generic (
		DELAY_US		: integer := 25;    		-- Delay (in us) between two packets
		CLKFREQ		 	: integer := 100_000_000;  	-- Frequency of the aclk signal (in Hz)
		SPI_SCLKFREQ 		: integer := 5_000 		-- Frequency of the SPI SCLK clock signal (in Hz)
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
	-- Determining DELAY_CYCLES using the constraints DELAY_US, CLKFREQ and SPI_SCLKFREQ in the generic of the module
	constant DELAY_CYCLES 		: integer := DELAY_US * (CLKFREQ / 1_000_000) + CLKFREQ / SPI_SCLKFREQ;

	-- Declaration of delay_counter, which is  used to wait for TX_DELAY clock
	-- period in the WAITING m_state.
	signal delay_counter 		: integer range 0 to DELAY_CYCLES 	:= 0;

	-- Declaration of jstk_x_reg and jstk_y_reg registers to synchronize outputs
	signal jstk_x_reg		: std_logic_vector(jstk_x'RANGE) 	:= (Others => '0');
	signal jstk_y_reg		: std_logic_vector(jstk_y'RANGE) 	:= (Others => '0');

	-- # Slave: joystick data from joystick to datapath
	-- Definition of the slave_FSM states in the s(lave)_state_type and
	-- declaration of s(lave)_state signal. The states' name describe their
	-- purpose.
	-- There is no RESET state since it's not required: since there is no s_axis_tready,
	-- the s_FSM is always receiving data from the joystick, it only stops while aresetn='0':
	-- so the various resets are made only when aresetn='0'.
	-- L stands for low significant bits, H stands for high significant bits.
	-- FSB stands for fsButtons as in the digilent2 jstk manual.
	type s_state_type is (READING_X_L, READING_X_H, READING_Y_L, READING_Y_H, READING_FSB);
	signal s_state	: s_state_type	:= READING_X_L;

	-- # Master: leds from datapath to joystick
	-- Definition of the master_FSM states in the m(aster)_state_type and
	-- declaration of m(aster)_state signal. The states' name describe their
	-- purpose, precisely:
	-- - WAITING is designed to comply the specification described at line 6;
	-- - the others are called WRITTEN_... since when entering the state, the
	--   output commutes to the corresponding value ( e.g. when entering 
	--   WRITTEN_R, the m_axis_tdata is commuting simultaneously to the 
	--   leds_r value )
	-- - WRITTEN_DUMMY is the state in which we send a valid 0x00 data to
	--   comply with the packet required by the joystick module as written in
	--   the manual
	type m_state_type is (RESET, WAITING, WRITTEN_CMD, WRITTEN_R, WRITTEN_G, WRITTEN_B, WRITTEN_DUMMY);
	signal m_state	: m_state_type	:= RESET;

begin

	-- # JSTK2 Protocol: AXI4-Stream Slave, joystick data from joystick to datapath
	-- The sensitivity list presents only aclk and aresetn since the module is
	-- synchronous with an asynchronous reset.
	s_FSM : process (aclk, aresetn) 
	begin 
		-- Asynchronous reset
		if aresetn = '0' then 
			s_state <= READING_X_L; 		-- State reset

			jstk_x		<= (Others => '0');	-- Outputs reset
			jstk_y		<= (Others => '0');
			jstk_x_reg	<= (Others => '0');
			jstk_y_reg	<= (Others => '0');
			btn_jstk   	<= '0';
                        btn_trigger	<= '0';

		elsif rising_edge(aclk) then 
			case s_state is 
				when READING_X_L => 
					if s_axis_tvalid = '1' then
						jstk_x_reg(7 downto 0)	<= s_axis_tdata;		-- Saving valid 8 LSBs in registers (x coord.)
						s_state	<= READING_X_H;					-- Switching state only when data is valid
					end if;

				when READING_X_H => 
					if s_axis_tvalid = '1' then
						jstk_x_reg(9 downto 8)	<= s_axis_tdata(1 downto 0);	-- Saving valid 2 MSBs in registers (x coord.)
						s_state	<= READING_Y_L;					-- Switching state only when data is valid
					end if;

				when READING_Y_L => 
					if s_axis_tvalid = '1' then
						jstk_y_reg(7 downto 0)	<= s_axis_tdata;		-- Saving valid 8 LSBs in registers (y coord.)
						s_state	<= READING_Y_H;					-- Switching state only when data is valid
					end if;

				when READING_Y_H => 
					if s_axis_tvalid = '1' then
						jstk_y_reg(9 downto 8)	<= s_axis_tdata(1 downto 0);	-- Saving valid 2 MSBs in registers (y coord.)
						s_state	<= READING_FSB;					-- Switching state only when data is valid
					end if;

				when READING_FSB =>
					if s_axis_tvalid = '1' then					-- Checking buttons data validity
						jstk_x		<= jstk_x_reg;				-- Writing the saved values of x and
						jstk_y		<= jstk_y_reg;				-- y coord. from registers to output
						btn_jstk   	<= s_axis_tdata(0);			-- Writing directly (and registering at the
						btn_trigger	<= s_axis_tdata(1);			-- output) the buttons data

						s_state	<= READING_X_L;					-- Since valid data was sent, getting ready
													-- to read next packet
					end if;

				when Others => 
					s_state <= READING_X_L;		-- Only for redundancy (VHDL good habit)
			end case; 
		end if; 
	end process s_FSM;

	-- # JSTK2 Protocol: AXI4-Stream Master, leds data from datapath to joystick
	-- The sensitivity list presents only aclk and aresetn since the module is
	-- synchronous with an asynchronous reset.
	m_FSM : process (aclk, aresetn) 
	begin 
		-- Asynchronous reset
		if aresetn = '0' then 
			m_state 	<= RESET; 		-- State reset

			m_axis_tvalid	<= '0';			-- tvalid='0' when aresetn='0' or when in m_state RESET or WAITING
			m_axis_tdata	<= (Others => '0');	-- Null data output

		elsif rising_edge(aclk) then 
			case m_state is 
				when RESET => 
					delay_counter	<= 0;			-- Initializing the delay_counter register

					m_axis_tvalid	<= '1';			-- tvalid='1' is set when switching state to WRITTEN_CMD
					m_axis_tdata	<= CMDSETLEDRGB;        -- Writing the CMDSETLEDRGB in output
					m_state <= WRITTEN_CMD;

				when WRITTEN_CMD => 
					m_axis_tvalid	<= '1';			-- Redundant, should be already '1'
					if m_axis_tready = '1' then             -- When slave is ready to accept data:
						m_axis_tdata	<= led_r;	-- Writing led_r to output
						m_state	<= WRITTEN_R;		-- Switching state only when a transaction happens
					end if;

				when WRITTEN_R => 
					m_axis_tvalid	<= '1';			-- Redundant, should be already '1'
					if m_axis_tready = '1' then             -- When slave is ready to accept data:
						m_axis_tdata	<= led_g;       -- Writing led_g to output
						m_state	<= WRITTEN_G;           -- Switching state only when a transaction happens
					end if;

				when WRITTEN_G => 
					m_axis_tvalid	<= '1';			-- Redundant, should be already '1'
					if m_axis_tready = '1' then             -- When slave is ready to accept data:
						m_axis_tdata	<= led_b;       -- Writing led_b to output
						m_state	<= WRITTEN_B;           -- Switching state only when a transaction happens
					end if;

				when WRITTEN_B => 
					m_axis_tvalid	<= '1';				-- Redundant, should be already '1'
					if m_axis_tready = '1' then                     -- When slave is ready to accept data:
						m_axis_tdata	<= (Others => '0');     -- Writing dummy data to output
						m_state	<= WRITTEN_DUMMY;               -- Switching state only when a transaction happens
					end if;

				when WRITTEN_DUMMY => 				
					m_axis_tvalid	<= '1';			-- Redundant, should be already '1'
					if m_axis_tready = '1' then             -- When slave is ready to accept data:
						m_axis_tvalid	<= '0';         -- Switching to WAITING m_state, since the last transaction
						m_state	<= WAITING;             -- has just happenend, so data during delay will not be valid
					end if;

				when WAITING => 
					m_axis_tvalid	<= '0';				-- Redundant, should be already '0'
                                                                                                                                                   
					delay_counter	<= delay_counter + 1;           -- Using delay_counter to wait
					if delay_counter = DELAY_CYCLES - 1 then        -- When delay has been accounted
						delay_counter 	<= 0;                   -- Resetting delay_counter
                                                                                                                                                   
						m_axis_tvalid	<= '1';                 -- tvalid='1' is set when switching state to WRITTEN_HEADER
						m_axis_tdata	<= CMDSETLEDRGB;        -- Writing the HEADER_CODE in output
						m_state		<= WRITTEN_CMD;         -- Switching state only when delay has passed	           
					end if;

				when Others => 
					m_state <= RESET;	-- Only for redundancy (VHDL good habit)
			end case; 
		end if; 
	end process m_FSM;

end architecture;
