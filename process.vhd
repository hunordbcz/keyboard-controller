LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
ENTITY keyboard IS
	PORT
	(
		clk      : IN std_logic;
		keyboard_clk  : IN std_logic;
		keyboard_data  : IN std_logic;
		keyboard_code_new : OUT std_logic;
		keyboard_code : OUT std_logic_vector(7 DOWNTO 0)
		
	);
END keyboard;
ARCHITECTURE arch1 OF keyboard IS
	CONSTANT clk_freq : INTEGER := 50_000_000;
	SIGNAL keyboard_word   : std_logic_vector(10 DOWNTO 0);
	SIGNAL error      : std_logic; --error flag
	SIGNAL keyboard_clk_f  : std_logic; --debounced keyboard clk
	SIGNAL keyboard_data_f  : std_logic; --debounced keyboard data
	SIGNAL count_idle : INTEGER RANGE 0 TO clk_freq / 18_000;
	COMPONENT debounce IS
		PORT
		(
			clk    : IN std_logic;
			input  : IN std_logic;
			output : OUT std_logic
		);
	END COMPONENT;
BEGIN
	debounce_clk : debounce
	PORT MAP
	(
		clk    => clk,
		input  => keyboard_clk,
		output => keyboard_clk_f
	);
	debounce_data : debounce
	PORT MAP
	(
		clk    => clk,
		input  => keyboard_data,
		output => keyboard_data_f
	);
	PROCESS (keyboard_clk_f)
	BEGIN
		IF falling_edge(keyboard_clk_f) THEN --falling edge of keyboard clk
			keyboard_word <= keyboard_data_f & keyboard_word(10 DOWNTO 1); --shift in keyboard data bit
		END IF;
	END PROCESS;
	error <= NOT (NOT keyboard_word(0) AND keyboard_word(10) AND
		(keyboard_word(9) XOR keyboard_word(8) XOR keyboard_word(7) XOR
		keyboard_word(6) XOR keyboard_word(5) XOR keyboard_word(4) XOR
		keyboard_word(3) XOR keyboard_word(2) XOR keyboard_word(1)));
		PROCESS (clk)
		BEGIN
			IF rising_edge(clk) THEN --rising edge of system clk
				IF keyboard_clk_f = '0' THEN --low keyboard clk, PS/2 is active
					count_idle <= 0; --reset idle counter
				ELSIF count_idle /= clk_freq / 18_000 THEN --keyboard clk has been high less than a half clk period (<55us)
					count_idle <= count_idle + 1; --continue counting
				END IF;
				IF count_idle = clk_freq / 18_000 AND error = '0' THEN --idle threshold reached and no errors detected
					keyboard_code_new <= '1'; --set flag that new PS/2 code is available
					keyboard_code <= keyboard_word(8 DOWNTO 1); --output new PS/2 code
				ELSE --PS/2 port active or error detected
					keyboard_code_new <= '0'; --set flag that PS/2 transaction is in progress
				END IF;
			END IF;
		END PROCESS;
END arch1;