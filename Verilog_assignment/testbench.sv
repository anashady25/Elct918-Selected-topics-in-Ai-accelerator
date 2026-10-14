`timescale 1ns/1ps
// ============================================================
//  ELCT918 - Lab 4  |  testbench.sv
//
//  Covers:
//    * Exploration experiments (Task 1 report evidence)
//    * Task 2 - Self-checking testbench (10 000+ random cycles)
//    * Task 3 - Password test  (6, 3, B, 9  ->  flag = 1)
// ============================================================
module tb;

  // -- Shared stimulus signals --------------------------------
  reg        clk   = 0;
  reg        rst_n = 0;
  reg        en    = 0;
  reg  [3:0] din   = 0;

  // -- DUT outputs --------------------------------------------
  wire [7:0] dout_bb,  dout_sol;
  wire       flag_bb,  flag_sol;

  // -- Instantiate black-box (mystery) and solution side-by-side
  mystery  bb  (.clk(clk), .rst_n(rst_n), .en(en), .din(din),
                .dout(dout_bb),  .flag(flag_bb));

  solution sol (.clk(clk), .rst_n(rst_n), .en(en), .din(din),
                .dout(dout_sol), .flag(flag_sol));

  // -- 10 ns clock period -------------------------------------
  always #5 clk = ~clk;

  // -- Mismatch tracking --------------------------------------
  integer mismatches = 0;
  integer total_clks = 0;

  // Compare outputs 1 ns after every rising edge.
  // Registered outputs are stable well before the next edge.
  always @(posedge clk) begin
    total_clks = total_clks + 1;
    #1;
    if (dout_bb !== dout_sol || flag_bb !== flag_sol) begin
      mismatches = mismatches + 1;
      if (mismatches <= 5)
        $display("  MISMATCH #%0d at cycle %0d: bb_dout=%h bb_flag=%b | sol_dout=%h sol_flag=%b",
                 mismatches, total_clks, dout_bb, flag_bb, dout_sol, flag_sol);
    end
  end

  // ===========================================================
  //  Helper tasks
  // ===========================================================

  // Synchronous reset for 2 clock cycles, then release.
  task do_reset;
    begin
      @(negedge clk); rst_n = 0; en = 0; din = 0;
      @(posedge clk);
      @(posedge clk);
      #1;
      rst_n = 1;
    end
  endtask

  // Drive one nibble and print both outputs.
  task step;
    input        e;
    input  [3:0] d;
    begin
      @(negedge clk); en = e; din = d;
      @(posedge clk); #1;
      $display("  t=%0t en=%b din=%h -> bb_dout=%h bb_flag=%b | sol_dout=%h sol_flag=%b",
               $time, e, d, dout_bb, flag_bb, dout_sol, flag_sol);
    end
  endtask

  // ===========================================================
  //  Simulation body
  // ===========================================================
  integer i;

  initial begin
    $dumpfile("dump.vcd");
    // Depth 1: only top-level tb signals dumped.
    // Avoids "too many signals" error from mystery's internal wires.
    $dumpvars(1, tb);

    // Hold in reset for 2 cycles before anything else
    @(posedge clk); @(posedge clk); #1;
    $display("\n[RESET STATE] bb_dout=%h bb_flag=%b | sol_dout=%h sol_flag=%b",
             dout_bb, flag_bb, dout_sol, flag_sol);

    // ===========================================================
    //  EXPERIMENT 1 - Behaviour while en = 0
    //  Expected: outputs hold at 0x00, flag=0; counter must NOT advance.
    // ===========================================================
    $display("\n=== Experiment 1: en=0 (outputs must hold) ===");
    rst_n = 1;
    step(0, 4'h5);
    step(0, 4'h9);

    // ===========================================================
    //  EXPERIMENT 2 - Same plaintext 8 times in a row
    //  Key stream: 6,7,4,5,6,7,4,5
    //  din=0 -> expected ciphertexts: 6,7,4,5,6,7,4,5
    // ===========================================================
    $display("\n=== Experiment 2: 8x din=0 after reset - reveals key stream ===");
    do_reset;
    repeat(8) step(1, 4'h0);

    // ===========================================================
    //  EXPERIMENT 3 - Modular wrap-around
    //  din=0xA, key=6 -> 10+6=16 -> ciphertext wraps to 0x0
    // ===========================================================
    $display("\n=== Experiment 3: wrap-around (0xA + key6 = 0x0) ===");
    do_reset;
    step(1, 4'hA);

    // ===========================================================
    //  EXPERIMENT 4 - en toggling mid-stream
    //  Counter must freeze while en=0 and resume with same key.
    // ===========================================================
    $display("\n=== Experiment 4: en toggling - counter freezes when en=0 ===");
    do_reset;
    step(1, 4'h0);   // cnt=0, key=6 -> out=6
    step(0, 4'hF);   // en=0: hold, counter stays at 1
    step(0, 4'hF);   // en=0: hold
    step(1, 4'h0);   // cnt=1, key=7 -> out=7 (not 4)

    // ===========================================================
    //  EXPERIMENT 5 - Reset mid-stream
    //  Counter and history clear; key restarts from index 0.
    // ===========================================================
    $display("\n=== Experiment 5: reset mid-stream ===");
    do_reset;
    step(1, 4'h0);   // cnt=0, key=6 -> 6
    step(1, 4'h0);   // cnt=1, key=7 -> 7
    do_reset;
    step(1, 4'h0);   // cnt=0, key=6 -> 6 again (counter restarted)

    // ===========================================================
    //  TASK 3 - PASSWORD TEST
    //  Plaintext sequence 6,3,B,9 right after reset produces
    //  ciphertexts C,A,F,E -> flag must go HIGH on 4th nibble.
    // ===========================================================
    $display("\n=== Task 3: Password test (6,3,B,9) - expect flag=1 on 4th nibble ===");
    do_reset;
    step(1, 4'h6);   // ciphertext = 0xC  (6+6)
    step(1, 4'h3);   // ciphertext = 0xA  (3+7)
    step(1, 4'hB);   // ciphertext = 0xF  (11+4)
    step(1, 4'h9);   // ciphertext = 0xE  (9+5) -> flag HIGH
    $display("  >>> bb_flag=%b sol_flag=%b (both must be 1) <<<", flag_bb, flag_sol);
    if (flag_bb !== 1'b1)
      $display("  [WARNING] mystery flag did not rise - check wiring");
    if (flag_sol !== 1'b1)
      $display("  [WARNING] solution flag did not rise");

    // Extra nibble: window scrolls, flag must drop back to 0
    step(1, 4'h0);
    $display("  >>> After extra nibble: bb_flag=%b sol_flag=%b (both must be 0) <<<",
             flag_bb, flag_sol);

    // ===========================================================
    //  TASK 2 - SELF-CHECKING RANDOM STIMULUS
    //  >= 10 000 cycles, random en and din, resets every ~400 cycles.
    //  The always block above compares outputs on every rising edge.
    // ===========================================================
    $display("\n=== Task 2: Random self-check (10500 cycles) ===");
    do_reset;

    for (i = 0; i < 10500; i = i + 1) begin
      if (i % 400 == 399) begin
        do_reset;
      end else begin
        @(negedge clk);
        en  = $random & 1;
        din = $random & 4'hF;
        @(posedge clk);
        #1;
      end
    end

    // -- Final report -------------------------------------------
    $display("\n========================================");
    if (mismatches == 0)
      $display("  PASS - 0 mismatches in %0d clock cycles", total_clks);
    else begin
      $display("  FAIL - %0d mismatch(es) in %0d clock cycles",
               mismatches, total_clks);
    end
    $display("========================================\n");

    $finish;
  end

endmodule
