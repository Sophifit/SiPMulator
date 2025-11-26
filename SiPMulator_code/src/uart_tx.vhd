library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Patched UART TX:
--  - Latches start_i requests so a 1-clk pulse won't be missed
--  - start_i may be a single-cycle pulse at clk speed; TX will begin at next tick_1x
entity uart_tx is
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    tick_1x  : in  std_logic;               -- baud tick
    tx_o     : out std_logic;               -- UART TX pin
    data_i   : in  std_logic_vector(7 downto 0);
    start_i  : in  std_logic;               -- 1-clk pulse accepted any time
    busy_o   : out std_logic                -- '1' while transmitting
  );
end entity;

architecture rtl of uart_tx is
  type state_t is (IDLE, START, DATA, STOP);
  signal state        : state_t := IDLE;
  signal bit_idx      : unsigned(2 downto 0) := (others => '0');
  signal tx_reg       : std_logic_vector(7 downto 0) := (others => '0');
  signal txd          : std_logic := '1';
  signal busy         : std_logic := '0';

  -- Latch de solicitud de inicio: captura start_i asíncronamente al tick
  signal start_latched: std_logic := '0';
begin
  tx_o   <= txd;
  busy_o <= busy;

  process(clk, rst_n)
  begin
    if rst_n = '0' then
      start_latched <= '0';
      state         <= IDLE;
      bit_idx       <= (others => '0');
      txd           <= '1';
      busy          <= '0';
    elsif rising_edge(clk) then
      if (state = IDLE) and (start_i = '1') then
        start_latched <= '1';
      end if;

      if tick_1x = '1' then
        case state is
          when IDLE =>
            busy <= '0';
            txd  <= '1';
            if start_latched = '1' then
              tx_reg        <= data_i;
              state         <= START;
              busy          <= '1';
              start_latched <= '0'; 
            end if;

          when START =>
            txd     <= '0'; 
            bit_idx <= (others => '0');
            state   <= DATA;

          when DATA =>
            txd <= tx_reg(to_integer(bit_idx));
            if bit_idx = 7 then
              state <= STOP;
            else
              bit_idx <= bit_idx + 1;
            end if;

          when STOP =>
            txd   <= '1';
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture;