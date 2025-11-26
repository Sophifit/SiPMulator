library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.data_package.all;

entity pulseLUT_sync is
    generic (
        N : natural := 32
    );
    port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        sel_lfsr : in  STD_LOGIC;
        sel      : in  STD_LOGIC_VECTOR(2 downto 0);
        done     : in  STD_LOGIC;
        bytes_in : in s_vector;
        outNum   : out STD_LOGIC_VECTOR(7 downto 0)
    );
end pulseLUT_sync;

architecture Behavioral of pulseLUT_sync is
    signal idx : integer range 0 to N-1 := 0;

    -- current pulse variant
    signal pulso_actual : STD_LOGIC_VECTOR(1 downto 0) := "00";

    signal outNums1, outNums2, outNums3 : STD_LOGIC_VECTOR(7 downto 0);

    -- synchronizer and edge detector for 'done'
    signal done_meta, done_sync, done_sync_d, done_rise : STD_LOGIC := '0';

    -- final selector: "00" = pulse preload, "01" = noise, "10" = user pulse
    signal sel2 : STD_LOGIC_vector(1 downto 0) := "01";

    type pulse_rom_t is array (0 to N-1) of STD_LOGIC_VECTOR(7 downto 0);
    type s_vector is array(0 to 31) of std_logic_vector(7 downto 0);

    constant pulse_rom_1 : pulse_rom_t := (
        x"80", x"80", x"80", x"80", x"87", x"A0", x"B6", x"BE",
        x"A8", x"95", x"88", x"82", x"80", x"80", x"80", x"80",
        x"80", x"80", x"80", x"80", x"80", x"80", x"80", x"80",
        x"80", x"80", x"80", x"80", x"80", x"80", x"80", x"80"
    );

    constant pulse_rom_2 : pulse_rom_t := (
        x"80", x"BD", x"9E", x"91", x"89", x"85", x"82", x"82",
        x"81", x"80", x"80", x"80", x"80", x"80", x"80", x"80",
        x"80", x"80", x"80", x"80", x"80", x"80", x"80", x"80",
        x"80", x"80", x"80", x"80", x"80", x"80", x"80", x"80"
    );

    constant pulse_rom_3 : pulse_rom_t := (
        x"80", x"BF", x"A1", x"94", x"8C", x"88", x"84", x"83",
        x"82", x"81", x"80", x"80", x"80", x"80", x"80", x"80",
        x"80", x"80", x"80", x"80", x"80", x"80", x"80", x"80",
        x"80", x"80", x"80", x"80", x"80", x"80", x"80", x"80"
    );

    constant pulse_rom_4 : pulse_rom_t := (
        x"80", x"BC", x"9B", x"90", x"89", x"86", x"84", x"83",
        x"83", x"82", x"81", x"80", x"80", x"80", x"80", x"80",
        x"80", x"80", x"80", x"80", x"80", x"80", x"80", x"80",
        x"80", x"80", x"80", x"80", x"80", x"80", x"80", x"80"
    );

    constant pulse_rom_6 : pulse_rom_t := (
        x"7F", x"80", x"81", x"80", x"7F", x"80", x"81", x"80",
        x"7F", x"80", x"81", x"80", x"7F", x"81", x"80", x"7F",
        x"80", x"81", x"7F", x"80", x"7F", x"80", x"81", x"80",
        x"7F", x"80", x"81", x"80", x"7F", x"81", x"80", x"7F"
    );

    function rom_sel(s : STD_LOGIC_VECTOR(1 downto 0); i : integer)
        return STD_LOGIC_VECTOR is
    begin
        case s is
            when "00" => return pulse_rom_1(i);
            when "01" => return pulse_rom_2(i);
            when "10" => return pulse_rom_3(i);
            when others => return pulse_rom_4(i);
        end case;
    end function;

begin
    -- sync + edge detect for 'done'
    process(clk)
    begin
        if rising_edge(clk) then
            done_meta   <= done;
            done_sync   <= done_meta;
            done_sync_d <= done_sync;
            done_rise   <= done_sync and not done_sync_d;
        end if;
    end process;

  -- LUT index, 1 advance per done_rise
    process(clk, rst)
    begin
        if rst = '1' then
            idx <= 0;
        elsif rising_edge(clk) then
            if done_rise = '1' then
                if idx = N-1 then
                    idx <= 0;
                else
                    idx <= idx + 1;
                end if;
            end if;
        end if;
    end process;

   -- mix selection and pulse variant change
    process(clk, rst)
    begin
        if rst = '1' then
            sel2         <= "01";        -- default noise
            pulso_actual <= "00";
        elsif rising_edge(clk) then
            -- Modo de mezcla
            if sel = "000" then--only noise
                sel2 <= "01";
            elsif sel = "001" and sel_lfsr = '0' then--noise + pulse preload lfsr desborda
                sel2 <= "00";
            elsif sel = "001" and sel_lfsr = '1' then--noise + pulse preload lfsr desborda
                sel2 <= "01";
            elsif sel = "010"  then--periodic pulse
                sel2 <= "00";
            elsif sel = "100"  and sel_lfsr = '0' then--noise + pulse user + lfsr desborda
                sel2 <= "00";
             elsif sel = "100"  and sel_lfsr = '1' then--noise + pulse user + lfsr desborda
                sel2 <= "10";
            end if;

          -- Rotate pulse in "11" mode: 1 step per sample (synchronized to done)
            if sel = "011" and done_rise = '1' then
                if pulso_actual = "11" then
                    pulso_actual <= "00";
                else
                    pulso_actual <= std_logic_vector(unsigned(pulso_actual) + 1);
                end if;
            end if;
        end if;
    end process;

    outNums1 <= rom_sel(pulso_actual, idx);
    outNums2 <= pulse_rom_6(idx);
    outNums3 <= bytes_in(idx);

    with sel2 select
        outNum <= outNums1 when "00",--preload pulse
                  outNums2 when "01",--only noise
                  outNums3 when others;--10 user pulse
end Behavioral;
