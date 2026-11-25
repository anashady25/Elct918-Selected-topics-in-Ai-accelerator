`timescale 1ns / 1ps
module uart_tx #(parameter CLKS_PER_BIT = 868) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] data_in,
    output reg        tx_out,
    output reg        tx_busy
);
    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0]  state;
    reg [9:0]  clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  tx_data;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            tx_out <= 1'b1;
            tx_busy <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx_out <= 1'b1;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_start) begin
                        tx_data <= data_in;
                        tx_busy <= 1'b1;
                        state <= START;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end
                START: begin
                    tx_out <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= DATA;
                    end
                end
                DATA: begin
                    tx_out <= tx_data[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            state <= STOP;
                        end
                    end
                end
                STOP: begin
                    tx_out <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule