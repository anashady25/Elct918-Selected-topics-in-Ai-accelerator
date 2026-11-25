`timescale 1ns / 1ps
module uart_rx #(parameter CLKS_PER_BIT = 868) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_in,
    output reg [7:0]  data_out,
    output reg        data_valid
);
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0] state;
    reg [9:0] clk_count;
    reg [2:0] bit_index;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            data_valid <= 1'b0;
            data_out <= 8'd0;
        end else begin
            // Pulse data_valid for exactly one clock cycle
            if (data_valid) data_valid <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_in == 1'b0) state <= START;
                end
                START: begin
                    // Wait to reach the middle of the start bit to sample safely
                    if (clk_count == (CLKS_PER_BIT / 2) - 1) begin
                        if (rx_in == 1'b0) begin
                            clk_count <= 0;
                            state <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                DATA: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        data_out[bit_index] <= rx_in;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            state <= STOP;
                        end
                    end
                end
                STOP: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        data_valid <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule