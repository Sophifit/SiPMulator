--Copyright (C)2014-2025 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.11.01 Education (64-bit)
--Part Number: GW2AR-LV18QN88C8/I7
--Device: GW2AR-18
--Device Version: C
--Created Time: Mon Nov 10 10:18:26 2025

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component sys_clk100
    port (
        clkout: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: sys_clk100
    port map (
        clkout => clkout,
        clkin => clkin
    );

----------Copy end-------------------
