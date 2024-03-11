

entity ShiftRegister_v0 is
    Port (
    ---------- Reset/Clock ---------- 
        reset : IN STD_LOGIC;
        clk : IN STD_LOGIC;
    ---------------------------------
    ------------- Data -------------- 
        din : IN STD_LOGIC;
        dout : OUT STD_LOGIC
    --------------------------------- 
    );
end ShiftRegister_v0;

