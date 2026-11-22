`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_bram_top.v -- runs the full Task 2 board design (ddr_ctrl + BRAM) in
// simulation: write pass + read pass + check for several data patterns,
// prints PASS/FAIL, the cycle counts of both passes and the bandwidth.
// Also checks that a corrupted word is detected (error injection).
// -----------------------------------------------------------------------------
module tb_bram_top;
    localparam integer DATA_W = 32;
    localparam integer DEPTH  = 4096;
    localparam real    F_CLK  = 100.0e6;

    reg         clk  = 1'b0;
    reg         rstn = 1'b0;
    reg  [7:0]  sw   = 8'd0;
    wire [15:0] led;
    wire [6:0]  seg;
    wire        dp;
    wire [7:0]  an;

    bram_top #(.DATA_W(DATA_W), .DEPTH(DEPTH), .INIT_FILE("bram32_init.mem")) dut (
        .CLK100MHZ (clk), .CPU_RESETN (rstn), .SW (sw),
        .LED (led), .SEG (seg), .DP (dp), .AN (an)
    );

    always #5 clk = ~clk;

    integer fails = 0;

    task run_test(input [2:0] pat, input inject);
        real wr_bw, rd_bw;
        begin
            sw   = {2'b00, 1'b0, 2'b00, pat};     // mode = test
            rstn = 1'b0;
            repeat (10) @(posedge clk);
            rstn = 1'b1;
            if (inject) begin                     // corrupt one word after the write pass
                wait (led[2] === 1'b1);
                dut.u_bram.mem[123] = ~dut.u_bram.mem[123];
            end
            wait (led[3] === 1'b1 || led[4] === 1'b1);
            @(posedge clk);
            wr_bw = DEPTH * (DATA_W / 8.0) * F_CLK / dut.wr_cycles / 1.0e6;
            rd_bw = DEPTH * (DATA_W / 8.0) * F_CLK / dut.rd_cycles / 1.0e6;
            $display("pattern %0d%0s: %0s  errors=%0d  write=%0d cycles (%.2f cyc/word, %.1f MB/s)  read=%0d cycles (%.2f cyc/word, %.1f MB/s)",
                     pat, inject ? " (1 word corrupted)" : "",
                     led[15] ? "PASS" : (led[4] ? "TIMEOUT" : "FAIL"), dut.errors,
                     dut.wr_cycles, dut.wr_cycles / (1.0 * DEPTH), wr_bw,
                     dut.rd_cycles, dut.rd_cycles / (1.0 * DEPTH), rd_bw);
            if (inject ? (dut.errors != 1) : (led[15] !== 1'b1))
                fails = fails + 1;
        end
    endtask

    initial begin
        $display("==== tb_bram_top: ddr_ctrl sweeping a %0d x %0d BRAM ====", DEPTH, DATA_W);
        run_test(3'd0, 1'b0);     // address hash
        run_test(3'd1, 1'b0);     // zeros
        run_test(3'd2, 1'b0);     // ones
        run_test(3'd3, 1'b0);     // 0/1 alternating
        run_test(3'd4, 1'b0);     // 5555/AAAA
        run_test(3'd5, 1'b0);     // LFSR
        run_test(3'd5, 1'b1);     // LFSR + injected error -> must count exactly 1
        $display("============================");
        if (fails == 0) $display("PASS: all sweeps behaved as expected");
        else            $display("FAIL: %0d sweeps misbehaved", fails);
        $display("============================");
        $finish;
    end
endmodule
