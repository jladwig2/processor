`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/common/fifo.sv
// Module:      fifo
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Parameterized Single-Clock Synchronous Circular FIFO Queue with first-word
//   fall-through (FWFT / combinational read data) semantics.
//
//   Why This Module Exists:
//     - Used throughout the SoC wherever producer and consumer rates differ
//       within the same clock domain:
//         * In M0: TX and RX byte queues inside `uart.sv` (`16 x 8b`).
//         * In M2: Command/data FIFO inside `qspi_ctrl.sv` and scan-code queue
//           in `ps2_hid.sv`.
//         * In M1/M4: Building block for fetch decoupling queues and store/write
//           buffers.
//
//   Protocol & Semantics:
//     - `DEPTH` must be a power of two (`DEPTH >= 2`).
//     - Write Interface (`push_i`, `wdata_i`, `full_o`):
//         * When `push_i && !full_o` on `posedge clk_i` (or `push_i && pop_i`
//           simultaneously when full, if bypass is supported; safest is gating
//           with `!full_o`), `wdata_i` is written at `wr_ptr` and `wr_ptr`
//           increments.
//     - Read Interface (`pop_i`, `rdata_o`, `empty_o`):
//         * `rdata_o` continuously presents the oldest entry at `rd_ptr`
//           (combinational read from distributed LUTRAM) whenever `!empty_o`.
//         * Pulsing `pop_i && !empty_o` on `posedge clk_i` advances `rd_ptr`
//           to the next entry.
//     - Pointer Tracking:
//         * Uses `(PTR_WIDTH + 1)`-bit read and write pointers (`PTR_WIDTH =
//           $clog2(DEPTH)`), where the MSB serves as the wrap bit:
//             - `empty_o = (wr_ptr == rd_ptr)`
//             - `full_o  = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) &&
//                          (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0])`
//             - `count_o = wr_ptr - rd_ptr`
//
// Connections:
//   - Instantiated by: `uart.sv` (`u_tx_fifo`, `u_rx_fifo`), and later by
//     `qspi_ctrl.sv` and `ps2_hid.sv`.
//
// What Needs to Be Implemented:
//   1. Declare storage array `logic [DATA_WIDTH-1:0] mem [0:DEPTH-1]` and
//      `(PTR_WIDTH+1)`-bit pointers `wr_ptr_q`, `rd_ptr_q`.
//   2. Implement synchronous reset and pointer update logic on `push_i && !full_o`
//      and `pop_i && !empty_o`.
//   3. Drive `rdata_o = mem[rd_ptr_q[PTR_WIDTH-1:0]]`, `empty_o`, `full_o`, and
//      `count_o`.
// =============================================================================

module fifo #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned DEPTH      = 16,
    parameter int unsigned CNT_WIDTH  = $clog2(DEPTH + 1)
) (
    input  logic                  clk_i,
    input  logic                  rst_n_i,

    // Synchronous clear (flushes pointers to empty)
    input  logic                  flush_i,

    // Write / Push Port
    input  logic                  push_i,
    input  logic [DATA_WIDTH-1:0] wdata_i,
    output logic                  full_o,

    // Read / Pop Port (First-Word Fall-Through: rdata_o is valid whenever !empty_o)
    input  logic                  pop_i,
    output logic [DATA_WIDTH-1:0] rdata_o,
    output logic                  empty_o,

    // Occupancy count (0 .. DEPTH)
    output logic [CNT_WIDTH-1:0]  count_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement circular buffer array `mem[0:DEPTH-1]`, wrap-bit read/write
    //   pointers `rd_ptr_q` and `wr_ptr_q`, and status flags `empty_o`,
    //   `full_o`, and `count_o`.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs (replace when implementing FIFO)
    assign full_o  = 1'b0;
    assign rdata_o = '0;
    assign empty_o = 1'b1;
    assign count_o = '0;

endmodule : fifo

