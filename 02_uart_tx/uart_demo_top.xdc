## Pin constraints for uart_demo_top on the Arty A7-100T

set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## BTN1 used as reset (active-high; rst_n is active-low in the code, so
## either invert at the top level or swap the polarity check in your RTL --
## for week 1 simplest fix: change `if (!rst_n)` to `if (rst_n)` everywhere
## and rename the port to `rst`.)
set_property -dict { PACKAGE_PIN C9  IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## BTN0
set_property -dict { PACKAGE_PIN D9  IOSTANDARD LVCMOS33 } [get_ports { btn0 }];

## USB-UART bridge TXD line (FPGA transmits -> USB chip receives)
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports { uart_txd }];
