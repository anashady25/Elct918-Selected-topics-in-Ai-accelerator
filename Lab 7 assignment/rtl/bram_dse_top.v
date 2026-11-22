`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// bram_dse_top.v -- Task 4.1: largest initialised block RAM
//
// One bram (forced to block RAM, preloaded with $readmemh from INIT_FILE),
// exercised so that synthesis must keep every word:
//   * the address counts 0 .. DEPTH-1 and wraps
//   * write data comes from an LFSR, write enable from SW[0]
//   * the read data is XOR-folded into the 16 LEDs
// -----------------------------------------------------------------------------
module bram_dse_top #(
    parameter integer DATA_W    = 36,
    parameter integer DEPTH     = 1024,
    parameter         INIT_FILE = "dse_init.mem"
)(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        WE,
    output reg  [15:0] LED
);
    localparam integer ADDR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam [ADDR_W-1:0] LAST = DEPTH - 1;

    wire clk = CLK100MHZ;

    reg [2:0] rst_sync = 3'b111;
    reg [1:0] we_sync  = 2'b00;
    always @(posedge clk) begin
        rst_sync <= CPU_RESETN ? {rst_sync[1:0], 1'b0} : 3'b111;
        we_sync  <= {we_sync[0], WE};
    end
    wire rst = rst_sync[2];

    reg [ADDR_W-1:0] addr = {ADDR_W{1'b0}};
    always @(posedge clk)
        if (rst || addr == LAST) addr <= {ADDR_W{1'b0}};
        else                     addr <= addr + 1'b1;

    wire [31:0] q;
    lfsr #(.W(32)) u_lfsr (.clk(clk), .rst(rst), .load(1'b0), .en(1'b1), .q(q));

    wire [63:0]       din64 = {q, q};
    wire [DATA_W-1:0] dout;

    bram #(.DATA_W(DATA_W), .DEPTH(DEPTH), .INIT_FILE(INIT_FILE)) u_bram (
        .clk  (clk),
        .en   (1'b1),
        .we   (we_sync[1]),
        .addr (addr),
        .din  (din64[DATA_W-1:0]),
        .dout (dout)
    );

    wire [47:0] d48 = {{(48-DATA_W){1'b0}}, dout};
    always @(posedge clk)
        LED <= d48[15:0] ^ d48[31:16] ^ d48[47:32];
endmodule
