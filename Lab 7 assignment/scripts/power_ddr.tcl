# -----------------------------------------------------------------------------
# power_ddr.tcl -- Task 3, DDR2: report_power of the implemented ddr_top with
# per-pattern switching activity set by set_switching_activity (simulating the
# MIG through calibration is too slow for a SAIF run).
#
#   vivado -mode batch -source scripts/power_ddr.tcl -tclargs [T_WR T_RD]
#
# T_WR / T_RD = 100 MHz cycles per write / read access. Defaults are the
# estimates from the wrapper's handshake (see README, Task 3); after the board
# run use the measured values:  T = (write or read pass cycles) / 2^26.
#
# How the toggle rates follow from the controller (p = probability that a data
# bit changes from one word to the next: 0 for all-zeros / all-ones, 1 for
# 0000/FFFF and 5555/AAAA alternating, 0.5 for LFSR):
#   write  user bus mem_d (100 MHz)      : one new word per access -> 100*p/T_WR %
#          MIG app_wdf_data (ui_clk 150) : one new word per access -> 100*p/(1.5*T_WR) %
#          ddr2_dq pins (300 MHz)        : ram2ddr replicates the word over all
#                                          8 beats of the BL8 burst, so the pins
#                                          only change between bursts -> 100*p/(3*T_WR) %
#   read   ddr2_dq pins                  : every access returns the whole burst of
#                                          8 consecutive words -> 8*p transitions
#                                          per access -> 100*8p/(3*T_RD) %
#          ram_dq_o (ui_clk)             : one selected word per access -> 100*p/(1.5*T_RD) %
#          app_rd_data lanes (ui_clk)    : lane j sees word j and j+4 (same parity),
#                                          so only the LFSR pattern toggles them
# Static probability: 0 (zeros), 1 (ones), 0.5 (all others).
# DQ output enable (IOBUF T = 1 means input / high-Z): writes drive the bus for
# ~5 of the 3*T_WR memory clocks of an access, reads never drive it.
# -----------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
file mkdir reports/task3

set T_WR [expr {[llength $argv] >= 1 ? double([lindex $argv 0]) : 15.0}]
set T_RD [expr {[llength $argv] >= 2 ? double([lindex $argv 1]) : 30.0}]
puts "DDR power: T_WR = $T_WR, T_RD = $T_RD cycles per access"

open_checkpoint build/ddr_top_routed.dcp
set_units -power mW

# ---------------------------------------------------------------- nets
proc nets_of_pins {pattern} {
    set p [get_pins -quiet $pattern]
    if {[llength $p] == 0} { puts "WARNING: no pins match $pattern"; return {} }
    return [get_nets -quiet -of $p]
}
set n_user_wr  [nets_of_pins u_ram/ram_dq_i[*]]
set n_user_rd  [nets_of_pins u_ram/ram_dq_o[*]]
set n_app_wr   [nets_of_pins u_ram/Inst_DDR/app_wdf_data[*]]
set n_app_rd   [nets_of_pins u_ram/Inst_DDR/app_rd_data[*]]
set p_dq       [get_ports ddr2_dq[*]]
set dq_bufs    [get_cells -quiet -of [get_nets -of $p_dq] -filter {REF_NAME =~ IOBUF*}]
set n_dq_t     [get_nets -quiet -of [get_pins -quiet -of $dq_bufs -filter {REF_PIN_NAME == T}]]
puts "nets: user_wr [llength $n_user_wr] user_rd [llength $n_user_rd] app_wr [llength $n_app_wr] app_rd [llength $n_app_rd] dq_ports [llength $p_dq] dq_bufs [llength $dq_bufs] dq_T [llength $n_dq_t]"

proc act {objs tr sp} {
    if {[llength $objs]} { set_switching_activity -toggle_rate $tr -static_probability $sp $objs }
}

# switch settings of each case on the SW ports (mode = SW[4:3], pattern = SW[2:0])
proc set_switches {mode pat} {
    set sw [expr {($mode << 3) | $pat}]
    for {set i 0} {$i < 8} {incr i} {
        set_switching_activity -toggle_rate 0 -static_probability [expr {($sw >> $i) & 1}] [get_ports SW[$i]]
    }
}

# pattern name -> {SW code, p (toggle probability per word), static probability}
set patterns {
    zeros    {1 0.0 0.0}
    ones     {2 0.0 1.0}
    alt01    {3 1.0 0.5}
    5555aaaa {4 1.0 0.5}
    lfsr     {5 0.5 0.5}
}

proc apply_case {op code p sp} {
    global T_WR T_RD n_user_wr n_user_rd n_app_wr n_app_rd p_dq n_dq_t
    reset_switching_activity -all
    if {$op eq "write"} {
        set_switches 1 $code
        act $n_user_wr [expr {100.0 * $p / $T_WR}]         $sp
        act $n_app_wr  [expr {100.0 * $p / (1.5 * $T_WR)}] $sp
        act $p_dq      [expr {100.0 * $p / (3.0 * $T_WR)}] $sp
        act $n_user_rd 0 0
        act $n_app_rd  0 0
        act $n_dq_t    [expr {200.0 / (3.0 * $T_WR)}] [expr {1.0 - 5.0 / (3.0 * $T_WR)}]
    } else {
        set_switches 2 $code
        act $n_user_wr 0 $sp
        act $n_app_wr  0 $sp
        act $p_dq      [expr {100.0 * 8.0 * $p / (3.0 * $T_RD)}] $sp
        act $n_user_rd [expr {100.0 * $p / (1.5 * $T_RD)}] $sp
        act $n_app_rd  [expr {($p == 0.5 ? 100.0 : 0.0) / (1.5 * $T_RD)}] $sp
        act $n_dq_t    0 1
    }
}

# ---------------------------------------------------------------- per-pattern cases
foreach op {write read} {
    foreach {name spec} $patterns {
        lassign $spec code p sp
        apply_case $op $code $p $sp
        report_power -file reports/task3/power_ddr_${op}_${name}.rpt
        puts "power: ddr $op $name done"
    }
}

# ---------------------------------------------------------------- toggle-rate sweep
# data pins and user / MIG data buses forced to a toggle rate, SP 0.5
foreach op {write read} {
    foreach tr {0 25 50 100} {
        apply_case $op 5 0.5 0.5
        if {$op eq "write"} {
            act $n_user_wr $tr 0.5
            act $n_app_wr  $tr 0.5
        } else {
            act $n_user_rd $tr 0.5
            act $n_app_rd  $tr 0.5
        }
        act $p_dq $tr 0.5
        report_power -file reports/task3/power_ddr_${op}_toggle${tr}.rpt
        puts "power: ddr $op toggle $tr % done"
    }
}

set f [open reports/task3/ddr_power_settings.txt w]
puts $f "T_WR=$T_WR"
puts $f "T_RD=$T_RD"
close $f
puts "DONE: reports/task3/power_ddr_*.rpt"
