## =====================================================================
## blink.xdc -- pin constraints for the Arty A7-100T (part xc7a100tcsg324-1)
## Copied/trimmed from Digilent's official Arty-A7-100-Master.xdc
## (https://github.com/Digilent/digilent-xdc) -- always prefer pulling the
## master file from that repo and un-commenting only what you use.
## =====================================================================

## 100 MHz onboard clock
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Push-button 0, used here as active-low reset (board buttons are active-HIGH,
## so we invert in this note: wire rst_n = ~btn0 at the top level, OR just
## treat BTN0 as active-high "reset pressed" and flip the polarity in blink.sv.
## Simplest for week 1: rename the port rst_n -> rst and use `if (rst)` instead
## of `if (!rst_n)` in blink.sv, and drop the inversion entirely.
set_property -dict { PACKAGE_PIN D9   IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## LED0 (green, one of the 4 individual LEDs LD4-LD7 on the board)
set_property -dict { PACKAGE_PIN H5   IOSTANDARD LVCMOS33 } [get_ports { led0 }];
