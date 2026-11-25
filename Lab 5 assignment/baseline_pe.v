`timescale 1ns/1ps

// Conventional Dense MAC PE (Baseline)
// Matches the pipeline depth of Eyeriss v2 for 1-to-1 comparison
module baseline_pe (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  iact_data_in,
    input  wire [7:0]  weight_data_in,
    input  wire [19:0] psum_in,
    input  wire        psum_mux_sel,
    output wire [19:0] psum_out
);

    reg signed [7:0]  ff_iact;
    reg signed [7:0]  ff_weight;
    reg signed [15:0] ff_prod;
    reg signed [19:0] local_psum;

    // Stage 1: Input buffering
    always @(posedge clk) begin
        if (!rst_n) begin
            ff_iact   <= 8'd0;
            ff_weight <= 8'd0;
        end else begin
            ff_iact   <= iact_data_in;
            ff_weight <= weight_data_in;
        end
    end

    // Stage 2: Multiply
    always @(posedge clk) begin
        if (!rst_n) begin
            ff_prod <= 16'd0;
        end else begin
            ff_prod <= ff_iact * ff_weight;
        end
    end

    // Stage 3: Accumulate
    wire signed [19:0] accum_base = psum_mux_sel ? psum_in : local_psum;
    wire signed [19:0] sum = accum_base + ff_prod;

    always @(posedge clk) begin
        if (!rst_n) begin
            local_psum <= 20'd0;
        end else begin
            local_psum <= sum;
        end
    end

    assign psum_out = local_psum;

endmodule