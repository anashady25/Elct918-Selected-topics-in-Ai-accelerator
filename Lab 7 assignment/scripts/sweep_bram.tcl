# -----------------------------------------------------------------------------
# sweep_bram.tcl -- Task 4.1: largest initialised block RAM per data width
#
# For every DATA_W the depth is swept in units of RAMB36 tiles
# (words per tile = 36 Kb / primitive width: 4096 for 8 bit, 2048 for 16/18,
# 1024 for 32/36). Every point: generate the init file (gen_init.py), synth,
# opt, place, route at 100 MHz, save utilization / timing reports and a
# one-line summary. If the 100 % point fails, the largest working depth is
# found by bisection between the last pass and the first failure.
#
#   vivado -mode batch -source scripts/sweep_bram.tcl -tclargs 8 16
#   (no args = all widths 8 16 18 32 36; run several processes in parallel
#    with different widths to save time)
#   vivado -mode batch -source scripts/sweep_bram.tcl -tclargs points 36:1024 18:8192
# -----------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
set part xc7a100tcsg324-1
set widths [expr {[llength $argv] ? $argv : {8 16 18 32 36}}]
set tiles_list {16 64 128 135 136}
set rpt_dir $root/reports/task4/bram
file mkdir $rpt_dir

proc words_per_tile {w} {
    if {$w <= 9}  { return 4096 }
    if {$w <= 18} { return 2048 }
    return 1024
}

proc util_value {rpt key} {
    foreach line [split $rpt "\n"] {
        if {[regexp "^\\|\\s*${key}\\s*\\|\\s*(\[0-9.\]+)" $line -> v]} { return $v }
    }
    return -1
}

# returns 1 if the point implemented (routed, no errors), 0 otherwise
proc run_point {w d} {
    global root part rpt_dir
    set tag W${w}_D${d}
    set run_dir $root/build/dse_bram/$tag
    file mkdir $run_dir
    cd $run_dir
    exec python $root/scripts/gen_init.py $w $d $run_dir/dse_init.mem

    set status ROUTED
    set msg ""
    set stage synth
    set t0 [clock seconds]
    if {[catch {
        read_verilog [list $root/rtl/bram_dse_top.v $root/rtl/bram.v $root/rtl/lfsr.v]
        read_mem $run_dir/dse_init.mem
        read_xdc $root/constraints/bram_dse.xdc
        # one retry: parallel Vivado runs occasionally collide on shared files
        if {[catch {synth_design -top bram_dse_top -part $part \
                -generic DATA_W=$w -generic DEPTH=$d}]} {
            after 5000
            synth_design -top bram_dse_top -part $part \
                -generic DATA_W=$w -generic DEPTH=$d
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
    if {$status eq "ROUTED"} {
        report_utilization    -file $rpt_dir/util_$tag.rpt
        report_timing_summary -file $rpt_dir/timing_$tag.rpt
        set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
        set u [report_utilization -return_string]
    } elseif {[file exists $rpt_dir/util_synth_$tag.rpt]} {
        set u [read [open $rpt_dir/util_synth_$tag.rpt]]
    } else {
        set u ""
    }
    set f [open $rpt_dir/summary_$tag.txt w]
    puts $f "width=$w"
    puts $f "depth=$d"
    puts $f "status=$status"
    puts $f "lut=[util_value $u {Slice LUTs\*?}]"
    puts $f "ff=[util_value $u {Slice Registers\*?}]"
    puts $f "bram_tile=[util_value $u {Block RAM Tile}]"
    puts $f "ramb36=[util_value $u {RAMB36/FIFO\*?}]"
    puts $f "ramb18=[util_value $u {RAMB18}]"
    puts $f "wns=$wns"
    puts $f "seconds=[expr {[clock seconds] - $t0}]"
    puts $f "message=$msg"
    close $f
    puts "SWEEP $tag: $status wns=$wns $msg"
    close_project -quiet
    cd $root
    return [expr {$status eq "ROUTED"}]
}

# "points W:D W:D ..." implements only the listed points (used for the
# shallow / medium depths that show how Vivado shapes the tiles)
if {[lindex $widths 0] eq "points"} {
    foreach p [lrange $widths 1 end] {
        lassign [split $p :] w d
        run_point $w $d
    }
    set widths {}
}

foreach w $widths {
    set wpt [words_per_tile $w]
    set last_pass 0
    set first_fail 0
    foreach t $tiles_list {
        set d [expr {$t * $wpt}]
        if {[run_point $w $d]} {
            set last_pass $d
        } else {
            set first_fail $d
            break
        }
    }
    # refine: largest working depth between last pass and first failure,
    # to a resolution of 1/8 tile
    if {$first_fail > 0 && $last_pass > 0} {
        set step [expr {$wpt / 8}]
        while {$first_fail - $last_pass > $step} {
            set mid [expr {(($last_pass + $first_fail) / 2 / $step) * $step}]
            if {$mid <= $last_pass} { break }
            if {[run_point $w $mid]} { set last_pass $mid } else { set first_fail $mid }
        }
    }
    puts "RESULT width=$w max_depth=$last_pass first_fail=$first_fail"
    set f [open $rpt_dir/max_W$w.txt w]
    puts $f "width=$w max_depth=$last_pass first_fail=$first_fail"
    close $f
}
