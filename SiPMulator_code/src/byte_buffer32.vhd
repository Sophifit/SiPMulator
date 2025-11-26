library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.data_package.all;

entity byte_buffer32 is
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    we       : in  std_logic;
    windex   : in  unsigned(4 downto 0); -- 0..31
    wdata    : in  std_logic_vector(7 downto 0);
    bytes_out: out s_vector;
    rindex   : in  unsigned(4 downto 0); -- 0..31
    rdata    : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of byte_buffer32 is
  type ram_t is array (0 to 31) of std_logic_vector(7 downto 0);
  signal ram : ram_t := (others => (others => '0'));
begin
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      ram <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if we = '1' then
        ram(to_integer(windex)) <= wdata;
      end if;
    end if;
  end process;

  rdata <= ram(to_integer(rindex));

bytesgen: for i in 0 to 31 generate
	bytes_out(i)<=ram(i);
end generate bytesgen;	

end architecture;