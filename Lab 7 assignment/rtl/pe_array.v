`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// pe_array.v -- Task 4.2 design space exploration
//
// N_PE copies of the Lab 5 PE (eyeriss_v2_pe) in a generate loop.
//   * every PE has its own 32-bit LFSR with a different seed, so no two PEs
//     see the same inputs and synthesis cannot merge them
//   * all 40-bit psum outputs are XOR-reduced (registered 2-level tree) into
//     the 16 LEDs, so synthesis cannot remove any PE
//   * USE_DSP = 1 selects eyeriss_v2_pe_dsp   (* use_dsp = "yes" *)
//     USE_DSP = 0 selects eyeriss_v2_pe_nodsp (* use_dsp = "no" *)
//     (Vivado puts 8 x 8 multipliers in LUTs unless DSPs are requested)
//   * SPAD = 1 gives every PE a private 1 Ki x 16 block RAM scratchpad
//     (Task 4.2.5): the low 16 psum bits are written into it and the read
//     data is XORed into the PE's contribution to the reduction
//
// psum_mux_sel is tied to 1, so every PE accumulates into its local psum.
// -----------------------------------------------------------------------------
module pe_array #(
    parameter integer N_PE    = 4,
    parameter integer USE_DSP = 1,
    parameter integer SPAD    = 0
)(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    output reg  [15:0] LED
);
    localparam integer G  = 16;                 // PEs per first-level XOR group
    localparam integer NG = (N_PE + G - 1) / G;

    wire clk = CLK100MHZ;

    reg [2:0] rst_sync = 3'b111;
    always @(posedge clk)
        rst_sync <= CPU_RESETN ? {rst_sync[1:0], 1'b0} : 3'b111;

    // scratchpad address / write enable counter (data differs per PE)
    reg  [9:0] spad_addr = 10'd0;
    reg        spad_we   = 1'b0;
    always @(posedge clk) begin
        spad_addr <= spad_addr + 1'b1;
        spad_we   <= ~spad_we;
    end

    // Reset and scratchpad control are distributed through a registered tree
    // (one copy per group of G PEs, then one per PE). A single flop driving
    // every PE register would make routing delay, not the PE, limit N_PE.
    (* keep = "true" *) reg        rst_grp  [0:NG-1];
    (* keep = "true" *) reg [9:0]  addr_grp [0:NG-1];
    (* keep = "true" *) reg        we_grp   [0:NG-1];
    genvar r;
    generate
        for (r = 0; r < NG; r = r + 1) begin : g_ctl
            always @(posedge clk) begin
                rst_grp[r]  <= rst_sync[2];
                addr_grp[r] <= spad_addr;
                we_grp[r]   <= spad_we;
            end
        end
    endgenerate

    wire [39:0] pe_out [0:N_PE-1];

    genvar i;
    generate
        for (i = 0; i < N_PE; i = i + 1) begin : g_pe
            wire [31:0] q;
            wire [39:0] psum;

            (* keep = "true" *) reg rst_pe = 1'b1;
            always @(posedge clk) rst_pe <= rst_grp[i / G];
            wire rst_n = ~rst_pe;

            lfsr #(
                .W    (32),
                .SEED ((32'hACE1_2468 ^ (i * 32'h9E37_79B1)) | 32'h1)
            ) u_lfsr (
                .clk  (clk),
                .rst  (~rst_n),
                .load (1'b0),
                .en   (1'b1),
                .q    (q)
            );

            if (USE_DSP != 0) begin : g_dsp
                eyeriss_v2_pe_dsp u_pe (
                    .clk            (clk),
                    .rst_n          (rst_n),
                    .iact_data_in   (q[11:0]),
                    .weight_data_in (q[31:8]),
                    .psum_in        (40'd0),
                    .csc_match_en   (q[31] | q[3]),
                    .psum_mux_sel   (1'b1),
                    .psum_out       (psum)
                );
            end else begin : g_lut
                eyeriss_v2_pe_nodsp u_pe (
                    .clk            (clk),
                    .rst_n          (rst_n),
                    .iact_data_in   (q[11:0]),
                    .weight_data_in (q[31:8]),
                    .psum_in        (40'd0),
                    .csc_match_en   (q[31] | q[3]),
                    .psum_mux_sel   (1'b1),
                    .psum_out       (psum)
                );
            end

            if (SPAD != 0) begin : g_spad
                wire [15:0] spad_q;
                bram #(.DATA_W(16), .DEPTH(1024), .INIT_FILE("")) u_spad (
                    .clk  (clk),
                    .en   (1'b1),
                    .we   (we_grp[i / G]),
                    .addr (addr_grp[i / G]),
                    .din  (psum[15:0]),
                    .dout (spad_q)
                );
                assign pe_out[i] = psum ^ {24'd0, spad_q};
            end else begin : g_nospad
                assign pe_out[i] = psum;
            end
        end
    endgenerate

    // ------------------------------------------------------------------ XOR reduction
    reg [39:0] grp [0:NG-1];

    genvar g;
    generate
        for (g = 0; g < NG; g = g + 1) begin : g_red
            integer k;
            reg [39:0] acc;
            always @(*) begin
                acc = 40'd0;
                for (k = g * G; k < g * G + G; k = k + 1)
                    if (k < N_PE)
                        acc = acc ^ pe_out[k];
            end
            always @(posedge clk) grp[g] <= acc;
        end
    endgenerate

    integer m;
    reg [39:0] red_c;
    reg [39:0] red;
    always @(*) begin
        red_c = 40'd0;
        for (m = 0; m < NG; m = m + 1)
            red_c = red_c ^ grp[m];
    end
    always @(posedge clk) begin
        red <= red_c;
        LED <= red[15:0] ^ red[31:16] ^ {8'd0, red[39:32]};
    end
endmodule
