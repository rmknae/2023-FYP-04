## Pin constraints for who_am_i_top on the Arty A7-100T
## Cross-check every pin against the official Digilent Arty-A7-100-Master.xdc
## (https://github.com/Digilent/digilent-xdc) before building -- pin numbers
## below are correct for the board's revision as of the project guide, but
## always verify against the current master file.

set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

set_property -dict { PACKAGE_PIN C9  IOSTANDARD LVCMOS33 } [get_ports { rst_n }];
set_property -dict { PACKAGE_PIN D9  IOSTANDARD LVCMOS33 } [get_ports { btn0 }];
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports { uart_txd }];

## Pmod JA pins 1 and 2 used here for SDA/SCL -- pick any free Pmod pair and
## remember to add EXTERNAL 4.7k pull-up resistors to 3.3V on both lines;
## the FPGA's internal pull-ups are not reliable enough for I2C.
set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 } [get_ports { sda }];
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports { scl }];
