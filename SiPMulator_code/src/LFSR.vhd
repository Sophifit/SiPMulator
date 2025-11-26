library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lfsr_ms_timer is
  generic (
    LFSR_WIDTH : positive := 16;              
    MS_MAX     : natural  := 1000               
  );
  port (
    clk      : in  std_logic;                 -- 50 MHz
    rst_n      : in  std_logic;                 -- reset active in '0'
    enable     : in  std_logic;                 
    seed_load  : in  std_logic;                 
    seed_in    : in  std_logic_vector(LFSR_WIDTH-1 downto 0);
    out_toggle : out std_logic                 
  );
end entity;

architecture rtl of lfsr_ms_timer is
  constant DIV_1MS : natural := 50000;

  signal div_cnt    : unsigned(15 downto 0) := (others=>'0');
  signal tick_1ms   : std_logic := '0';

  -- LFSR 
  signal lfsr_q     : std_logic_vector(LFSR_WIDTH-1 downto 0) := (others=>'1');

  signal ms_cnt     : unsigned(15 downto 0) := (others=>'0');
  signal ms_reload  : unsigned(15 downto 0) := to_unsigned(10,16); 
  signal o_tgl      : std_logic := '0';

  -- Feedback 
  function lfsr_fb(v : std_logic_vector) return std_logic is
    variable f : std_logic := '0';
  begin
    
    if v'length = 16 then
      f := v(15) xor v(13) xor v(12) xor v(10);
    else
      f := v(v'high) xor v(1) xor v(2);
    end if;
    return f;
  end function;

begin
  -- Divisor to 1 ms
  process(clk, rst_n)
  begin
    if rst_n='0' then
      div_cnt  <= (others=>'0');
      tick_1ms <= '0';
    elsif rising_edge(clk) then
      if enable='1' then
        if div_cnt = to_unsigned(DIV_1MS-1, div_cnt'length) then
          div_cnt  <= (others=>'0');
          tick_1ms <= '1';
        else
          div_cnt  <= div_cnt + 1;
          tick_1ms <= '0';
        end if;
      else
        tick_1ms <= '0';
      end if;
    end if;
  end process;

-- LFSR with seed charge; avoids zero state
  process(clk, rst_n)
    variable next_bit : std_logic;
    variable next_vec : std_logic_vector(LFSR_WIDTH-1 downto 0);
  begin
    if rst_n='0' then
      lfsr_q <= (others=>'1');
    elsif rising_edge(clk) then
      if seed_load='1' then
        if seed_in = (seed_in'range => '0') then
          lfsr_q <= (others=>'1');                     
        else
          lfsr_q <= seed_in;
        end if;
      elsif tick_1ms='1' and enable='1' then
        next_bit := lfsr_fb(lfsr_q);
        next_vec := lfsr_q(lfsr_q'left-1 downto 0) & next_bit;
        if next_vec = (next_vec'range => '0') then
          lfsr_q <= (others=>'1');                     
        else
          lfsr_q <= next_vec;
        end if;
      end if;
    end if;
  end process;

  -- Map LFSR to reload in ms within range
  process(lfsr_q)
    variable raw : unsigned(15 downto 0);
  begin
    raw := resize(unsigned(lfsr_q), 16);
    if MS_MAX = 0 then
      ms_reload <= to_unsigned(1,16);
    else
      ms_reload <= to_unsigned(1,16) + (raw mod to_unsigned(MS_MAX,16));
    end if;
  end process;

 -- Timer in ms and switching to “overflow
  process(clk, rst_n)
  begin
    if rst_n='0' then
      ms_cnt  <= to_unsigned(10,16);
      o_tgl   <= '0';
    elsif rising_edge(clk) then
      if enable='1' and tick_1ms='1' then
        if ms_cnt = 0 then
          ms_cnt <= ms_reload;       -- “overflow” and recharge
          o_tgl  <= '0';       
        else
          ms_cnt <= ms_cnt - 1;
          o_tgl<= '1';  
        end if;
      end if;
    end if;
  end process;

  out_toggle <= o_tgl;
end architecture;
