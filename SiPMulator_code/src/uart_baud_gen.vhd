library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_baud_gen is
  generic (
    CLK_FREQ_HZ : integer := 27000000;
    BAUD        : integer := 115200
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    tick_16x  : out std_logic; 
    tick_1x   : out std_logic 
  );
end entity;

architecture rtl of uart_baud_gen is
  -- DDS for 16x: 48-bit cumulative phase for high resolution
  signal acc16       : unsigned(47 downto 0) := (others => '0');
  constant INC16     : unsigned(47 downto 0) := to_unsigned(BAUD*16, 48);
  constant MODULO    : unsigned(47 downto 0) := to_unsigned(CLK_FREQ_HZ, 48);

  signal t16         : std_logic := '0';
  signal t1          : std_logic := '0';
  signal div16_cnt   : unsigned(3 downto 0) := (others => '0');
begin
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      acc16     <= (others => '0');
      t16       <= '0';
      t1        <= '0';
      div16_cnt <= (others => '0');
    elsif rising_edge(clk) then
        -- 16x tick generation using fractional DDS
      if (acc16 + INC16) >= MODULO then
        acc16 <= (acc16 + INC16) - MODULO;
        t16   <= '1';
        if div16_cnt = 15 then
          div16_cnt <= (others => '0');
          t1        <= '1';
        else
          div16_cnt <= div16_cnt + 1;
          t1        <= '0';
        end if;
      else
        acc16 <= acc16 + INC16;
        t16   <= '0';
        t1    <= '0';
      end if;
    end if;
  end process;

  tick_16x <= t16;
  tick_1x  <= t1;
end architecture;