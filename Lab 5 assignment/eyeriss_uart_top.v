`timescale 1ns / 1ps

module eyeriss_uart_top (
    input  wire clk,
    input  wire rst_n,
    input  wire uart_rx,
    output wire uart_tx
);

    // UART RX Signals
    wire [7:0] rx_data;
    wire       rx_valid;
    
    // UART TX Signals
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    // PE Signals
    reg  [11:0] pe_iact;
    reg  [23:0] pe_weight;
    wire [39:0] pe_psum_out;
    reg         pe_csc_en;

    // State Machine Registers
    reg [2:0] rx_byte_count;
    reg [2:0] tx_byte_count;
    reg [39:0] tx_shift_reg;
    
    localparam IDLE = 0, WAIT_RX = 1, FIRE_PE = 2, SEND_TX = 3;
    reg [1:0] state;

    // Instantiate your Eyeriss PE
    eyeriss_v2_pe pe_inst (
        .clk(clk),
        .rst_n(rst_n),
        .iact_data_in(pe_iact),
        .weight_data_in(pe_weight),
        .psum_in(40'd0),          // Hardcoded to 0 for single-PE testing
        .csc_match_en(pe_csc_en),
        .psum_mux_sel(1'b0),      // Use local accumulation
        .psum_out(pe_psum_out)
    );

    // Instantiate standard UART RX and TX modules (Baud: 115200)
    uart_rx receiver (.clk(clk), .rst_n(rst_n), .rx(uart_rx), .data(rx_data), .valid(rx_valid));
endmodule
