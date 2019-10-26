LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY debounce IS
	GENERIC (
	counter_size : INTEGER := 19); --counter size (19 bits gives 10.5ms with 50MHz clock)
	PORT (
		clk     : IN STD_LOGIC;
		input   : IN STD_LOGIC;
		output  : OUT STD_LOGIC
	);
END debounce;

ARCHITECTURE logic OF debounce IS
	SIGNAL flipflops : STD_LOGIC_VECTOR(1 DOWNTO 0); --input flip flops
	SIGNAL counter_set : STD_LOGIC; --sync reset to zero
	SIGNAL counter_out : STD_LOGIC_VECTOR(counter_size DOWNTO 0) := (OTHERS => '0'); --counter output
BEGIN
	counter_set <= flipflops(0) XOR flipflops(1); --determine when to start/reset counter
 
	PROCESS (clk)
	BEGIN
		IF (clk'EVENT AND clk = '1') THEN
			flipflops(0) <= input;
			flipflops(1) <= flipflops(0);
			IF (counter_set = '1') THEN --reset counter because input is changing
				counter_out <= (OTHERS => '0');
			ELSIF (counter_out(counter_size) = '0') THEN --stable input time is not yet met
				counter_out <= counter_out + 1;
			ELSE --stable input time is met
				output <= flipflops(1);
			END IF; 
		END IF;
	END PROCESS;
END logic;