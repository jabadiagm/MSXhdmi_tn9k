//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.10 
//Created Time: 2023-02-04 18:43:51
create_clock -name clock_27m -period 37.037 -waveform {0 18.518} [get_ports {ex_clk_27m}]
create_generated_clock -name clock_100m -source [get_ports {ex_clk_27m}] -master_clock clock_27m -divide_by 7 -multiply_by 26 [get_nets {clk_100m}]
create_generated_clock -name clock_50m -source [get_nets {clk_100m}] -master_clock clock_100m -divide_by 2 [get_nets {clk_50m}]
create_generated_clock -name clock_25m -source [get_nets {clk_100m}] -master_clock clock_100m -divide_by 4 -phase 180 [get_nets {clk_25m}]
create_generated_clock -name clock_126m -source [get_nets {clk_25m}] -master_clock clock_25m -multiply_by 5 [get_nets {clk_126m}]

//set_false_path -from [get_clocks {clock_cpu}] -to [get_clocks {clock_100m}] 