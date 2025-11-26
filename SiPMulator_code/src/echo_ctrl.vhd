library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.data_package.all;


entity echo_ctrl is
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;

    -- RX interface
    rx_byte       : in  std_logic_vector(7 downto 0);
    rx_valid      : in  std_logic;

    -- Buffer 32
    buf_we        : out std_logic;
    buf_windex    : out unsigned(4 downto 0);
    buf_rindex    : out unsigned(4 downto 0);
    buf_rdata     : in  std_logic_vector(7 downto 0);

    -- TX interface
    tx_data       : out std_logic_vector(7 downto 0);
    tx_start      : out std_logic;
    tx_busy       : in  std_logic;
    sel : out STD_LOGIC_VECTOR(2 downto 0);
 
    count_rx      : out unsigned(5 downto 0); -- cuenta 0..32
    echo_active   : out std_logic
  );
end entity;

architecture rtl of echo_ctrl is
  type state_t is (WAIT_BUSY, COMMAND, RECV, ECHO_PREP, ECHO_ARM, ECHO_WAIT_BUSY_HI, ECHO_WAIT_BUSY_LO);
  signal state      : state_t := COMMAND;

  signal widx       : unsigned(4 downto 0) := (others => '0');
  signal ridx       : unsigned(4 downto 0) := (others => '0');
  signal rx_cnt     : unsigned(5 downto 0) := (others => '0'); -- 0..32

  signal buf_we_i   : std_logic := '0';
  signal tx_go_i    : std_logic := '0';
  signal echo_on    : std_logic := '0';

  signal tx_data_reg: std_logic_vector(7 downto 0) := (others => '0');

begin
  buf_windex  <= widx;
  buf_rindex  <= ridx;
  count_rx    <= rx_cnt;
  echo_active <= echo_on;
  buf_we      <= buf_we_i;

  tx_start    <= tx_go_i;
  tx_data     <= tx_data_reg;

 
process(clk, rst_n)
  begin
    if rst_n = '0' then
      state       <= RECV;
      widx        <= (others => '0');
      ridx        <= (others => '0');
      rx_cnt      <= (others => '0');
      buf_we_i    <= '0';
      tx_go_i     <= '0';
      echo_on     <= '0';
      tx_data_reg <= (others => '0');
    elsif rising_edge(clk) then
      buf_we_i <= '0';
      tx_go_i  <= '0';

      case state is


        when COMMAND =>
          if rx_valid = '1' and rx_byte ="00000000" then
             state <= RECV;
          elsif rx_valid = '1' and rx_byte ="10101010" then--AA ACK
             tx_data_reg <= "10101010";
             tx_go_i     <= '1';
             state <= WAIT_BUSY;
          elsif rx_valid = '1' and rx_byte ="10111011" then--BB only noise
             tx_data_reg <= "10111011";
             sel <= "000";
             tx_go_i     <= '1';
             state <= WAIT_BUSY;
          elsif rx_valid = '1' and rx_byte ="11001100" then--CC  noise + preload random pulse CC
             tx_data_reg <= "11001100";
             sel <= "001";
             tx_go_i     <= '1';
             state <= WAIT_BUSY;
          elsif rx_valid = '1' and rx_byte ="11011101" then---- periodic preload pulse DD 
             tx_data_reg <= "11011101";
             sel <= "010";
             tx_go_i     <= '1';
             state <= WAIT_BUSY;
          elsif rx_valid = '1' and rx_byte ="11101110" then---- user pulse EE
             tx_data_reg <= "11101110";
             sel <= "100";
             tx_go_i     <= '1';
             state <= WAIT_BUSY;
          elsif rx_valid = '1' and rx_byte ="11111111" then----FF change pulse
             tx_data_reg <= "11111111";
             sel <= "011";
             tx_go_i     <= '1';
             state <= WAIT_BUSY;
          end if;
        

       when WAIT_BUSY =>
          if tx_busy = '1' then
            state <=WAIT_BUSY;
          else
            state <=COMMAND;
          end if;
      


        when RECV =>
          echo_on <= '0';
          if rx_valid = '1' then
            buf_we_i <= '1';
           
            if rx_cnt /= 31 then
              widx <= widx + 1;
            end if;
            rx_cnt <= rx_cnt + 1;
            if rx_cnt = 31 then
              state <= ECHO_PREP;
            end if;
          end if;

        when ECHO_PREP =>
          ridx    <= (others => '0');
          echo_on <= '1';
          state   <= ECHO_ARM;

        when ECHO_ARM =>
        
          tx_data_reg <= buf_rdata;
          tx_go_i     <= '1';
          state       <= ECHO_WAIT_BUSY_HI;

        when ECHO_WAIT_BUSY_HI =>
          if tx_busy = '1' then
            state <= ECHO_WAIT_BUSY_LO;
          end if;

        when ECHO_WAIT_BUSY_LO =>
          if tx_busy = '0' then
            if ridx = 31 then
              state   <= RECV;
              widx    <= (others => '0');
              rx_cnt  <= (others => '0');
              echo_on <= '0';
            else
              ridx  <= ridx + 1;
              state <= ECHO_ARM;
            end if;
          end if;
      end case;
    end if;
  end process;


end architecture;