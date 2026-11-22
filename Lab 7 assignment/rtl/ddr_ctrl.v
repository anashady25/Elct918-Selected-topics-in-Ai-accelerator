`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// ddr_ctrl.v -- memory traffic controller (Tasks 1, 2 and 3)
//
// Drives an SRAM-style memory port (active-low CEN / WEN / OEN, word address)
// with the 4-phase handshake on mem_ack -- no fixed wait times:
//   1. SETUP : drive address / write data with CEN, WEN, OEN high; wait at
//              least GAP cycles AND until mem_ack is low (previous access done)
//   2.         pull CEN low together with WEN (write) or OEN (read)
//   3. ACCESS: wait until mem_ack is high; for a read, sample mem_q now
//   4.         release CEN/WEN/OEN and go back to SETUP for the next word
//
// The same controller drives
//   * the DDR2 through ram2ddr (mem_ack = 2-flop synchronized ram_ack_o, GAP=4)
//   * the block RAM through a 1-cycle ack adapter (GAP=0)
//
// Modes (sampled when 'start' first goes high, re-armed by rst):
//   MODE_TEST       write pass over [a_start, a_end], read pass, count
//                   mismatches, then stop in DONE            (Tasks 1 and 2)
//   MODE_LOOP_WRITE write pass, forever                       (Task 3)
//   MODE_LOOP_READ  one write pass (prefill), then read passes forever,
//                   still counting mismatches                 (Task 3)
//
// Data patterns (pat_sel):
//   0 PAT_ADDR  address hash: catches stuck / aliased address bits
//   1 PAT_ZERO  all zeros
//   2 PAT_ONES  all ones
//   3 PAT_ALT   all zeros / all ones on alternate words
//   4 PAT_5A    0x5555... / 0xAAAA... on alternate words
//   5 PAT_LFSR  pseudo-random (32-bit LFSR, restarted every pass)
//   6,7         same as PAT_LFSR
//
// Bandwidth: wr_cycles / rd_cycles hold the clk cycles of the last complete
// write / read pass (first SETUP cycle up to and including the last ack).
// -----------------------------------------------------------------------------
module ddr_ctrl #(
    parameter integer DATA_W  = 16,          // <= 32
    parameter integer ADDR_W  = 26,          // word address width
    parameter integer GAP     = 4,           // setup cycles before CEN falls
    parameter integer CNT_W   = 40,          // cycle counter width
    parameter integer TMO_W   = 16           // access timeout = 2^TMO_W - 1 cycles
)(
    input  wire              clk,
    input  wire              rst,            // synchronous, active high
    input  wire              start,          // e.g. calibration complete
    input  wire [1:0]        mode,
    input  wire [2:0]        pat_sel,
    input  wire [ADDR_W-1:0] a_start,        // first word address
    input  wire [ADDR_W-1:0] a_end,          // last word address (inclusive)

    // SRAM-style memory port
    output reg  [ADDR_W-1:0] mem_a,
    output reg  [DATA_W-1:0] mem_d,
    input  wire [DATA_W-1:0] mem_q,
    output reg               mem_cen,
    output reg               mem_wen,
    output reg               mem_oen,
    input  wire              mem_ack,        // must already be in clk domain

    // status
    output reg  [2:0]        state,
    output reg  [ADDR_W:0]   errors,         // saturating mismatch count
    output reg  [CNT_W-1:0]  wr_cycles,
    output reg  [CNT_W-1:0]  rd_cycles,
    output reg  [15:0]       passes          // completed passes (wraps)
);

    localparam [1:0] MODE_TEST       = 2'd0,
                     MODE_LOOP_WRITE = 2'd1,
                     MODE_LOOP_READ  = 2'd2;

    localparam [2:0] PAT_ADDR = 3'd0,
                     PAT_ZERO = 3'd1,
                     PAT_ONES = 3'd2,
                     PAT_ALT  = 3'd3,
                     PAT_5A   = 3'd4;

    localparam [2:0] S_IDLE     = 3'd0,
                     S_W_SETUP  = 3'd1,
                     S_W_ACCESS = 3'd2,
                     S_R_SETUP  = 3'd3,
                     S_R_ACCESS = 3'd4,
                     S_DONE     = 3'd5,
                     S_TIMEOUT  = 3'd6;

    // ------------------------------------------------------------------ registers
    reg  [1:0]        mode_r;
    reg  [2:0]        pat_r;
    reg  [ADDR_W-1:0] addr;
    reg  [ADDR_W-1:0] a_start_r, a_end_r;
    reg  [CNT_W-1:0]  cyc;
    reg  [TMO_W-1:0]  cnt;
    wire [31:0]       lfsr_q;

    wire last = (addr == a_end_r);
    wire tmo  = &cnt;

    // the LFSR holds the current word's value during SETUP and ACCESS, steps
    // on the accepting ack and restarts at the beginning of every pass
    wire acked     = ((state == S_W_ACCESS) || (state == S_R_ACCESS)) && mem_ack;
    wire lfsr_load = ((state == S_IDLE) && start) || (acked && last);
    wire lfsr_step = acked && !last;

    lfsr #(.W(32)) u_lfsr (
        .clk  (clk),
        .rst  (rst),
        .load (lfsr_load),
        .en   (lfsr_step),
        .q    (lfsr_q)
    );

    // ------------------------------------------------------------------ pattern
    wire [31:0] a32  = {{(32-ADDR_W){1'b0}}, addr};
    wire [31:0] hash = a32 ^ {a32[15:0], a32[31:16]} ^ 32'h5A3C_96E1;

    reg  [31:0] pat32;
    always @(*) begin
        case (pat_r)
            PAT_ADDR: pat32 = hash;
            PAT_ZERO: pat32 = 32'h0000_0000;
            PAT_ONES: pat32 = 32'hFFFF_FFFF;
            PAT_ALT:  pat32 = addr[0] ? 32'hFFFF_FFFF : 32'h0000_0000;
            PAT_5A:   pat32 = addr[0] ? 32'hAAAA_AAAA : 32'h5555_5555;
            default:  pat32 = lfsr_q;
        endcase
    end
    wire [DATA_W-1:0] pattern = pat32[DATA_W-1:0];

    // ------------------------------------------------------------------ FSM
    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            mode_r    <= MODE_TEST;
            pat_r     <= PAT_ADDR;
            addr      <= {ADDR_W{1'b0}};
            a_start_r <= {ADDR_W{1'b0}};
            a_end_r   <= {ADDR_W{1'b0}};
            cyc       <= {CNT_W{1'b0}};
            cnt       <= {TMO_W{1'b0}};
            errors    <= {(ADDR_W+1){1'b0}};
            wr_cycles <= {CNT_W{1'b0}};
            rd_cycles <= {CNT_W{1'b0}};
            passes    <= 16'd0;
            mem_a     <= {ADDR_W{1'b0}};
            mem_d     <= {DATA_W{1'b0}};
            mem_cen   <= 1'b1;
            mem_wen   <= 1'b1;
            mem_oen   <= 1'b1;
        end else begin
            case (state)

            S_IDLE: begin
                if (start) begin
                    mode_r    <= mode;
                    pat_r     <= pat_sel;
                    a_start_r <= a_start;
                    a_end_r   <= a_end;
                    addr      <= a_start;
                    cyc       <= {CNT_W{1'b0}};
                    cnt       <= {TMO_W{1'b0}};
                    state     <= S_W_SETUP;
                end
            end

            // ---------------------------------------------------------- write
            S_W_SETUP: begin
                cyc     <= cyc + 1'b1;
                mem_a   <= addr;
                mem_d   <= pattern;
                mem_cen <= 1'b1;
                mem_wen <= 1'b1;
                mem_oen <= 1'b1;
                if (cnt >= GAP && !mem_ack) begin
                    cnt     <= {TMO_W{1'b0}};
                    mem_cen <= 1'b0;
                    mem_wen <= 1'b0;
                    state   <= S_W_ACCESS;
                end else if (tmo)
                    state <= S_TIMEOUT;
                else
                    cnt <= cnt + 1'b1;
            end

            S_W_ACCESS: begin
                cyc <= cyc + 1'b1;
                if (mem_ack) begin
                    mem_cen   <= 1'b1;
                    mem_wen   <= 1'b1;
                    cnt       <= {TMO_W{1'b0}};
                    if (last) begin
                        wr_cycles <= cyc + 1'b1;
                        passes    <= passes + 1'b1;
                        cyc       <= {CNT_W{1'b0}};
                        addr      <= a_start_r;
                        state     <= (mode_r == MODE_LOOP_WRITE) ? S_W_SETUP : S_R_SETUP;
                    end else begin
                        addr  <= addr + 1'b1;
                        state <= S_W_SETUP;
                    end
                end else if (tmo)
                    state <= S_TIMEOUT;
                else
                    cnt <= cnt + 1'b1;
            end

            // ---------------------------------------------------------- read
            S_R_SETUP: begin
                cyc     <= cyc + 1'b1;
                mem_a   <= addr;
                mem_cen <= 1'b1;
                mem_wen <= 1'b1;
                mem_oen <= 1'b1;
                if (cnt >= GAP && !mem_ack) begin
                    cnt     <= {TMO_W{1'b0}};
                    mem_cen <= 1'b0;
                    mem_oen <= 1'b0;
                    state   <= S_R_ACCESS;
                end else if (tmo)
                    state <= S_TIMEOUT;
                else
                    cnt <= cnt + 1'b1;
            end

            S_R_ACCESS: begin
                cyc <= cyc + 1'b1;
                if (mem_ack) begin
                    mem_cen   <= 1'b1;
                    mem_oen   <= 1'b1;
                    cnt       <= {TMO_W{1'b0}};
                    if (mem_q != pattern && !(&errors))
                        errors <= errors + 1'b1;
                    if (last) begin
                        rd_cycles <= cyc + 1'b1;
                        passes    <= passes + 1'b1;
                        cyc       <= {CNT_W{1'b0}};
                        addr      <= a_start_r;
                        state     <= (mode_r == MODE_LOOP_READ) ? S_R_SETUP : S_DONE;
                    end else begin
                        addr  <= addr + 1'b1;
                        state <= S_R_SETUP;
                    end
                end else if (tmo)
                    state <= S_TIMEOUT;
                else
                    cnt <= cnt + 1'b1;
            end

            S_DONE: ;                           // results held until rst

            S_TIMEOUT: begin                    // an access never got its ack
                mem_cen <= 1'b1;
                mem_wen <= 1'b1;
                mem_oen <= 1'b1;
            end

            default: state <= S_IDLE;
            endcase
        end
    end

endmodule
