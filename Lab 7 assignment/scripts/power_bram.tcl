# -----------------------------------------------------------------------------
# power_bram.tcl -- Task 3, BRAM: report_power of the implemented bram_top
# with the switching activity of every (operation, pattern) case read from
# its SAIF file, plus a toggle-rate sweep (0/25/50/100 %) of the BRAM data
# pins.
# Needs build/bram_top_routed.dcp (build_bram.tcl) and build/saif/*.saif
# (power_bram_sims.bat).
#
#   vivado -mode batch -source scripts/power_bram.tcl    (from "Lab7 assignment")
# -----------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
file mkdir reports/task3

open_checkpoint build/bram_top_routed.dcp
set_units -power mW         ;# reports in mW with 3 decimals (1 uW resolution)

# ---------------------------------------------------------------- per-case SAIF
foreach op {write read} {
    foreach pat {zeros ones alt01 5555aaaa lfsr} {
        set case bram_${op}_${pat}
        reset_switching_activity -all
        read_saif build/saif/$case.saif -strip_path tb_power/dut -out_file reports/task3/${case}_saif_match.txt
        report_power -file reports/task3/power_${case}.rpt
        puts "power: $case done"
    }
}

# ---------------------------------------------------------------- toggle-rate sweep
# activity of the control logic from the LFSR case of each operation, then the
# BRAM data pins forced to a toggle rate (static probability 0.5)
set brams     [get_cells -hier -filter {REF_NAME =~ RAMB*}]
set din_nets  [get_nets -of [get_pins -of $brams -filter {REF_PIN_NAME =~ DIADI* || REF_PIN_NAME =~ DIBDI* || REF_PIN_NAME =~ DIPADIP* || REF_PIN_NAME =~ DIPBDIP*}]]
set dout_nets [get_nets -of [get_pins -of $brams -filter {REF_PIN_NAME =~ DOADO* || REF_PIN_NAME =~ DOBDO* || REF_PIN_NAME =~ DOPADOP* || REF_PIN_NAME =~ DOPBDOP*}]]
puts "BRAM cells: [llength $brams], data-in nets: [llength $din_nets], data-out nets: [llength $dout_nets]"

foreach op {write read} {
    foreach tr {0 25 50 100} {
        reset_switching_activity -all
        read_saif build/saif/bram_${op}_lfsr.saif -strip_path tb_power/dut
        set nets [expr {$op eq "write" ? $din_nets : $dout_nets}]
        set_switching_activity -toggle_rate $tr -static_probability 0.5 $nets
        report_power -file reports/task3/power_bram_${op}_toggle${tr}.rpt
        puts "power: bram $op toggle $tr % done"
    }
}
puts "DONE: reports/task3/power_bram_*.rpt"
