`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// board_status.v -- LEDs and 7-segment display for the ddr_ctrl test designs
//
// LEDs
//   LED[0]  waiting (calibration / start)     LED[3]  done
//   LED[1]  writing                           LED[4]  TIMEOUT (wrapper hung)
//   LED[2]  reading                           LED[14] FAIL (errors != 0)
//                                             LED[15] PASS (done, 0 errors)
// 7-segment display (disp_sel = SW[7:6])
//   00  error count
//   01  write-pass cycles [31:0]
//   10  read-pass  cycles [31:0]
//   11  {write cycles [39:32], read cycles [39:32], completed passes [15:0]}
// -----------------------------------------------------------------------------
module board_status #(
    parameter integer ERR_W = 27,
    parameter integer CNT_W = 40
)(
    input  wire             clk,
    input  wire [2:0]       state,
    input  wire [ERR_W-1:0] errors,
    input  wire [CNT_W-1:0] wr_cycles,
    input  wire [CNT_W-1:0] rd_cycles,
    input  wire [15:0]      passes,
    input  wire [1:0]       disp_sel,
    output reg  [15:0]      led,
    output wire [6:0]       seg,
    output wire             dp,
    output wire [7:0]       an
);
    localparam [2:0] S_IDLE = 3'd0, S_W_SETUP = 3'd1, S_W_ACCESS = 3'd2,
                     S_R_SETUP = 3'd3, S_R_ACCESS = 3'd4, S_DONE = 3'd5,
                     S_TIMEOUT = 3'd6;

    wire [63:0] wr64  = {{(64-CNT_W){1'b0}}, wr_cycles};
    wire [63:0] rd64  = {{(64-CNT_W){1'b0}}, rd_cycles};
    wire [31:0] err32 = {{(32-ERR_W){1'b0}}, errors};
    wire        fail  = |errors;

    always @(posedge clk) begin
        led      <= 16'h0000;
        led[0]   <= (state == S_IDLE);
        led[1]   <= (state == S_W_SETUP) || (state == S_W_ACCESS);
        led[2]   <= (state == S_R_SETUP) || (state == S_R_ACCESS);
        led[3]   <= (state == S_DONE);
        led[4]   <= (state == S_TIMEOUT);
        led[14]  <= fail;
        led[15]  <= (state == S_DONE) && !fail;
    end

    reg [31:0] value;
    always @(posedge clk) begin
        case (disp_sel)
            2'd0: value <= err32;
            2'd1: value <= wr64[31:0];
            2'd2: value <= rd64[31:0];
            default: value <= {wr64[39:32], rd64[39:32], passes};
        endcase
    end

    seg7_hex u_seg (.clk(clk), .value(value), .seg(seg), .dp(dp), .an(an));
endmodule
