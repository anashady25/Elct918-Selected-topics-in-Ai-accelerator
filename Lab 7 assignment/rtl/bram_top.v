`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// bram_top.v -- Task 2 (BRAM sweep + bandwidth on the board) and
//               Task 3 (BRAM power design)
//
// The ddr_ctrl controller of Task 1 drives a DATA_W x DEPTH block RAM through
// a small adapter that produces the same 4-phase ram_ack handshake as
// ram2ddr:  the BRAM performs the access on the first clock edge that sees
// CEN low; ack rises with the registered read data and drops as soon as the
// controller releases CEN. With GAP = 0 one access takes 3 clock cycles.
//
// Clock: the 100 MHz board oscillator directly (no MMCM needed).
// Switches, LEDs and display: same meaning as in ddr_top.v (SW[5] unused).
// -----------------------------------------------------------------------------
module bram_top #(
    parameter integer DATA_W    = 32,
    parameter integer DEPTH     = 4096,
    parameter         INIT_FILE = "bram32_init.mem"
)(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire [7:0]  SW,
    output wire [15:0] LED,
    output wire [6:0]  SEG,
    output wire        DP,
    output wire [7:0]  AN
);
    localparam integer          ADDR_W    = $clog2(DEPTH);
    localparam [ADDR_W-1:0]     LAST_ADDR = DEPTH - 1;

    wire clk = CLK100MHZ;

    reg [2:0] rst_sync = 3'b111;
    always @(posedge clk)
        rst_sync <= CPU_RESETN ? {rst_sync[1:0], 1'b0} : 3'b111;
    wire rst = rst_sync[2];

    reg [7:0] sw_s1 = 8'd0, sw_s2 = 8'd0;
    always @(posedge clk) begin
        sw_s1 <= SW;
        sw_s2 <= sw_s1;
    end

    // start a short while after reset so the switches are settled
    reg [3:0] start_dly = 4'd0;
    always @(posedge clk)
        if (rst) start_dly <= 4'd0;
        else if (!start_dly[3]) start_dly <= start_dly + 1'b1;

    // ------------------------------------------------------------------ BRAM + ack adapter
    wire [ADDR_W-1:0] mem_a;
    wire [DATA_W-1:0] mem_d, mem_q;
    wire              mem_cen, mem_wen, mem_oen;

    reg ack_r = 1'b0;
    always @(posedge clk)
        ack_r <= ~mem_cen & (~mem_wen | ~mem_oen);
    wire mem_ack = ack_r & ~mem_cen;

    bram #(
        .DATA_W    (DATA_W),
        .DEPTH     (DEPTH),
        .INIT_FILE (INIT_FILE)
    ) u_bram (
        .clk  (clk),
        .en   (~mem_cen),
        .we   (~mem_cen & ~mem_wen),
        .addr (mem_a),
        .din  (mem_d),
        .dout (mem_q)
    );

    // ------------------------------------------------------------------ controller
    wire [2:0]        state;
    wire [ADDR_W:0]   errors;
    wire [39:0]       wr_cycles, rd_cycles;
    wire [15:0]       passes;

    ddr_ctrl #(
        .DATA_W (DATA_W),
        .ADDR_W (ADDR_W),
        .GAP    (0)
    ) u_ctrl (
        .clk       (clk),
        .rst       (rst),
        .start     (start_dly[3]),
        .mode      (sw_s2[4:3]),
        .pat_sel   (sw_s2[2:0]),
        .a_start   ({ADDR_W{1'b0}}),
        .a_end     (LAST_ADDR),
        .mem_a     (mem_a),
        .mem_d     (mem_d),
        .mem_q     (mem_q),
        .mem_cen   (mem_cen),
        .mem_wen   (mem_wen),
        .mem_oen   (mem_oen),
        .mem_ack   (mem_ack),
        .state     (state),
        .errors    (errors),
        .wr_cycles (wr_cycles),
        .rd_cycles (rd_cycles),
        .passes    (passes)
    );

    board_status #(.ERR_W(ADDR_W+1), .CNT_W(40)) u_status (
        .clk       (clk),
        .state     (state),
        .errors    (errors),
        .wr_cycles (wr_cycles),
        .rd_cycles (rd_cycles),
        .passes    (passes),
        .disp_sel  (sw_s2[7:6]),
        .led       (LED),
        .seg       (SEG),
        .dp        (DP),
        .an        (AN)
    );

endmodule
