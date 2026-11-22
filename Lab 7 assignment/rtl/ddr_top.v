`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// ddr_top.v -- Task 1 (DDR2 test + bandwidth) and Task 3 (DDR2 power design)
//
// clk_wiz_0 -> 200 MHz to ram2ddr/MIG, 100 MHz to this logic.
// ddr_ctrl sweeps word addresses [A_START, A_END] of the 128 MiB DDR2
// (2^26 x 16 bit) through ram2ddr with the ram_ack_o 4-phase handshake.
//
// Switches (sampled when calibration completes; press CPU_RESET to re-run
// with new settings)
//   SW[2:0]  data pattern   0 address hash (verification)  1 all zeros
//                           2 all ones   3 0000/FFFF alternating
//                           4 5555/AAAA  5 LFSR pseudo-random
//   SW[4:3]  mode           00 test: write all, read all, check, stop
//                           01 loop write forever (power)
//                           10 prefill, then loop read forever (power)
//   SW[5]    quick range    1 = only the first 8192 words (sanity check)
//   SW[7:6]  display        see board_status.v
// LEDs / 7-segment: see board_status.v
// -----------------------------------------------------------------------------
module ddr_top #(
    parameter [25:0] A_START = 26'd0,
    parameter [25:0] A_END   = 26'h3FF_FFFF,  // 2^26 - 1 = 128 MiB / 2 B
    parameter [25:0] A_QUICK = 26'd8191
)(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire [7:0]  SW,
    output wire [15:0] LED,
    output wire [6:0]  SEG,
    output wire        DP,
    output wire [7:0]  AN,

    // DDR2 pins -- constrained by the MIG IP, not by the XDC
    output wire [12:0] ddr2_addr,
    output wire [2:0]  ddr2_ba,
    output wire        ddr2_ras_n,
    output wire        ddr2_cas_n,
    output wire        ddr2_we_n,
    output wire [0:0]  ddr2_ck_p,
    output wire [0:0]  ddr2_ck_n,
    output wire [0:0]  ddr2_cke,
    output wire [0:0]  ddr2_cs_n,
    output wire [1:0]  ddr2_dm,
    output wire [0:0]  ddr2_odt,
    inout  wire [15:0] ddr2_dq,
    inout  wire [1:0]  ddr2_dqs_p,
    inout  wire [1:0]  ddr2_dqs_n
);

    // ------------------------------------------------------------------ clocks
    wire clk200, clk100, locked;

    clk_wiz_0 u_clk (
        .clk_in1  (CLK100MHZ),
        .reset    (1'b0),
        .clk_out1 (clk200),      // 200 MHz -> ram2ddr / MIG
        .clk_out2 (clk100),      // 100 MHz -> controller
        .locked   (locked)
    );

    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk100 or negedge locked)
        if (!locked)          rst_sync <= 2'b11;
        else if (!CPU_RESETN) rst_sync <= 2'b11;
        else                  rst_sync <= {rst_sync[0], 1'b0};
    wire rst = rst_sync[1];

    reg [7:0] sw_s1 = 8'd0, sw_s2 = 8'd0;
    always @(posedge clk100) begin
        sw_s1 <= SW;
        sw_s2 <= sw_s1;
    end

    // ------------------------------------------------------------------ ram2ddr
    wire [25:0] mem_a;
    wire [15:0] mem_d, ram_dq_o;
    wire        mem_cen, mem_wen, mem_oen;
    wire        calib, ram_ack;

    ram2ddr u_ram (
        .clk_200MHz_i  (clk200),
        .rst_i         (~locked),
        .device_temp_i (12'd0),

        .ram_a         ({mem_a, 1'b0}),         // byte address = word * 2
        .ram_dq_i      (mem_d),
        .ram_dq_o      (ram_dq_o),
        .ram_cen       (mem_cen),
        .ram_oen       (mem_oen),
        .ram_wen       (mem_wen),
        .ram_ub        (1'b0),
        .ram_lb        (1'b0),

        .calib_o       (calib),
        .ram_ack_o     (ram_ack),

        .ddr2_addr     (ddr2_addr),
        .ddr2_ba       (ddr2_ba),
        .ddr2_ras_n    (ddr2_ras_n),
        .ddr2_cas_n    (ddr2_cas_n),
        .ddr2_we_n     (ddr2_we_n),
        .ddr2_ck_p     (ddr2_ck_p),
        .ddr2_ck_n     (ddr2_ck_n),
        .ddr2_cke      (ddr2_cke),
        .ddr2_cs_n     (ddr2_cs_n),
        .ddr2_dm       (ddr2_dm),
        .ddr2_odt      (ddr2_odt),
        .ddr2_dq       (ddr2_dq),
        .ddr2_dqs_p    (ddr2_dqs_p),
        .ddr2_dqs_n    (ddr2_dqs_n)
    );

    reg [1:0] ack_sync   = 2'b00;
    reg [1:0] calib_sync = 2'b00;
    always @(posedge clk100) begin
        ack_sync   <= {ack_sync[0],   ram_ack};
        calib_sync <= {calib_sync[0], calib};
    end

    // ------------------------------------------------------------------ controller
    wire [2:0]  state;
    wire [26:0] errors;
    wire [39:0] wr_cycles, rd_cycles;
    wire [15:0] passes;

    ddr_ctrl #(
        .DATA_W (16),
        .ADDR_W (26),
        .GAP    (4)
    ) u_ctrl (
        .clk       (clk100),
        .rst       (rst),
        .start     (calib_sync[1]),
        .mode      (sw_s2[4:3]),
        .pat_sel   (sw_s2[2:0]),
        .a_start   (A_START),
        .a_end     (sw_s2[5] ? A_QUICK : A_END),
        .mem_a     (mem_a),
        .mem_d     (mem_d),
        .mem_q     (ram_dq_o),
        .mem_cen   (mem_cen),
        .mem_wen   (mem_wen),
        .mem_oen   (mem_oen),
        .mem_ack   (ack_sync[1]),
        .state     (state),
        .errors    (errors),
        .wr_cycles (wr_cycles),
        .rd_cycles (rd_cycles),
        .passes    (passes)
    );

    board_status #(.ERR_W(27), .CNT_W(40)) u_status (
        .clk       (clk100),
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
