# -----------------------------------------------------------------------------
# build_bram.tcl -- Task 2 / Task 3: BRAM test design (top = bram_top)
#
# Creates build/bram_proj/bram_proj.xpr (with the testbenches in sim_1 so the
# waveform can be opened from the GUI), runs synthesis, implementation and
# bitstream, writes the reports and the post-implementation functional
# netlist used for the Task 3 SAIF simulations.
#
#   vivado -mode batch -source scripts/build_bram.tcl    (from "Lab7 assignment")
# -----------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set part xc7a100tcsg324-1
set proj_dir $root/build/bram_proj
file mkdir reports/task2 bitstreams build/netlist

create_project bram_proj $proj_dir -part $part -force
set_property target_language Verilog [current_project]

add_files -norecurse [list \
    rtl/bram_top.v rtl/bram.v rtl/ddr_ctrl.v rtl/lfsr.v \
    rtl/board_status.v rtl/seg7_hex.v \
    mem/bram32_init.mem mem/bram16_init.mem]
add_files -fileset constrs_1 -norecurse constraints/bram_top.xdc
set_property top bram_top [current_fileset]

add_files -fileset sim_1 -norecurse [list sim/tb_bram.v sim/tb_bram_top.v]
set_property top tb_bram [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

launch_runs synth_1 -jobs 6
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} { error "synth_1 failed" }

launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} { error "impl_1 failed" }

open_run impl_1
report_utilization                 -file reports/task2/bram_top_utilization.rpt
report_utilization -hierarchical   -file reports/task2/bram_top_utilization_hier.rpt
report_ram_utilization             -file reports/task2/bram_top_ram_utilization.rpt
report_timing_summary -max_paths 10 -file reports/task2/bram_top_timing_summary.rpt
report_power                       -file reports/task2/bram_top_power_default.rpt
write_checkpoint -force            $root/build/bram_top_routed.dcp
write_verilog -force -mode funcsim $root/build/netlist/bram_top_funcsim.v

file copy -force [get_property DIRECTORY [get_runs impl_1]]/bram_top.bit bitstreams/bram_top.bit
puts "DONE: bitstreams/bram_top.bit, reports in reports/task2"
