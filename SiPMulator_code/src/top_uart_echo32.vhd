library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.data_package.all;

entity top_uart_echo32 is
  generic (
    CLK_FREQ_HZ : integer := 27000000;
    BAUD        : integer := 115200
  );
  port (
    clk   : in  std_logic;
    --rst_n     : in  std_logic;
    rx_i      : in  std_logic; 
    tx_o      : out std_logic; 
    sel  : out std_logic_vector(2 downto 0);
    bytes_out: out s_vector;
    
    led_recv  : out std_logic; 
    led_echo  : out std_logic   
  );
end entity;

architecture rtl of top_uart_echo32 is
  signal rst_n: std_logic;
  signal clk_100m: std_logic;
  -- Baud gen
  signal tick16_s, tick1_s : std_logic;

  -- RX
  signal rx_byte_s   : std_logic_vector(7 downto 0);
  signal rx_valid_s  : std_logic;

  -- Buffer
  signal buf_we_s    : std_logic;
  signal widx_s      : unsigned(4 downto 0);
  signal ridx_s      : unsigned(4 downto 0);
  signal wdata_s     : std_logic_vector(7 downto 0);
  signal rdata_s     : std_logic_vector(7 downto 0);

  -- TX
  signal tx_data_s   : std_logic_vector(7 downto 0);
  signal tx_start_s  : std_logic;
  signal tx_busy_s   : std_logic;

  -- Ctrl
  signal rx_cnt_s    : unsigned(5 downto 0);
  signal echo_on_s   : std_logic;

  -- LEDs
  signal led_recv_d  : std_logic := '0';
 

begin
  rst_n <= '1';
  -- Baud generator
  U_BAUD: entity work.uart_baud_gen
    generic map(
      CLK_FREQ_HZ => CLK_FREQ_HZ,
      BAUD        => BAUD
    )
    port map(
      clk      => clk,
      rst_n    => rst_n,
      tick_16x => tick16_s,
      tick_1x  => tick1_s
    );

  -- RX
  U_RX: entity work.uart_rx
    port map(
      clk        => clk,
      rst_n      => rst_n,
      tick_16x   => tick16_s,
      rx_i       => rx_i,
      data_o     => rx_byte_s,
      data_valid => rx_valid_s
    );

  -- Buffer 32
  U_BUF: entity work.byte_buffer32
    port map(
      clk     => clk,
      rst_n   => rst_n,
      we      => buf_we_s,
      windex  => widx_s,
      wdata   => wdata_s,
      bytes_out => bytes_out,
      rindex  => ridx_s,
      rdata   => rdata_s
    );

  wdata_s <= rx_byte_s;

  -- Control
  U_CTRL: entity work.echo_ctrl
    port map(
      clk         => clk,
      rst_n       => rst_n,
      rx_byte     => rx_byte_s,
      rx_valid    => rx_valid_s,
      buf_we      => buf_we_s,
      buf_windex  => widx_s,
      buf_rindex  => ridx_s,
      buf_rdata   => rdata_s,
      tx_data     => tx_data_s,
      tx_start    => tx_start_s,
      tx_busy     => tx_busy_s,
      count_rx    => rx_cnt_s,
      echo_active => echo_on_s,
      sel => sel
    );

  -- TX
  U_TX: entity work.uart_tx
    port map(
      clk      => clk,
      rst_n    => rst_n,
      tick_1x  => tick1_s,
      tx_o     => tx_o,
      data_i   => tx_data_s,
      start_i  => tx_start_s,
      busy_o   => tx_busy_s
    );

  -- LEDs/debug
  process(clk_100m, rst_n)
  begin
    if rst_n = '0' then
      led_recv_d <= '0';
    elsif rising_edge(clk_100m) then
      if rx_valid_s = '1' then
        led_recv_d <= not led_recv_d;
      end if;
    end if;
  end process;

  led_recv <= led_recv_d;
  led_echo <= echo_on_s;
end architecture;