`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// lfsr.v -- Galois LFSR, shifts right once per enabled clock.
// Default polynomial x^32 + x^22 + x^2 + x + 1 (maximal length, XAPP052).
// -----------------------------------------------------------------------------
module lfsr #(
    parameter integer   W    = 32,
    parameter [W-1:0]   SEED = 32'hACE1_2468,   // must be non-zero
    parameter [W-1:0]   TAPS = 32'h8020_0003
)(
    input  wire         clk,
    input  wire         rst,     // synchronous, loads SEED
    input  wire         load,    // synchronous, loads SEED
    input  wire         en,      // advance one step
    output reg  [W-1:0] q = SEED
);
    always @(posedge clk) begin
        if (rst || load)
            q <= SEED;
        else if (en)
            q <= q[0] ? ((q >> 1) ^ TAPS) : (q >> 1);
    end
endmodule
