--Copyright (C)2014-2022 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.8.10
--Part Number: GW1NR-LV9QN88PC6/I5
--Device: GW1NR-9
--Device Version: C
--Created Time: Sat Feb 04 09:03:33 2023

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_rPLL2
    port (
        clkout: out std_logic;
        clkoutp: out std_logic;
        clkin: in std_logic
    );
end component;

your_instance_name: Gowin_rPLL2
    port map (
        clkout => clkout_o,
        clkoutp => clkoutp_o,
        clkin => clkin_i
    );

----------Copy end-------------------
