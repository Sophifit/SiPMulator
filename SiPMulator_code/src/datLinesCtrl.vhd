------------------------------------------------------------------------
--	datLinesCtrl.vhd  --  PmodDA1 Controller
------------------------------------------------------------------------
-- Author: Luke Renaud 
--	Copyright 2011 Digilent, Inc.
------------------------------------------------------------------------
-- Module description
--		This is the primary controller module for the DA1 component of
--		this example. The module takes in two, double byte words, and
--		transmits them to the PmodDA1 connected to JA when the module
--		comes out of reset. To transmit a new value to the PmodDA1, the
--		module must be put back into and brought out of the reset state.
--
--  Inputs:
--		datClk		Data Clock line
--		wData0		Word for DA #0 channel 1 and 2
--		wData1		Word for DA #1 channel 1 and 2
--		rst			Device Reset Control
--
--  Outputs:
--		SD0			Data out for DA #0
--		SD1			Data out for DA #1
--		SYNC			Select line for the PmodDA1
--		DONE			Done signal for the higher level controller
--
------------------------------------------------------------------------
-- Revision History:
--
--	5/23/2011(Luke Renaud): created
--
------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity pmodDA1_ctrl is
    Port ( datClk		: in	STD_LOGIC;
           SD0			: out	STD_LOGIC;
           SD1			: out	STD_LOGIC;
           wData0		: in	STD_LOGIC_VECTOR (15 downto 0);
           wData1		: in	STD_LOGIC_VECTOR (15 downto 0);
           rst			: in	STD_LOGIC;
		   SYNC		: out	STD_LOGIC;
           DONE		: out	STD_LOGIC);
end pmodDA1_ctrl;

architecture Behavioral of pmodDA1_ctrl is

	------------------------------------------------------------------------
	-- Component Declarations
	------------------------------------------------------------------------

	------------------------------------------------------------------------
	-- General control and timing signals
	------------------------------------------------------------------------
	type stDACCtrl is (stInit, stTx, stDone);
	signal stCur : stDACCtrl := stInit;
	
	signal index : integer := 0;
	
	------------------------------------------------------------------------
	-- Data path signals
	------------------------------------------------------------------------


------------------------------------------------------------------------
-- Implementation
------------------------------------------------------------------------

begin
	-- Output a specific bit of the word passed in from the system
	SD0 <= wData0(index);
	SD1 <= wData1(index);

	process(rst, datClk)
	begin
		-- Reset Condition
		if (rst = '1') then
			DONE <= '0';
			SYNC <= '1';
			index <= 0;
			stCur <= stInit;
		elsif falling_edge(datClk) then
			case stCur is
				when stInit =>
					-- TX the first bit
					DONE <= '0';
					SYNC <= '0'; -- Bring Select line low
					index <= 0; -- And initalize the index
					stCur <= stTx;
				when stTx =>
					-- TX all other bits
					DONE <= '0';
					SYNC <= '0';
					index <= index + 1; -- Rotate the index 
					if (index = 14) then -- Stop when we're at the last bit
					-- We stop at 14 because this if statement is computed in
					-- parallel with the index. So the stDone signal is set
					-- just prior to the index becoming 15.
						stCur <= stDone;
					else
						stCur <= stTx;
					end if;
				when others => -- Finish the system. To TX another byte, reset the module.
					stCur <= stDone;
					DONE <= '1';
					SYNC <= '1';
					index <= 0;
			end case;
		end if;
	end process;


end Behavioral;

