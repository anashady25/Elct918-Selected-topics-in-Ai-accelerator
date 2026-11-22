# -----------------------------------------------------------------------------
# sweep_pe.tcl -- Task 4.2: maximum number of PEs on the xc7a100t at 100 MHz
#
#   vivado -mode batch -source scripts/sweep_pe.tcl -tclargs <variant> <spad> [N ...]
#     variant : dsp  (multipliers in DSP48E1)  |  lut  (use_dsp = "no")
#     spad    : 0    (no scratchpad)           |  1    (private 1Ki x 16 BRAM per PE)
#     N ...   : optional explicit list of N_PE values; without it N_PE doubles
#               (1, 2, 4, ...) until implementation fails or WNS < 0, and the
#               limit is then refined by bisection.
#
# Every point: synth, opt, place, route, then report_utilization,
# report_timing_summary and report_power into reports/task4/pe/, plus a
# one-line summary file used by scripts/collect_results.py.
# -----------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
set part xc7a100tcsg324-1
set variant [lindex $argv 0]
set spad    [lindex $argv 1]
set explicit [lrange $argv 2 end]
if {$variant ni {dsp lut} || $spad ni {0 1}} {
    error "usage: -tclargs dsp|lut 0|1 \[N ...\]"
}
set use_dsp [expr {$variant eq "dsp" ? 1 : 0}]
exec python $root/scripts/gen_pe_variants.py
set rpt_dir $root/reports/task4/pe
file mkdir $rpt_dir

proc util_value {rpt key} {
    foreach line [split $rpt "\n"] {
        if {[regexp "^\\|\\s*${key}\\s*\\|\\s*(\[0-9.\]+)" $line -> v]} { return $v }
    }
    return -1
}

proc power_value {rpt key} {
    foreach line [split $rpt "\n"] {
        if {[regexp "^\\|\\s*${key}\\s*\\|\\s*(\[0-9.\]+)" $line -> v]} { return $v }
    }
    return -1
}

# returns 1 if routed with WNS >= 0
proc run_point {n} {
    global root part rpt_dir variant spad use_dsp
    set tag ${variant}_spad${spad}_N$n
    set run_dir $root/build/dse_pe/$tag
    file mkdir $run_dir
    cd $run_dir

    set status ROUTED
    set msg ""
    set stage synth
    set t0 [clock seconds]
    if {[catch {
        read_verilog [list $root/rtl/pe_array.v \
                           $root/rtl/eyeriss_v2_pe_dsp.v $root/rtl/eyeriss_v2_pe_nodsp.v \
                           $root/rtl/lfsr.v $root/rtl/bram.v]
        read_xdc $root/constraints/pe_array.xdc
        # one retry: parallel Vivado runs occasionally collide on shared files
        if {[catch {synth_design -top pe_array -part $part \
                -generic N_PE=$n -generic USE_DSP=$use_dsp -generic SPAD=$spad}]} {
            after 5000
            synth_design -top pe_array -part $part \
                -generic N_PE=$n -generic USE_DSP=$use_dsp -generic SPAD=$spad
        }
        report_utilization -file $rpt_dir/util_synth_$tag.rpt
        set stage opt
        opt_design
        set stage place
        place_design
        set stage route
        route_design
    } err]} {
        set status FAILED_$stage
        set msg [string map {"\n" " "} $err]
    }

    set wns NA
    set p_tot -1
    set p_dyn -1
    if {$status eq "ROUTED"} {
        report_utilization    -file $rpt_dir/util_$tag.rpt
        report_timing_summary -file $rpt_dir/timing_$tag.rpt
        report_power          -file $rpt_dir/power_$tag.rpt
        set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
        set u [report_utilization -return_string]
        set p [report_power -return_string]
        set p_tot [power_value $p {Total On-Chip Power \(W\)}]
        set p_dyn [power_value $p {Dynamic \(W\)}]
        if {$wns < 0} { set status TIMING_FAIL }
    } elseif {[file exists $rpt_dir/util_synth_$tag.rpt]} {
        set u [read [open $rpt_dir/util_synth_$tag.rpt]]
    } else {
        set u ""
    }
    set f [open $rpt_dir/summary_$tag.txt w]
    puts $f "variant=$variant"
    puts $f "spad=$spad"
    puts $f "n_pe=$n"
    puts $f "status=$status"
    puts $f "lut=[util_value $u {Slice LUTs\*?}]"
    puts $f "ff=[util_value $u {Slice Registers\*?}]"
    puts $f "dsp=[util_value $u {DSPs}]"
    puts $f "bram_tile=[util_value $u {Block RAM Tile}]"
    puts $f "ramb36=[util_value $u {RAMB36/FIFO\*?}]"
    puts $f "ramb18=[util_value $u {RAMB18}]"
    puts $f "wns=$wns"
    puts $f "power_total=$p_tot"
    puts $f "power_dynamic=$p_dyn"
    puts $f "seconds=[expr {[clock seconds] - $t0}]"
    puts $f "message=$msg"
    close $f
    puts "SWEEP $tag: $status wns=$wns P=$p_tot $msg"
    close_project -quiet
    cd $root
    return [expr {$status eq "ROUTED"}]
}

if {[llength $explicit]} {
    foreach n $explicit { run_point $n }
    return
}

set last_pass 0
set first_fail 0
set n 1
while {1} {
    if {[run_point $n]} {
        set last_pass $n
        set n [expr {$n * 2}]
    } else {
        set first_fail $n
        break
    }
}
# bisection to ~3 % resolution
while {$first_fail - $last_pass > max(1, $last_pass / 32)} {
    set mid [expr {($last_pass + $first_fail) / 2}]
    if {[run_point $mid]} { set last_pass $mid } else { set first_fail $mid }
}
puts "RESULT variant=$variant spad=$spad max_n_pe=$last_pass first_fail=$first_fail"
set f [open $rpt_dir/max_${variant}_spad$spad.txt w]
puts $f "variant=$variant spad=$spad max_n_pe=$last_pass first_fail=$first_fail"
close $f
