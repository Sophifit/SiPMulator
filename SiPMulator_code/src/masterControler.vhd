------------------------------------------------------------------------
--	masterController.vhd  --  Overall Project Controller Module
------------------------------------------------------------------------
-- Author: Luke Renaud 
--	Copyright 2011 Digilent, Inc.
------------------------------------------------------------------------
-- Module description
--		This module manages the full I/O of the system. The 100MHz clock
--		is fed through two clock dividers to produce a 100KHz signal and
--		a 100Hz signal. The 100KHz signal is used to interface with two
--		Pmod's to send out an arbitrary number, convert it to an analog
--		value, then to convert it back into a digital number.
--		
--		The 100Hz clock is used to drive the counter that controls what number
--		should currently be stored in the DA1, and the target value that
--		the AD2 is trying to read.
--
--		Chipscope may then be used to read the state of the board. The lower
--		12 bits of the wRetSignal0 will contain the ADC value, this will be
--		shown in comparision to the 8-bits sent to the DAC.
--	
--		To compare the values graphically, select signals 0 through 11 in the
--		Signals pane, right click, and select copy to new bus. Then select
--		signals 4 through 11 and select move to new bus. Finally select signals
--		12 through 19 and select move to new bus. This should result in three
--		busses which can be ploted in the Bus Plot section of ChipScope for
--		comparision.

------------------------------------------------------------------------
-- Revision History:
--
--	05/20/2011(Luke Renaud): created
--	06/01/2011(Luke Renaud): Modified for PmodAD2
--
--   08/20/2025 adapted for SiPMUlator project by Sophia Pinzon and Javier Castaño Universidad Antonio Nariño

------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.data_package.all;


entity masterControler is
    Port ( RESET		: in		STD_LOGIC;
           rx_i	: in		STD_LOGIC;
           tx_o	: out		STD_LOGIC;
           clk	: in		STD_LOGIC; --input crystal Tang Nano 27 MHz
           DA1_SYNC	: out		STD_LOGIC;
           DA1_SCLK	: out		STD_LOGIC;
           DA1_SD0	: out		STD_LOGIC;
           DA1_SD1	: out		STD_LOGIC;
           led_recv  : out std_logic;  
           led_echo  : out std_logic   
			  );
end masterControler;

architecture Behavioral of masterControler is

	------------------------------------------------------------------------
	-- Component Declarations
	------------------------------------------------------------------------


component sys_clk100
    port (
        clkout: out std_logic;
        clkin: in std_logic
    );
end component;

component top_uart_echo32 is
  generic (
    CLK_FREQ_HZ : integer := 27000000;
    BAUD        : integer := 115200
  );
  port (
    clk   : in  std_logic;
    rx_i      : in  std_logic;  -- UART RX 
    tx_o      : out std_logic;  -- UART TX
    sel : out STD_LOGIC_VECTOR(2 downto 0);
    bytes_out: out s_vector;
   -- Optional: Debug pins/LEDs
    led_recv  : out std_logic;  
    led_echo  : out std_logic   
  );
end component;

component lfsr_ms_timer is
  generic (
    LFSR_WIDTH : positive := 16;                
    MS_MAX     : natural  := 1000               
  );
  port (
    clk      : in  std_logic;                 
    rst_n      : in  std_logic;                 
    enable     : in  std_logic;                
    seed_load  : in  std_logic;                 
    seed_in    : in  std_logic_vector(LFSR_WIDTH-1 downto 0);
    out_toggle : out std_logic                 
  );
end component;


	component txFrameDriver_safe is
  generic (
    RST_HOLD : natural := 2  -- number of datClk cycles to hold reset high
  );
  port (
    datClk  : in  STD_LOGIC;  -- same clock that goes to the DAC shifter
    ext_rst : in  STD_LOGIC;  -- external reset (active high)
    done    : in  STD_LOGIC;  -- DONE from datLinesCtrl (1 = last frame finished)
    rst_out : out STD_LOGIC   -- to datLinesCtrl.rst (active high)
  );
end component;

	
component txResetOneShot is
    generic (
        PULSE_CYCLES : natural := 1024  -- length of reset pulse in clk cycles
    );
    port (
        clk      : in  STD_LOGIC;  -- system clock 
        ext_rst  : in  STD_LOGIC;  -- external async reset 
        rst_out  : out STD_LOGIC   -- synchronous reset pulse 
    );
end component;

component pulseLUT_sync is
    generic (
        N : natural := 32 
    );
    Port (
         clk    : in  STD_LOGIC;  
        rst    : in  STD_LOGIC;
        sel_lfsr: in  STD_LOGIC;
        sel : in std_logic_vector(2 downto 0);
        done   : in  STD_LOGIC; 
        bytes_in : in s_vector;
        outNum : out STD_LOGIC_VECTOR(7 downto 0)
    );
end component;


	component clkDivMain is
		Port (	clkSys100MHz	: in	STD_LOGIC;
					clkOut100KHz	: out	STD_LOGIC;
					rst				: in	STD_LOGIC);
	end component;

	component clkDivSecondary is
		Port (	clkInt100KHz	: in	STD_LOGIC;
					clkOut100Hz		: out	STD_LOGIC;
					early100Hz		: out STD_LOGIC;
					rst				: in	STD_LOGIC);
	end component;

	component pmodDA1_ctrl is
		Port (	datClk		: in	STD_LOGIC;
					SD0			: out	STD_LOGIC;
					SD1			: out	STD_LOGIC;
					wData0		: in	STD_LOGIC_VECTOR (15 downto 0);
					wData1		: in	STD_LOGIC_VECTOR (15 downto 0);
					rst			: in	STD_LOGIC;
					SYNC			: out	STD_LOGIC;
					DONE			: out	STD_LOGIC);
	end component;

	------------------------------------------------------------------------
	-- General control and timing signals
	------------------------------------------------------------------------
	signal clockInternal : STD_LOGIC;
	signal clockTrigger : STD_LOGIC;
	signal chipscopeSample : STD_LOGIC;
	signal fTxDone : STD_LOGIC;
	signal fRxDone : STD_LOGIC;
	signal fRstTXCtrl : STD_LOGIC;
	signal fRstRXCtrl : STD_LOGIC;
    signal SYS_CLK : STD_LOGIC;
 
	------------------------------------------------------------------------
	signal wValue, wvalue_n : STD_LOGIC_VECTOR(7 downto 0);
	signal wValueReverse : STD_LOGIC_VECTOR(7 downto 0);
    signal wValue_n_Reverse : STD_LOGIC_VECTOR(7 downto 0);
	signal wOutSignal0 : STD_LOGIC_VECTOR(15 downto 0);
	signal wOutSignal1 : STD_LOGIC_VECTOR(15 downto 0);
	signal wRetSignal0 : STD_LOGIC_VECTOR(15 downto 0);

	signal SDA_ctrl : STD_LOGIC;
	signal SCL_ctrl : STD_LOGIC;

	
	signal rst_tx : STD_LOGIC;
   signal por_rst : STD_LOGIC;  

signal lfsr_seed    : std_logic_vector(15 downto 0) := x"ACE1"; -- seed ≠ 0
signal lfsr_seed_ld : std_logic := '0';                         -- optional charging pulse
signal lfsr_toggle  : std_logic;                                
signal lfsr_enable  : std_logic := '1';                        -- permanent enabled
signal sels : std_logic_vector(2 downto 0);

signal bytes_in, bytes_out: s_vector;
------------------------------------------------------------------------
-- Implementation
------------------------------------------------------------------------
begin

clk_gen: sys_clk100
    port map (
        clkout => SYS_CLK,
        clkin => clk
    );


uart_echo32_gen : top_uart_echo32
  generic map (
    CLK_FREQ_HZ => 27000000,
    BAUD        => 115200
  )
  port map (
    clk      => clk,          
    rx_i     => rx_i,     
    tx_o     => tx_o,     
    led_recv => led_recv,   
    led_echo => led_echo,    
    bytes_out => bytes_out,
    sel => sels
  );

u_lfsr_ms_timer : lfsr_ms_timer
  generic map (
    LFSR_WIDTH => 16,     
    MS_MAX     => 1000  
  )
  port map (
    clk      => SYS_CLK,          -- clock 100 MHz
    rst_n      => not RESET,       
    enable     => lfsr_enable,    -- '1' to always run
    seed_load  => lfsr_seed_ld,   -- set a seed reload cycle to '1'
    seed_in    => lfsr_seed,      -- entry seed
    out_toggle => lfsr_toggle     
  );


u_por: txResetOneShot
  generic map ( PULSE_CYCLES => 2048 ) 
  port map (
    clk     => SYS_CLK,
    ext_rst => RESET,
    rst_out => por_rst
  );



valueCounter: pulseLUT_sync
  generic map ( N => 32 )        
  port map (
    clk    => SYS_CLK,           -- 100 MHz
    rst    => RESET,
    sel_lfsr    => lfsr_toggle,
    sel       => sels,
    bytes_in => bytes_out,
    done   => fTxDone,           
    outNum => wValue
  );
-- Divide from 100MHz to 100KHz
mainDivider: clkDivMain PORT MAP(
			clkSys100MHz =>	SYS_CLK,
			clkOut100KHz =>	clockInternal,
			rst =>				RESET);

		
-- When the 100Hz signal goes low, output the current
-- counter value to the PmodDA1 module
digitalController: pmodDA1_ctrl PORT MAP(
			datClk =>	clockInternal,
			SD0 =>		DA1_SD0,
			SD1 =>		DA1_SD1,
			wData0 =>	wOutSignal0,
			wData1 =>	wOutSignal1,
			rst =>		fRstTXCtrl,
			SYNC =>		DA1_SYNC,
			DONE =>		fTxDone);
	 
			-- Divide from 100KHz to 100Hz
secondDivider: clkDivSecondary PORT MAP(
			clkInt100KHz =>	clockInternal,
			clkOut100Hz =>		clockTrigger,
			early100Hz =>		chipscopeSample,
			rst =>				RESET);
			
u_txdrv: txFrameDriver_safe
  generic map ( RST_HOLD => 2 )  -- 2 datClk cycles with high reset between frames
  port map (
    datClk  => clockInternal,    
    ext_rst => RESET,            
    done    => fTxDone,         
    rst_out => rst_tx
  );
  
			
-- This flag controls the reset on the DA1 controller. It is only
-- going to transmit after comming out of a reset state, so we cause
-- it's reset signal to be controlled by either the system reset signal
-- or by the high state of the 100Hz clock.
--fRstTXCtrl <= RESET or clockTrigger;
--fRstRXCtrl <= RESET or not clockTrigger;

--fRstTXCtrl <= RESET;
fRstRXCtrl <= rst_tx;

fRstTXCtrl <= rst_tx;


wValueReverse(7 downto 0) <= wValue(0) & wValue(1) & wValue(2) & wValue(3) & wValue(4) & wValue(5) & wValue(6) & wValue(7);
wValue_n_Reverse(7 downto 0) <= wValue_n(0) & wValue_n(1) & wValue_n(2) & wValue_n(3) & wValue_n(4) & wValue_n(5) & wValue_n(6) & wValue_n(7);
wvalue_n <= 256 - wvalue;
-- Set the output value of the first channel of the DAC.
wOutSignal0(15 downto 0) <= wValueReverse(7 downto 0) & "00000000";

-- And set the other two channels to zero, we don't really need two channels.
wOutSignal1(15 downto 0) <= wValue_n_Reverse(7 downto 0) & "00000000";

-- Set the data clock we're using to be the 100KHz clock that we're using internally.
DA1_SCLK <= clockInternal;

end Behavioral;

