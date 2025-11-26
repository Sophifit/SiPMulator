//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.01 Education (64-bit) 
//Created Time: 2025-11-10 10:18:53
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
set_input_delay -clock clk 2 [get_ports {rx_i}]
set_output_delay -clock clk 2 [get_ports {tx_o}]