`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// seg7_hex.v -- shows a 32-bit value as 8 hex digits on the Nexys 4 DDR
// 7-segment display (common anode: segments and anodes are active low).
// Digit 7 (leftmost) = value[31:28] ... digit 0 (rightmost) = value[3:0].
// Each digit is refreshed at 100 MHz / 2^17 * 8 ~ 760 Hz.
// -----------------------------------------------------------------------------
module seg7_hex (
    input  wire        clk,
    input  wire [31:0] value,
    output reg  [6:0]  seg,      // {CG, CF, CE, CD, CC, CB, CA}, active low
    output wire        dp,
    output reg  [7:0]  an        // active low
);
    reg [16:0] refresh = 17'd0;
    always @(posedge clk) refresh <= refresh + 1'b1;

    wire [2:0] digit = refresh[16:14];
    wire [3:0] nib   = value[digit*4 +: 4];

    always @(posedge clk) begin
        an <= ~(8'b1 << digit);
        case (nib)                    //  gfedcba
            4'h0: seg <= 7'b1000000;
            4'h1: seg <= 7'b1111001;
            4'h2: seg <= 7'b0100100;
            4'h3: seg <= 7'b0110000;
            4'h4: seg <= 7'b0011001;
            4'h5: seg <= 7'b0010010;
            4'h6: seg <= 7'b0000010;
            4'h7: seg <= 7'b1111000;
            4'h8: seg <= 7'b0000000;
            4'h9: seg <= 7'b0010000;
            4'hA: seg <= 7'b0001000;
            4'hB: seg <= 7'b0000011;
            4'hC: seg <= 7'b1000110;
            4'hD: seg <= 7'b0100001;
            4'hE: seg <= 7'b0000110;
            default: seg <= 7'b0001110;   // F
        endcase
    end

    assign dp = 1'b1;
endmodule
