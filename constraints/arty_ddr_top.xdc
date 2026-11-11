## Digilent Arty A7-100T: 100 MHz board oscillator
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports { CLK100MHZ }]

## User LEDs: LED[0] = DDR calibration complete, LED[1] = traffic generator error
set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS33 } [get_ports { LED[0] }]
set_property -dict { PACKAGE_PIN G3 IOSTANDARD LVCMOS33 } [get_ports { LED[1] }]

## DDR3 pins are assigned by the generated MIG constraint file:
## mig_7series_0/user_design/constraints/mig_7series_0.xdc

## Arty A7 configuration-bank voltage settings (CFGBVS warning fix)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
