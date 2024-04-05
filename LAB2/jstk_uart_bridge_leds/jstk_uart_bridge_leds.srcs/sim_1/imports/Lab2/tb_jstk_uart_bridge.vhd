library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real."ceil";
use IEEE.math_real."log2";

entity tb_jstk_uart_bridge is
--  Port ( );
end tb_jstk_uart_bridge;

architecture Behavioral of tb_jstk_uart_bridge is
  	-- Constants declarations
  	constant CLK_PER	: time				:= 10ns;
	constant ISTANTANEOUS_LEDS : integer range 0 to 1	:= 0;
	-- 0 vuol dire INSTANEO, all'ultimo colpo di clk con il dato del led blu mi aspetto che i led cambino. 1 vuol dire che aspetta un colpo di clk
  	constant TX_DELAY	: positive			:= 5;
	constant HEADER_CODE	: std_logic_vector(7 downto 0)	:= x"c0";
	constant JSTK_BITS	: integer range 1 to 7 		:= 7;

	-- Component delcaration
	component jstk_uart_bridge is
	Generic (
		HEADER_CODE	: std_logic_vector(7 downto 0) 	:= x"c0"; -- Header of the packet
		TX_DELAY	: positive 			:= 1_000_000;    -- Pause (in clock cycles) between two packets
		JSTK_BITS	: integer range 1 to 7 		:= 7    -- Number of bits of the joystick axis to transfer to the PC 
	);
	Port (
		aclk 		: in	std_logic;
		aresetn		: in	std_logic;

		-- Data going TO the PC (i.e., joystick position and buttons state)
		m_axis_tvalid	: out 	std_logic;
		m_axis_tdata	: out 	std_logic_vector(7 downto 0);
		m_axis_tready	: in 	std_logic;

		-- Data coming FROM the PC (i.e., LED color)
		s_axis_tvalid	: in 	std_logic;
		s_axis_tdata	: in	std_logic_vector(7 downto 0);
		s_axis_tready	: out 	std_logic;

		jstk_x		: in 	std_logic_vector(9 downto 0);
		jstk_y		: in 	std_logic_vector(9 downto 0);
		btn_jstk	: in 	std_logic;
		btn_trigger	: in 	std_logic;

		led_r		: out 	std_logic_vector(7 downto 0);
		led_g		: out 	std_logic_vector(7 downto 0);
		led_b		: out 	std_logic_vector(7 downto 0)
	);
	end component;

	signal tb_aclk		: std_logic			:= '0';
	signal tb_aresetn	: std_logic			:= '0';

	signal tb_led_r		: std_logic_vector(7 downto 0)	:= (Others => '0');
	signal tb_led_g		: std_logic_vector(7 downto 0)	:= (Others => '0');
	signal tb_led_b		: std_logic_vector(7 downto 0)	:= (Others => '0');
	type rgb is record 
	 	red	: std_logic_vector(tb_led_r'RANGE);
	  	green 	: std_logic_vector(tb_led_g'RANGE);
	  	blue  	: std_logic_vector(tb_led_b'RANGE);
	end record rgb;
	signal tb_leds		: rgb				:= (Others => (Others => '0'));

	signal tb_m_axis_tvalid	: std_logic			:= '0';
	signal tb_m_axis_tdata	: std_logic_vector(7 downto 0)	:= (Others => '0');
	signal tb_m_axis_tready	: std_logic			:= '0';
	signal tb_s_axis_tvalid	: std_logic			:= '0';
	signal tb_s_axis_tdata	: std_logic_vector(7 downto 0)	:= (Others => '0');
	signal tb_s_axis_tready	: std_logic			:= '0';
	signal tb_jstk_x	: std_logic_vector(9 downto 0)	:= (Others => '0');
	signal tb_jstk_y	: std_logic_vector(9 downto 0)	:= (Others => '0');
	signal tb_btn_jstk	: std_logic			:= '0';
	signal tb_btn_trigger	: std_logic			:= '0';


begin
  	dut_jstk_uart_bridge_inst : jstk_uart_bridge
	Generic Map(
		HEADER_CODE	=> HEADER_CODE,
		TX_DELAY	=> TX_DELAY,
		JSTK_BITS	=> JSTK_BITS
	)
	Port Map(
		aclk 		=> tb_aclk,
		aresetn		=> tb_aresetn,
		m_axis_tvalid	=> tb_m_axis_tvalid,
		m_axis_tdata	=> tb_m_axis_tdata,
		m_axis_tready	=> tb_m_axis_tready,
		s_axis_tvalid	=> tb_s_axis_tvalid,
		s_axis_tdata	=> tb_s_axis_tdata,
		s_axis_tready	=> tb_s_axis_tready,
		jstk_x		=> tb_jstk_x,
		jstk_y		=> tb_jstk_y,
		btn_jstk	=> tb_btn_jstk,
		btn_trigger	=> tb_btn_trigger,
		led_r		=> tb_led_r,
		led_g		=> tb_led_g,
		led_b		=> tb_led_b
	);


	tb_aclk	<= not tb_aclk after CLK_PER/2;

	tb_leds.red 	<= tb_led_r;
	tb_leds.green 	<= tb_led_g;
	tb_leds.blue 	<= tb_led_b;

	simulation : process
	begin
		-----------------
		-- TEST CASE 0 --
		-----------------

	 	tb_s_axis_tvalid	<= '0';
	 	tb_s_axis_tdata		<= (Others => '0');
	 	tb_aresetn		<= '0';
	  	wait for CLK_PER;
	      	-- TC0 t0
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '0' report "JACK ARRABIATO! Test fallito al caso #0" severity FAILURE;

	 	tb_aresetn		<= '1';
	  	wait for CLK_PER;
	  	-- TC0 t1
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #0" severity FAILURE;

	  	wait for CLK_PER;
		-- TC0 t2
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #0" severity FAILURE;

	  	wait for CLK_PER;
		-- TC0 t3
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #0" severity FAILURE;

	 	tb_aresetn		<= '0';
	  	wait for CLK_PER;
	  	-- TC0 t4
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '0' report "JACK ARRABIATO! Test fallito al caso #0" severity FAILURE;

	 	tb_aresetn		<= '1';
	  	wait for CLK_PER;
	  	-- TC0 t5
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #0" severity FAILURE;

	  	wait for CLK_PER;
	  	-- TC0 t6
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #0" severity FAILURE;

		-----------------
		-- TEST CASE 1 --
		-----------------

	 	tb_s_axis_tvalid	<= '0';
	 	tb_s_axis_tdata		<= (Others => '0');
	 	tb_aresetn		<= '0';
	  	wait for CLK_PER;
	      	-- TC1 t0
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '0' report "JACK ARRABIATO! Test fallito al caso #1" severity FAILURE;

	 	tb_aresetn		<= '1';
	  	wait for CLK_PER;
	  	-- TC1 t1
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #1" severity FAILURE;

		tb_s_axis_tdata		<= HEADER_CODE;
	 	tb_s_axis_tvalid	<= '1';
	  	wait for CLK_PER;
		-- TC1 t2
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #1" severity FAILURE;

		tb_s_axis_tdata		<= x"ab";
	  	wait for CLK_PER;
		-- TC1 t3
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #1" severity FAILURE;

		tb_s_axis_tdata		<= x"cd";
	  	wait for CLK_PER;
	  	-- TC1 t4
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #1" severity FAILURE;

		tb_s_axis_tdata		<= x"ef";
	  	wait for CLK_PER;
	  	-- TC1 t5
		assert tb_leds.red = x"ab" and tb_leds.green = x"cd" and tb_leds.blue = x"ef" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #1" severity FAILURE;

		tb_s_axis_tdata		<= (Others => '0');
		tb_s_axis_tvalid	<= '0';
	  	wait for CLK_PER;
	  	-- TC1 t6
		assert tb_leds.red = x"ab" and tb_leds.green = x"cd" and tb_leds.blue = x"ef" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #1" severity FAILURE;

		-----------------
		-- TEST CASE 2 --
		-----------------

	 	tb_s_axis_tvalid	<= '0';
	 	tb_s_axis_tdata		<= (Others => '0');
	 	tb_aresetn		<= '0';
	  	wait for CLK_PER;
	      	-- TC2 t0
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '0' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;

	 	tb_aresetn		<= '1';
	  	wait for CLK_PER;
	  	-- TC2 t1
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;

		tb_s_axis_tdata		<= HEADER_CODE;
	  	wait for CLK_PER;
		-- TC2 t2
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;

		tb_s_axis_tvalid	<= '1';
		tb_s_axis_tdata		<= x"ab";
	  	wait for CLK_PER;
		-- TC2 t3
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;

	  	wait for CLK_PER;
	  	-- TC2 t4
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;

	 	tb_s_axis_tvalid	<= '0';
		tb_s_axis_tdata		<= HEADER_CODE;
	  	wait for CLK_PER;
	  	-- TC2 t5
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;

		tb_s_axis_tdata		<= x"ff";
	  	wait for CLK_PER;
	  	-- TC2 t6
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;
		
		tb_s_axis_tdata		<= x"ee";
	  	wait for CLK_PER;
	  	-- TC2 t7
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;
		
		tb_s_axis_tdata		<= x"dd";
	  	wait for CLK_PER;
	  	-- TC2 t8
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;
		
		tb_s_axis_tdata		<= HEADER_CODE;
	 	tb_s_axis_tvalid	<= '1';
	  	wait for CLK_PER;
	  	-- TC2 t9
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;
		
		tb_s_axis_tdata		<= x"aa";
	  	wait for CLK_PER;
	  	-- TC2 t10
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;
		
		tb_s_axis_tdata		<= x"bb";
	  	wait for CLK_PER;
	  	-- TC2 t11
		assert tb_leds.red = x"00" and tb_leds.green = x"00" and tb_leds.blue = x"00" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;
		
		tb_s_axis_tdata		<= x"cc";
	  	wait for CLK_PER;
	  	-- TC2 t12
		assert tb_leds.red = x"aa" and tb_leds.green = x"bb" and tb_leds.blue = x"cc" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;
		
		tb_s_axis_tdata		<= (Others => '0');
		tb_s_axis_tvalid	<= '0';
	  	wait for CLK_PER;
	  	-- TC2 t13
		assert tb_leds.red = x"aa" and tb_leds.green = x"bb" and tb_leds.blue = x"cc" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;
		
		tb_s_axis_tdata		<= (Others => '0');
		tb_s_axis_tvalid	<= '0';
	  	wait for CLK_PER;
	  	-- TC2 t14
		assert tb_leds.red = x"aa" and tb_leds.green = x"bb" and tb_leds.blue = x"cc" and tb_s_axis_tready = '1' report "JACK ARRABIATO! Test fallito al caso #2" severity FAILURE;
		
--		assert FALSE report "JACK FELICE! TEST: OK!" severity FAILURE;
	  	wait;
	end process simulation;

end Behavioral;
