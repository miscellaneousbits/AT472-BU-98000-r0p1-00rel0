# --------------------------------------------------
# JTAG ports
# --------------------------------------------------

# JTAG connected to PMOD connector JC (nearest to device)
#set_property PULLDOWN true [get_ports swclk]
#set_property PULLUP true [get_ports swio]

set_property IOSTANDARD LVCMOS33 [get_ports swio]

# --------------------------------------------------
# UART
# --------------------------------------------------
set_property IOSTANDARD LVCMOS33 [get_ports usb_uart_*]

# *****************************************************************************
# Timing
# *****************************************************************************

# Master clock frequencies derived from clock wizard


# --------------------------------------------------
# Clocks
# --------------------------------------------------

# Rename main clock for clarity
create_generated_clock -name cpu_clk [get_pins m1_for_arty_s7_i/Clocks_and_Resets/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]
create_generated_clock -name qspi_clk [get_pins m1_for_arty_s7_i/Clocks_and_Resets/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT1]

# --------------------------------------------------
# Input clocks
# --------------------------------------------------
# Support upto 20MHz SWD
create_clock -period 50.000 -name SWCLK [get_ports swclk]

# --------------------------------------------------
# Output clocks
# --------------------------------------------------

# QSPI clocks are set to be divide by 1.  Their frequency is actually divide_by 2, however the QSPI
# device reads and outputs data on the opposite edge to the FPGA.  So for timing purposes the QSPI clock
# appears to be twice as fast, as only half a cycle is available for setup and hold

# Base QSPI
# For S7 board, the CCLK pin is used as the base qspi clock pin.
# See answer record https://www.xilinx.com/support/answers/63174.html
# -combinational option creates a divide_by 1 path through combinational logic
create_generated_clock -name cclk -source [get_pins -hier -regexp m1_for_arty_s7_i/axi_quad_spi_0/.*STARTUP2_7SERIES_inst/USRCCLKO] -combinational [get_pins -hier -regexp m1_for_arty_s7_i/axi_quad_spi_0/.*STARTUP2_7SERIES_inst/USRCCLKO]
set_clock_latency -min 0.500 [get_clocks cclk]
set_clock_latency -max 6.700 [get_clocks cclk]

# --------------------------------------------------
# Virtual clocks
# --------------------------------------------------
create_clock -period 100.000 -name slow_out_clk

# --------------------------------------------------
# Clock groups
# --------------------------------------------------


# Set asynchronous clocks
# Set asynchronous clocks
# Unfortunately this overrides all other timing settings, including the desired set_max_delay.  See forum post
# https://forums.xilinx.com/t5/Timing-Analysis/CDC-Constrains-set-clock-groups-precedes-set-max-delay/td-p/589843
# Therefore better to do set_false_paths where necessary, and set_max_delay where desired.
#set_clock_groups -name async_group -asynchronous -group {cpu_clk} -group {dap_qspi_clk dap_spi_clk cclk} -group {SWCLK} -group {slow_out_clk}

set_max_delay -from [get_clocks cpu_clk] -to [get_clocks -include_generated_clocks qspi_clk] -datapath_only 8.5
set_max_delay -from [get_clocks -include_generated_clocks qspi_clk] -to [get_clocks cpu_clk] -datapath_only 17.0

# cclk is independent of cpu_clk and qspi_clk, due to large offset skews
set_max_delay -from [get_clocks cclk] -to [get_clocks -include_generated_clocks qspi_clk] -datapath_only 8.5
set_max_delay -from [get_clocks -include_generated_clocks qspi_clk] -to [get_clocks cclk] -datapath_only 8.5

set_max_delay -from [get_clocks cclk] -to [get_clocks cpu_clk] -datapath_only 9.5
set_max_delay -from [get_clocks cpu_clk] -to [get_clocks cclk] -datapath_only 9.5

# --------------------------------------------------
# Internal timings
# --------------------------------------------------
# The DAP is asynchronous to the CPU, (SWCLK and cpu_clk).
# However need to ensure that all signals pass across the relevant CDC structures quickly enough
# This should be within 2 cycles of the fastest clock, (cpu_clk).  This is currently 110MHz, ~9ns.
# We only wish to constrain the acutal datapath, we do not need to consider clock skew and jitter
# as these are asychronous clocks
# Set to be less that cpu_clk period for guaranteed transistion times.
set_max_delay -from [get_clocks cpu_clk] -to [get_clocks SWCLK]   -datapath_only 8.0
set_max_delay -from [get_clocks SWCLK]   -to [get_clocks cpu_clk] -datapath_only 8.0


# *****************************************************************************
# IO timings
# *****************************************************************************
# --------------------------------------------------
# Base QSPI
# --------------------------------------------------

# Data is written out on the falling edge of dap_qspi_clk, read by QSPI on rising edge (output delay).
# Data is read out of QSPI on the falling edge, and read by the FPGA on the rising edge (input delay).
# Limiting factor is base QSPI Tco of 7ns.  Add extra 0.5ns for the board


set_input_delay -clock [get_clocks cclk] -max -add_delay 7.500 [get_ports qspi_flash_io?_io]
set_input_delay -clock [get_clocks cclk] -min -add_delay 1.500 [get_ports qspi_flash_io?_io]
set_input_delay -clock [get_clocks cclk] -max -add_delay 7.500 [get_ports qspi_flash_ss*]
set_input_delay -clock [get_clocks cclk] -min -add_delay 1.500 [get_ports qspi_flash_ss*]

set_output_delay -clock [get_clocks cclk] -max -add_delay 2.500 [get_ports qspi_flash_io?_io]
set_output_delay -clock [get_clocks cclk] -min -add_delay -3.500 [get_ports qspi_flash_io?_io]
set_output_delay -clock [get_clocks cclk] -max -add_delay 2.500 [get_ports qspi_flash_ss*]
set_output_delay -clock [get_clocks cclk] -min -add_delay -3.500 [get_ports qspi_flash_ss*]

# --------------------------------------------------
# Debug signals
# --------------------------------------------------

# Large input Tsu, as clock insertion delay is a lot shorter than datapath input delay.


# JTAG
# Note, these are optional ports and may be removed from the build
set_input_delay  -clock [get_clocks SWCLK] -add_delay 5.0 [get_ports swdi]
set_output_delay -clock [get_clocks SWCLK] -add_delay 5.0 [get_ports swdo]
set_output_delay -clock [get_clocks SWCLK] -add_delay 5.0 [get_ports swdoen]

# --------------------------------------------------
# Untimed ports
# --------------------------------------------------
# Following ports have no timing requirement to any output or on-board clock.
# Set to small delays to give timing closure

# Use a virtual slow clock for the untimed IO
# UART
set_input_delay  -clock [get_clocks slow_out_clk] -add_delay 0.5 [get_ports usb_uart_rxd]
set_output_delay -clock [get_clocks slow_out_clk] -add_delay 0.5 [get_ports usb_uart_txd]

# Switch inputs
set_input_delay -clock [get_clocks slow_out_clk] -add_delay 0.500 [get_ports dip_switches*]
set_input_delay -clock [get_clocks slow_out_clk] -add_delay 0.500 [get_ports push_buttons*]

# Reset
set_input_delay -clock [get_clocks cpu_clk] -add_delay 0.500 [get_ports reset*]
# Prevent reset from timing from cpu_clk to qspi_clk
set_false_path -from [get_ports reset*] -to [get_clocks qspi_clk]

# Output LEDs
set_input_delay  -clock [get_clocks slow_out_clk] -add_delay 0.5 [get_ports led_4bits*]
set_input_delay  -clock [get_clocks slow_out_clk] -add_delay 0.5 [get_ports rgb_led*]
set_output_delay -clock [get_clocks slow_out_clk] -add_delay 0.500 [get_ports led_4bits*]
set_output_delay -clock [get_clocks slow_out_clk] -add_delay 0.500 [get_ports rgb_led*]



set_property IOSTANDARD LVCMOS33 [get_ports UART_0_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports UART_0_txd]
set_property PACKAGE_PIN R14 [get_ports {swdo[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {swdo[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports swclk]
set_property IOSTANDARD LVCMOS33 [get_ports swdi]
set_property IOSTANDARD LVCMOS33 [get_ports swdoen]
set_property PACKAGE_PIN T14 [get_ports swdi]
set_property PACKAGE_PIN R16 [get_ports swdoen]
set_property PACKAGE_PIN G16 [get_ports swclk]
set_property PACKAGE_PIN V12 [get_ports UART_0_txd]
set_property PACKAGE_PIN R12 [get_ports UART_0_rxd]

set_property PACKAGE_PIN T14 [get_ports swio]
set_property IOSTANDARD SSTL135 [get_ports {dip_switches_4bits_tri_i[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_switches_4bits_tri_i[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_switches_4bits_tri_i[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {dip_switches_4bits_tri_i[0]}]

set_property INTERNAL_VREF 0.675 [get_iobanks 34]

set_property PULLUP true [get_ports swio]
set_property PULLDOWN true [get_ports swclk]
