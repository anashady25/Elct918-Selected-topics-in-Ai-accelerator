`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// bram.v -- parameterized single-port block RAM (Task 2, reused in Task 4)
//   * DATA_W x DEPTH, forced into block RAM with ram_style = "block"
//   * preloaded from INIT_FILE with $readmemh (leave "" for no preload)
//   * registered read with read-first behaviour: during a write, dout shows
//     the OLD contents of the address
//   * en gates the whole port (no read, no write when low)
// -----------------------------------------------------------------------------
module bram #(
    parameter integer DATA_W    = 16,
    parameter integer DEPTH     = 4096,
    parameter         INIT_FILE = "init.mem",
    parameter integer ADDR_W    = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input  wire              clk,
    input  wire              en,
    input  wire              we,
    input  wire [ADDR_W-1:0] addr,
    input  wire [DATA_W-1:0] din,
    output reg  [DATA_W-1:0] dout
);
    (* ram_style = "block" *) reg [DATA_W-1:0] mem [0:DEPTH-1];

    generate
        if (INIT_FILE != "") begin : g_init
            initial $readmemh(INIT_FILE, mem);
        end
    endgenerate

    always @(posedge clk) begin
        if (en) begin
            if (we)
                mem[addr] <= din;
            dout <= mem[addr];
        end
    end
endmodule
