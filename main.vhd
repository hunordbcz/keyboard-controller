LIBRARY ieee;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;
ENTITY keyboard_to_bcd IS
	GENERIC (
		clk_freq                       : INTEGER := 50_000_000;
		keyboard_debounce_counter_size : INTEGER := 8
	);
	PORT (
		clk           : IN STD_LOGIC;
		keyboard_clk  : IN STD_LOGIC;
		keyboard_data : IN STD_LOGIC;
		bcd_code      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		bcd_enable    : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END keyboard_to_bcd;
ARCHITECTURE behavior OF keyboard_to_bcd IS
	TYPE machine IS(waiting, new_code, trigger, new_output);
	SIGNAL state                  : machine;
	SIGNAL keyboard_code_new      : STD_LOGIC;
	SIGNAL keyboard_code          : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL prev_code_new          : STD_LOGIC := '1';
	SIGNAL break                  : STD_LOGIC := '0'; --'1' break code, '0' make code
	SIGNAL e0_code                : STD_LOGIC := '0'; --'1' multi-code commands, '0' single code commands
	SIGNAL caps_lock              : STD_LOGIC := '0';
	SIGNAL shift_r                : STD_LOGIC := '0';
	SIGNAL shift_l                : STD_LOGIC := '0';
	SIGNAL bcd                    : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"FFF";
	SIGNAL led_enable             : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
	SIGNAL reg_bcd                : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"FFFFFFFF";
	SIGNAL LED_activating_counter : std_logic_vector(1 DOWNTO 0);
	SIGNAL refresh_counter        : STD_LOGIC_VECTOR (31 DOWNTO 0);
	COMPONENT keyboard IS
		GENERIC (
			clk_freq              : INTEGER;
			debounce_counter_size : INTEGER
		);
		PORT (
			clk               : IN STD_LOGIC;
			keyboard_clk      : IN STD_LOGIC;
			keyboard_data     : IN STD_LOGIC;
			keyboard_code_new : OUT STD_LOGIC;
			keyboard_code     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
		);
	END COMPONENT;
BEGIN
	keyboard_0 : keyboard
		GENERIC MAP(clk_freq => clk_freq, debounce_counter_size => keyboard_debounce_counter_size)
	PORT MAP(clk         => clk, keyboard_clk => keyboard_clk, keyboard_data => keyboard_data, keyboard_code_new => keyboard_code_new, keyboard_code => keyboard_code);
	PROCESS (clk)
	BEGIN
		IF (rising_edge(clk)) THEN
			refresh_counter <= refresh_counter + 1;
		END IF;
	END PROCESS;
	LED_activating_counter <= refresh_counter(19 DOWNTO 18);
	PROCESS (LED_activating_counter)
		BEGIN
			CASE LED_activating_counter IS
				WHEN "00" =>
					bcd_enable <= "0111";
					bcd_code   <= reg_bcd(31 DOWNTO 24);
				WHEN "01" =>
					bcd_enable <= "1011";
					bcd_code   <= reg_bcd(23 DOWNTO 16);
				WHEN "10" =>
					bcd_enable <= "1101";
					bcd_code   <= reg_bcd(15 DOWNTO 8);
				WHEN "11" =>
					bcd_enable <= "1110";
					bcd_code   <= reg_bcd(7 DOWNTO 0);
				WHEN OTHERS => NULL;
			END CASE;
		END PROCESS;
		PROCESS (clk)
			BEGIN
				IF (clk'EVENT AND clk = '1') THEN
					prev_code_new <= keyboard_code_new;
					CASE state IS
						WHEN waiting =>
							IF (prev_code_new = '0' AND keyboard_code_new = '1') THEN
								state <= new_code;
							ELSE
								state <= waiting;
							END IF;
						WHEN new_code =>
							IF (keyboard_code = x"F0") THEN
								break <= '1';
								state <= waiting;
							ELSIF (keyboard_code = x"E0") THEN
								e0_code <= '1';
								state   <= waiting;
							ELSE
								bcd(11) <= '1'; --set internal value to unsupported code (for verification)
								state   <= trigger;
							END IF;
						WHEN trigger =>
							break   <= '0';
							e0_code <= '0';
							CASE keyboard_code IS
								WHEN x"58" => --caps lock code
									IF (break = '0') THEN
										caps_lock <= NOT caps_lock;
									END IF;
								WHEN x"12" => --left shift
									shift_l <= NOT break;
								WHEN x"59" => --right shift
									shift_r <= NOT break;
								WHEN OTHERS => NULL;
						END CASE;
						CASE keyboard_code IS
							WHEN x"29" => bcd <= x"000"; --space
							WHEN x"66" => bcd <= x"001"; --backspace: use another code to know the case at shifting
							WHEN x"5A" => bcd <= x"000"; --enter
							reg_bcd                 <= NOT x"00000000";
							WHEN x"76" => bcd <= x"000"; --escape
							reg_bcd                 <= NOT x"00000000";
							WHEN x"71" => --delete
								IF (e0_code = '1') THEN
									bcd <= x"000";
								END IF;
							WHEN OTHERS => NULL;
						END CASE;
						--shift + capslock letters or none (lowercase letters)
						IF ((shift_r = '0' AND shift_l = '0' AND caps_lock = '0') OR
						 ((shift_r = '1' OR shift_l = '1') AND caps_lock = '1')) THEN
							CASE keyboard_code IS
								WHEN x"1C" => bcd <= x"077"; --a
								WHEN x"32" => bcd <= x"07C"; --b
								WHEN x"21" => bcd <= x"039"; --c
								WHEN x"23" => bcd <= x"05E"; --d
								WHEN x"24" => bcd <= x"079"; --e
								WHEN x"2B" => bcd <= x"071"; --f
								WHEN x"34" => bcd <= x"07D"; --g
								WHEN x"33" => bcd <= x"076"; --h
								WHEN x"43" => bcd <= x"006"; --i
								WHEN x"3B" => bcd <= x"01E"; --j
								WHEN x"42" => bcd <= x"070"; --k
								WHEN x"4B" => bcd <= x"038"; --l
								WHEN x"3A" => bcd <= x"015"; --m
								WHEN x"31" => bcd <= x"037"; --n
								WHEN x"44" => bcd <= x"063"; --o
								WHEN x"4D" => bcd <= x"073"; --p
								WHEN x"15" => bcd <= x"067"; --q
								WHEN x"2D" => bcd <= x"031"; --r
								WHEN x"1B" => bcd <= x"06D"; --s
								WHEN x"2C" => bcd <= x"007"; --t
								WHEN x"3C" => bcd <= x"03E"; --u
								WHEN x"2A" => bcd <= x"026"; --v
								WHEN x"1D" => bcd <= x"02A"; --w
								WHEN x"22" => bcd <= x"036"; --x
								WHEN x"35" => bcd <= x"066"; --y
								WHEN x"1A" => bcd <= x"049"; --z
								WHEN OTHERS => NULL;
							END CASE;
						ELSE --letter is uppercase
							CASE keyboard_code IS
								WHEN x"1C" => bcd  <= x"0F7"; --A
								WHEN x"32" => bcd  <= x"0FC"; --B
								WHEN x"21" => bcd  <= x"0B9"; --C
								WHEN x"23" => bcd  <= x"0BE"; --D
								WHEN x"24" => bcd  <= x"0F9"; --E
								WHEN x"2B" => bcd  <= x"0F1"; --F
								WHEN x"34" => bcd  <= x"0FD"; --G
								WHEN x"33" => bcd  <= x"0F6"; --H
								WHEN x"43" => bcd  <= x"086"; --I
								WHEN x"3B" => bcd  <= x"09E"; --J
								WHEN x"42" => bcd <= x"0F0"; --K
								WHEN x"4B" => bcd <= x"0B8"; --L
								WHEN x"3A" => bcd <= x"095"; --M
								WHEN x"31" => bcd <= x"0B7"; --N
								WHEN x"44" => bcd <= x"0E3"; --O
								WHEN x"4D" => bcd <= x"0F3"; --P
								WHEN x"15" => bcd <= x"0E7"; --Q
								WHEN x"2D" => bcd <= x"0B1"; --R
								WHEN x"1B" => bcd <= x"0ED"; --S
								WHEN x"2C" => bcd <= x"087"; --T
								WHEN x"3C" => bcd <= x"0EE"; --U
								WHEN x"2A" => bcd <= x"0A6"; --V
								WHEN x"1D" => bcd <= x"0AA"; --W
								WHEN x"22" => bcd <= x"0B6"; --X
								WHEN x"35" => bcd <= x"0E6"; --Y
								WHEN x"1A" => bcd <= x"0C9"; --Z
								WHEN OTHERS => NULL;
							END CASE;
						END IF;
						--special character with shift
						IF (shift_l = '1' OR shift_r = '1') THEN
							CASE keyboard_code IS
								WHEN x"52" => bcd <= x"022"; --"
								WHEN x"4A" => bcd <= x"0D3"; --?
								WHEN x"4E" => bcd <= x"008"; --_
								WHEN x"5D" => bcd <= x"030"; --|
								WHEN OTHERS => NULL;
							END CASE;
						ELSE
							CASE keyboard_code IS
								WHEN x"45" => bcd <= x"03F"; --0
								WHEN x"16" => bcd <= x"006"; --1
								WHEN x"1E" => bcd <= x"05B"; --2
								WHEN x"26" => bcd <= x"04F"; --3
								WHEN x"25" => bcd <= x"064"; --4
								WHEN x"2E" => bcd <= x"06D"; --5
								WHEN x"36" => bcd <= x"07D"; --6
								WHEN x"3D" => bcd <= x"007"; --7
								WHEN x"3E" => bcd <= x"07F"; --8
								WHEN x"46" => bcd <= x"06F"; --9
								WHEN x"52" => bcd <= x"002"; --'
								WHEN x"41" => bcd <= x"004"; --,
								WHEN x"4E" => bcd <= x"040"; ---
								WHEN x"49" => bcd <= x"080"; --.
								WHEN x"55" => bcd <= x"048"; --=
								WHEN x"54" => bcd <= x"039"; --[
								WHEN x"5B" => bcd <= x"00F"; --]
								WHEN x"0E" => bcd <= x"020"; --`
								WHEN OTHERS => NULL;
							END CASE;
						END IF;
						IF (break = '0') THEN
							state <= new_output;
						ELSE
							state <= waiting;
						END IF;
						WHEN new_output =>
								IF (bcd(11) = '0') THEN
									IF (bcd = x"001") THEN
										CASE led_enable IS
											WHEN "00" =>
												led_enable          <= "01";
												reg_bcd(7 DOWNTO 0) <= NOT x"00";
											WHEN "01" =>
												led_enable           <= "10";
												reg_bcd(15 DOWNTO 8) <= NOT x"00";
												reg_bcd(7 DOWNTO 0)  <= reg_bcd(15 DOWNTO 8);
											WHEN "10" =>
												led_enable            <= "11";
												reg_bcd(23 DOWNTO 16) <= NOT x"00";
												reg_bcd(15 DOWNTO 8)  <= reg_bcd(23 DOWNTO 16);
												reg_bcd(7 DOWNTO 0)   <= reg_bcd(15 DOWNTO 8);
											WHEN "11" =>
												reg_bcd(31 DOWNTO 24) <= NOT x"00";
												reg_bcd(23 DOWNTO 16) <= reg_bcd(31 DOWNTO 24);
												reg_bcd(15 DOWNTO 8)  <= reg_bcd(23 DOWNTO 16);
												reg_bcd(7 DOWNTO 0)   <= reg_bcd(15 DOWNTO 8);
											WHEN OTHERS => NULL;
										END CASE;
									ELSE
										CASE led_enable IS
											WHEN "00" =>
												led_enable          <= "01";
												reg_bcd(7 DOWNTO 0) <= NOT bcd(7 DOWNTO 0);
											WHEN "01" =>
												led_enable           <= "10";
												reg_bcd(15 DOWNTO 8) <= reg_bcd(7 DOWNTO 0);
												reg_bcd(7 DOWNTO 0)  <= NOT bcd(7 DOWNTO 0);
											WHEN "10" =>
												led_enable            <= "11";
												reg_bcd(23 DOWNTO 16) <= reg_bcd(15 DOWNTO 8);
												reg_bcd(15 DOWNTO 8)  <= reg_bcd(7 DOWNTO 0);
												reg_bcd(7 DOWNTO 0)   <= NOT bcd(7 DOWNTO 0);
											WHEN "11" =>
												reg_bcd(31 DOWNTO 24) <= reg_bcd(23 DOWNTO 16);
												reg_bcd(23 DOWNTO 16) <= reg_bcd(15 DOWNTO 8);
												reg_bcd(15 DOWNTO 8)  <= reg_bcd(7 DOWNTO 0);
												reg_bcd(7 DOWNTO 0)   <= NOT bcd(7 DOWNTO 0);
											WHEN OTHERS => NULL;
										END CASE;
									END IF;
								END IF;
								state <= waiting;
						END CASE;
					END IF;
				END PROCESS;
END behavior;