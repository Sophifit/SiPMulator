library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Simple power-on / one-shot reset generator for TX controller
entity txResetOneShot is
    generic (
        PULSE_CYCLES : natural := 1024  -- length of reset pulse in clk cycles
    );
    port (
        clk      : in  STD_LOGIC;  -- system clock 
        ext_rst  : in  STD_LOGIC;  -- external async reset (active high)
        rst_out  : out STD_LOGIC   -- synchronous reset pulse (active high)
    );
end txResetOneShot;

architecture Behavioral of txResetOneShot is
    signal cnt      : unsigned(31 downto 0) := (others => '0');
    signal active   : STD_LOGIC := '1';
begin
    process(clk, ext_rst)
    begin
        if ext_rst = '1' then
            cnt    <= (others => '0');
            active <= '1';
        elsif rising_edge(clk) then
            if active = '1' then
                if cnt = to_unsigned(PULSE_CYCLES-1, cnt'length) then
                    active <= '0';
                else
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;

    rst_out <= '1' when (active = '1') or (ext_rst = '1') else '0';
end Behavioral;
