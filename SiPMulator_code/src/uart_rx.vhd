library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;
    tick_16x   : in  std_logic;      -- de uart_baud_gen
    rx_i       : in  std_logic;      -- pin UART RX externo
    data_o     : out std_logic_vector(7 downto 0);
    data_valid : out std_logic       -- pulso 1 clk cuando hay un byte nuevo
  );
end entity;

architecture rtl of uart_rx is
  type state_t is (IDLE, START, DATA, STOP);
  signal state      : state_t := IDLE;

  -- Doble sincronizador para la línea RX (evita metastabilidad)
  signal rx_sync0, rx_sync1 : std_logic := '1';

  -- Oversampling
  signal os_cnt     : unsigned(3 downto 0) := (others => '0'); -- 0..15
  signal bit_idx    : unsigned(2 downto 0) := (others => '0'); -- 0..7
  signal shifter    : std_logic_vector(7 downto 0) := (others => '0');

  signal dv         : std_logic := '0';
begin
  data_o     <= shifter;
  data_valid <= dv;

  -- Sincronizador de entrada
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      rx_sync0 <= '1';
      rx_sync1 <= '1';
    elsif rising_edge(clk) then
      rx_sync0 <= rx_i;
      rx_sync1 <= rx_sync0;
    end if;
  end process;

  -- FSM RX
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      state   <= IDLE;
      os_cnt  <= (others => '0');
      bit_idx <= (others => '0');
      shifter <= (others => '0');
      dv      <= '0';
    elsif rising_edge(clk) then
      dv <= '0';
      if tick_16x = '1' then
        case state is
          when IDLE =>
            if rx_sync1 = '0' then        -- inicio start bit
              state  <= START;
              os_cnt <= (others => '0');
            end if;

          when START =>
            -- muestreo al centro del start (cuando os_cnt = 7)
            if os_cnt = 7 then
              if rx_sync1 = '0' then
                os_cnt  <= (others => '0');
                bit_idx <= (others => '0');
                state   <= DATA;
              else
                state   <= IDLE; -- falso start
              end if;
            else
              os_cnt <= os_cnt + 1;
            end if;

          when DATA =>
            if os_cnt = 15 then
              os_cnt <= (others => '0');
              -- muestreo en el centro del bit
              shifter(to_integer(bit_idx)) <= rx_sync1;
              if bit_idx = 7 then
                state   <= STOP;
              else
                bit_idx <= bit_idx + 1;
              end if;
            else
              os_cnt <= os_cnt + 1;
            end if;

          when STOP =>
            if os_cnt = 15 then
              os_cnt <= (others => '0');
              -- aceptamos el stop sin verificar error de trama
              dv    <= '1';
              state <= IDLE;
            else
              os_cnt <= os_cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;