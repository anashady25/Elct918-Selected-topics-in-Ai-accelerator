`timescale 1ns / 1ps

module top_system (
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rx,
    output wire uart_tx
);

    // UART Signals
    wire [7:0] rx_byte;
    wire       rx_valid;
    reg  [7:0] tx_byte;
    reg        tx_start;
    wire       tx_busy;

    // PE Signals
    reg  [11:0] pe_iact;
    reg  [23:0] pe_weight;
    reg  [39:0] pe_psum_in;
    reg         pe_csc_en;
    reg         pe_mux_sel;
    reg         pe_clear;       // <-- DECLARED HERE
    wire [39:0] pe_psum_out;

    // Shift registers for packing/unpacking
    reg [79:0] rx_buffer;
    reg [39:0] tx_buffer;
    reg [3:0]  rx_count;
    reg [2:0]  tx_count;
    reg [2:0]  pipeline_wait;

    localparam IDLE = 0, UNPACK = 1, WAIT_PE = 2, SEND_TX = 3;
    reg [1:0] state;

    uart_rx #(.CLKS_PER_BIT(868)) u_rx (.clk(clk), .rst_n(rst_n), .rx_in(uart_rx), .data_out(rx_byte), .data_valid(rx_valid));
    uart_tx #(.CLKS_PER_BIT(868)) u_tx (.clk(clk), .rst_n(rst_n), .tx_start(tx_start), .data_in(tx_byte), .tx_out(uart_tx), .tx_busy(tx_busy));
    
    eyeriss_v2_pe u_pe (
        .clk(clk), .rst_n(rst_n), .iact_data_in(pe_iact), .weight_data_in(pe_weight),
        .psum_in(pe_psum_in), .csc_match_en(pe_csc_en), .psum_mux_sel(pe_mux_sel), // <-- WIRED TO PE HERE
        .psum_out(pe_psum_out)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            rx_count <= 0;
            tx_start <= 0;
        end else begin
            tx_start <= 0; // Default to not sending

            case (state)
                IDLE: begin
                    if (rx_valid) begin
                        // Shift incoming byte into the history buffer
                        rx_buffer <= {rx_buffer[71:0], rx_byte};
                        
                        if (rx_count == 9) begin
                            rx_count <= 0;
                            // Move to UNPACK to wait 1 cycle for rx_buffer to physically update
                            state <= UNPACK; 
                        end else begin
                            rx_count <= rx_count + 1;
                        end
                    end
                end
                
                UNPACK: begin
                    // Sequence complete: slice the fully updated 80-bit buffer
                    pe_iact    <= rx_buffer[11:0];
                    pe_weight  <= rx_buffer[35:12];
                    pe_psum_in <= rx_buffer[75:36];
                    pe_csc_en  <= rx_buffer[76];
                    pe_mux_sel <= rx_buffer[77];
                    pe_clear   <= rx_buffer[78];
                    
                    pipeline_wait <= 0;
                    state <= WAIT_PE;
                end
                
                WAIT_PE: begin
                    // Hold for the PE's 3-cycle pipeline delay + accumulation
                    if (pipeline_wait < 5) begin
                        pipeline_wait <= pipeline_wait + 1;
                    end else begin
                        tx_buffer <= pe_psum_out;
                        tx_count <= 0;
                        state <= SEND_TX;
                    end
                end
                
                SEND_TX: begin
                    if (!tx_busy && !tx_start) begin
                        if (tx_count < 5) begin
                            // Shift out the highest byte
                            tx_byte <= tx_buffer[39:32];
                            tx_buffer <= {tx_buffer[31:0], 8'd0};
                            tx_start <= 1;
                            tx_count <= tx_count + 1;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end
endmodule