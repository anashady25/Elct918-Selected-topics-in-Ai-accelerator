`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_bram.v -- self-checking testbench for the parameterized bram (Task 2)
//
//   Test 1  preloaded contents of ALL DEPTH addresses (rule of gen_init.py)
//   Test 2  write then read back at several addresses (first, last, middle)
//   Test 3  read-first: in the write cycle dout shows the OLD value,
//           in the next read the NEW value
//   Test 4  neighbouring addresses are not disturbed by the writes
//   Test 5  en = 0: no write and dout holds its value
//
// Prints PASS or FAIL with the error count. Override DATA_W / DEPTH /
// INIT_FILE with xelab -generic_top (see scripts/run_tb_bram.tcl).
// -----------------------------------------------------------------------------
module tb_bram;
    parameter integer DATA_W    = 32;
    parameter integer DEPTH     = 4096;
    parameter         INIT_FILE = "bram32_init.mem";
    localparam integer ADDR_W   = $clog2(DEPTH);

    reg               clk  = 1'b0;
    reg               en   = 1'b0;
    reg               we   = 1'b0;
    reg  [ADDR_W-1:0] addr = 0;
    reg  [DATA_W-1:0] din  = 0;
    wire [DATA_W-1:0] dout;

    bram #(.DATA_W(DATA_W), .DEPTH(DEPTH), .INIT_FILE(INIT_FILE)) dut (
        .clk(clk), .en(en), .we(we), .addr(addr), .din(din), .dout(dout)
    );

    always #5 clk = ~clk;       // 100 MHz

    integer errors = 0;
    integer checks = 0;
    integer i;

    // same rule as scripts/gen_init.py
    function [DATA_W-1:0] init_val(input integer a);
        reg [63:0] v;
        begin
            if (a == 0)      v = 64'hDEADBEEF;
            else if (a == 1) v = 64'hCAFEBABE;
            else             v = {32'd0, a[15:0], ~a[15:0]};
            if (DATA_W > 32) v = v | ({32'd0, a} << 32);
            init_val = v[DATA_W-1:0];
        end
    endfunction

    function [DATA_W-1:0] pat(input integer k);   // write data
        pat = {(DATA_W+31)/32{32'hA5C3_0F00 + k}};
    endfunction

    task check(input [DATA_W-1:0] expected, input [255:0] what);
        begin
            checks = checks + 1;
            if (dout !== expected) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("  ERROR @%0t ns: %0s addr %0d: dout = %h, expected %h",
                             $time, what, addr, dout, expected);
            end
        end
    endtask

    task read_check(input integer a, input [DATA_W-1:0] expected);
        begin
            @(negedge clk);  en = 1; we = 0; addr = a;
            @(posedge clk);  #1;
            check(expected, "read");
        end
    endtask

    task write(input integer a, input [DATA_W-1:0] d);
        begin
            @(negedge clk);  en = 1; we = 1; addr = a; din = d;
            @(posedge clk);  #1;
            @(negedge clk);  we = 0;
        end
    endtask

    integer mid;
    reg [DATA_W-1:0] held;

    initial begin
        $display("==== tb_bram: %0d x %0d bit, init %0s ====", DEPTH, DATA_W, INIT_FILE);
        mid = DEPTH / 2 + 3;
        repeat (3) @(posedge clk);

        $display("Test 1: preloaded contents (all %0d addresses)", DEPTH);
        for (i = 0; i < DEPTH; i = i + 1)
            read_check(i, init_val(i));

        $display("Test 2: write then read back");
        write(0,       pat(0));
        write(5,       pat(1));
        write(mid,     pat(2));
        write(DEPTH-1, pat(3));
        read_check(0,       pat(0));
        read_check(5,       pat(1));
        read_check(mid,     pat(2));
        read_check(DEPTH-1, pat(3));

        $display("Test 3: read-first behaviour during a write");
        @(negedge clk);  en = 1; we = 1; addr = 10; din = pat(4);
        @(posedge clk);  #1;
        check(init_val(10), "read-first (old value during write)");
        @(negedge clk);  we = 0;
        @(posedge clk);  #1;
        check(pat(4), "read-first (new value after write)");

        $display("Test 4: neighbouring addresses unchanged");
        read_check(4,       init_val(4));
        read_check(6,       init_val(6));
        read_check(9,       init_val(9));
        read_check(11,      init_val(11));
        read_check(mid-1,   init_val(mid-1));
        read_check(mid+1,   init_val(mid+1));
        read_check(DEPTH-2, init_val(DEPTH-2));

        $display("Test 5: en = 0 blocks writes and holds dout");
        read_check(20, init_val(20));
        held = dout;
        @(negedge clk);  en = 0; we = 1; addr = 20; din = pat(5);
        @(posedge clk);  #1;
        check(held, "en=0 holds dout");
        @(negedge clk);  we = 0;
        read_check(20, init_val(20));

        $display("============================");
        if (errors == 0) $display("PASS: all %0d checks OK", checks);
        else             $display("FAIL: %0d of %0d checks failed", errors, checks);
        $display("============================");
        $finish;
    end
endmodule
