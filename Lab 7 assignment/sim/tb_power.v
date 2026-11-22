`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_power.v -- Task 3: post-implementation functional simulation of bram_top
// for one (operation, pattern) case, to record a SAIF file of the real
// switching activity (scripts/power_bram_sims.bat drives it).
//
//   MODE 1 = loop write forever, 2 = prefill then loop read forever
//   PAT  1 = zeros, 2 = ones, 3 = 0/1 alternating, 4 = 5555/AAAA, 5 = LFSR
//
// MODE and PAT come from plusargs (xsim -testplusarg MODE=2 -testplusarg PAT=5)
// so that one snapshot serves all cases and the scope stays /tb_power.
// The SAIF window (opened by the xsim Tcl script) starts after the prefill
// pass of the read cases is long finished.
// -----------------------------------------------------------------------------
module tb_power;
    integer MODE = 1;
    integer PAT  = 1;

    reg         CLK100MHZ  = 1'b0;
    reg         CPU_RESETN = 1'b0;
    reg  [7:0]  SW = 8'd0;
    wire [15:0] LED;
    wire [6:0]  SEG;
    wire        DP;
    wire [7:0]  AN;

    bram_top dut (
        .CLK100MHZ (CLK100MHZ), .CPU_RESETN (CPU_RESETN), .SW (SW),
        .LED (LED), .SEG (SEG), .DP (DP), .AN (AN)
    );

    always #5 CLK100MHZ = ~CLK100MHZ;

    initial begin
        if (!$value$plusargs("MODE=%d", MODE)) MODE = 1;
        if (!$value$plusargs("PAT=%d",  PAT))  PAT  = 1;
        SW = {2'b00, 1'b0, MODE[1:0], PAT[2:0]};
        #200 CPU_RESETN = 1'b1;
    end

    // progress report (LED[1] = writing, LED[2] = reading, LED[14] = mismatch)
    always @(posedge LED[1]) $display("%0t ns: writing (mode %0d, pattern %0d)", $time, MODE, PAT);
    always @(posedge LED[2]) $display("%0t ns: reading (mode %0d, pattern %0d)", $time, MODE, PAT);
    always @(posedge LED[14]) $display("%0t ns: WARNING read mismatch detected", $time);
endmodule
