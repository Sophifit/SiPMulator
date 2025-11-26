library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity txFrameDriver_safe is
  generic ( RST_HOLD : natural := 2 );
  port (
    datClk  : in  STD_LOGIC; 
    ext_rst : in  STD_LOGIC;  
    done    : in  STD_LOGIC;  
    rst_out : out STD_LOGIC   
  );
end txFrameDriver_safe;

architecture Behavioral of txFrameDriver_safe is
  type st_t is (ASSERT_RST, RELEASE_RST);
  signal st       : st_t := ASSERT_RST;
  signal cnt      : unsigned(7 downto 0) := (others => '0');
  signal seen_low : STD_LOGIC := '0';  
begin
  process(datClk, ext_rst)
  begin
    if ext_rst = '1' then
      st       <= ASSERT_RST;
      cnt      <= (others => '0');
      seen_low <= '0';
      rst_out  <= '1';
    elsif rising_edge(datClk) then
      case st is
        when ASSERT_RST =>
          rst_out <= '1';
          seen_low <= '0';
          if cnt = to_unsigned(RST_HOLD-1, cnt'length) then
            cnt <= (others => '0');
            st  <= RELEASE_RST;
          else
            cnt <= cnt + 1;
          end if;

        when RELEASE_RST =>
          rst_out <= '0';
          if seen_low = '0' then
            if done = '0' then
              seen_low <= '1';          -- detected frame startup
            end if;
          else
            if done = '1' then          -- end of frame
              st       <= ASSERT_RST;   -- reassemble for the next
              cnt      <= (others => '0');
              seen_low <= '0';
            end if;
          end if;
      end case;
    end if;
  end process;
end Behavioral;
