# -----------------------------------------------------------------------------
# build_ddr.tcl -- Task 1 / Task 3: DDR2 test design (top = ddr_top)
#
# Creates the Vivado project build/ddr_proj/ddr_proj.xpr with
#   * Clocking Wizard clk_wiz_0: 100 MHz in, 200 MHz + 100 MHz out, reset
#     active high, locked enabled
#   * MIG 7 Series "ddr" from ip/mig.prj (tutorial settings, see README)
# runs synthesis, implementation and bitstream, and writes the reports.
#
#   vivado -mode batch -source scripts/build_ddr.tcl     (from "Lab7 assignment")
# -----------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set part xc7a100tcsg324-1
set proj_dir $root/build/ddr_proj
file mkdir reports/task1 bitstreams

create_project ddr_proj $proj_dir -part $part -force
set_property target_language Verilog [current_project]

add_files -norecurse [list \
    rtl/ram2ddr_fixed.vhd rtl/ddr_top.v rtl/ddr_ctrl.v rtl/lfsr.v \
    rtl/board_status.v rtl/seg7_hex.v]
add_files -fileset constrs_1 -norecurse constraints/ddr_top.xdc
set_property top ddr_top [current_fileset]

# ---------------------------------------------------------------- Clocking Wizard
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ               {100.000} \
    CONFIG.CLKOUT2_USED               {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.RESET_TYPE                 {ACTIVE_HIGH} \
    CONFIG.USE_LOCKED                 {true} \
    CONFIG.USE_RESET                  {true}] [get_ips clk_wiz_0]

# ---------------------------------------------------------------- MIG
create_ip -name mig_7series -vendor xilinx.com -library ip -module_name ddr
set ip_dir [get_property IP_DIR [get_ips ddr]]
file copy -force $root/ip/mig.prj $ip_dir/mig_a.prj
set_property -dict [list \
    CONFIG.XML_INPUT_FILE        {mig_a.prj} \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.MIG_DONT_TOUCH_PARAM  {Custom} \
    CONFIG.BOARD_MIG_PARAM       {Custom}] [get_ips ddr]

generate_target all [get_ips]
create_ip_run [get_ips]

# ---------------------------------------------------------------- runs
launch_runs synth_1 -jobs 6
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} { error "synth_1 failed" }

launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} { error "impl_1 failed" }

open_run impl_1
report_utilization                 -file reports/task1/ddr_top_utilization.rpt
report_utilization -hierarchical   -file reports/task1/ddr_top_utilization_hier.rpt
report_timing_summary -max_paths 10 -file reports/task1/ddr_top_timing_summary.rpt
report_clocks                      -file reports/task1/ddr_top_clocks.rpt
report_power                       -file reports/task1/ddr_top_power_default.rpt
write_checkpoint -force            $root/build/ddr_top_routed.dcp

# MIG alone: out-of-context synthesis of the IP + its share of the routed design
set mig_run [get_runs ddr_synth_1]
open_run $mig_run -name mig_ooc
report_utilization -file reports/task1/mig_ooc_synth_utilization.rpt
close_design

file copy -force [get_property DIRECTORY [get_runs impl_1]]/ddr_top.bit bitstreams/ddr_top.bit
puts "DONE: bitstreams/ddr_top.bit, reports in reports/task1"
