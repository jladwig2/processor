## =============================================================================
## File:        constrs/basys3.xdc
## Project:     processor-complex
## Target:      Digilent Basys 3 (Xilinx Artix-7 XC7A35T-1CPG236C)
## Milestone:   M0 (Infrastructure & Peripherals)
##
## Description:
##   Physical pin assignments, I/O standards (LVCMOS33), and primary clock
##   constraints for `top_basys3.sv` (`rtl/top/top_basys3.sv`).
##
##   Every port name in this file matches the top-level port list of
##   `top_basys3` 1-for-1:
##     - `clk`           : 100 MHz CMOS oscillator (Pin W5)
##     - `btnC`          : Dedicated active-high system reset (Pin U18)
##     - `btnU/L/R/D`    : 4 directional GPIO pushbuttons
##     - `sw[15:0]`      : 16 slide switches (`sw[15]` = boot mode select)
##     - `led[15:0]`     : 16 discrete green LEDs
##     - `seg[6:0]`, `dp`: Active-low 7-segment cathodes
##     - `an[3:0]`       : Active-low 7-segment digit anodes
##     - `RsRx`, `RsTx`  : FT2232H USB-UART bridge
##     - `QspiCSn`, `QspiDB[3:0]` : Spansion S25FL032P 4 MB Quad-SPI Flash
##     - `PS2Clk`, `PS2Data`      : PIC24 USB-HID host PS/2 interface
## =============================================================================

## -----------------------------------------------------------------------------
## 1. System Clock (100 MHz Onboard Oscillator)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## -----------------------------------------------------------------------------
## 2. Slide Switches (sw[15:0] -> GPIO.SW[15:0]; sw[15] = Boot Mode Select)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {sw[6]}]
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports {sw[7]}]
set_property -dict { PACKAGE_PIN V2   IOSTANDARD LVCMOS33 } [get_ports {sw[8]}]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports {sw[9]}]
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports {sw[10]}]
set_property -dict { PACKAGE_PIN R3   IOSTANDARD LVCMOS33 } [get_ports {sw[11]}]
set_property -dict { PACKAGE_PIN W2   IOSTANDARD LVCMOS33 } [get_ports {sw[12]}]
set_property -dict { PACKAGE_PIN U1   IOSTANDARD LVCMOS33 } [get_ports {sw[13]}]
set_property -dict { PACKAGE_PIN T1   IOSTANDARD LVCMOS33 } [get_ports {sw[14]}]
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports {sw[15]}]

## -----------------------------------------------------------------------------
## 3. Discrete LEDs (led[15:0] <- GPIO.LED[15:0])
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## -----------------------------------------------------------------------------
## 4. 4-Digit 7-Segment Display (Active-Low Cathodes seg[6:0], dp, Anodes an[3:0])
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN W6   IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN U5   IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN V5   IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN U7   IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]
set_property -dict { PACKAGE_PIN V7   IOSTANDARD LVCMOS33 } [get_ports dp]

set_property -dict { PACKAGE_PIN U2   IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN U4   IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN V4   IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN W4   IOSTANDARD LVCMOS33 } [get_ports {an[3]}]

## -----------------------------------------------------------------------------
## 5. Pushbuttons (btnC = Dedicated Reset; btnU/L/R/D = GPIO.BTN[3:0])
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports btnC]
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports btnU]
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports btnL]
set_property -dict { PACKAGE_PIN T17  IOSTANDARD LVCMOS33 } [get_ports btnR]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btnD]

## -----------------------------------------------------------------------------
## 6. USB-RS232 Interface (FT2232H Bridge)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports RsRx]
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports RsTx]

## -----------------------------------------------------------------------------
## 7. USB-HID Host (PIC24 PS/2 Keyboard/Mouse Emulation)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN C17  IOSTANDARD LVCMOS33 PULLUP true } [get_ports PS2Clk]
set_property -dict { PACKAGE_PIN B17  IOSTANDARD LVCMOS33 PULLUP true } [get_ports PS2Data]

## -----------------------------------------------------------------------------
## 8. Quad-SPI Flash (Spansion S25FL032P; SCK driven via STARTUPE2.USRCCLKO)
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN D18  IOSTANDARD LVCMOS33 } [get_ports {QspiDB[0]}]
set_property -dict { PACKAGE_PIN D19  IOSTANDARD LVCMOS33 } [get_ports {QspiDB[1]}]
set_property -dict { PACKAGE_PIN G18  IOSTANDARD LVCMOS33 } [get_ports {QspiDB[2]}]
set_property -dict { PACKAGE_PIN F18  IOSTANDARD LVCMOS33 } [get_ports {QspiDB[3]}]
set_property -dict { PACKAGE_PIN K19  IOSTANDARD LVCMOS33 } [get_ports QspiCSn]

## -----------------------------------------------------------------------------
## 9. Configuration & Bitstream Settings
## -----------------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

