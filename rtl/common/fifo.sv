`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/common/fifo.sv
// Module:      fifo
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Parameterized synchronous First-In-First-Out (FIFO) circular queue with
//   registered/distributed storage and support for synchronous pipeline flush
//   (`flush_i`).
//
//   Why This Module Exists:
//     Used throughout the processor complex wherever elastic valid/ready
//     buffering is required within a single clock domain:
//       - In `fetch_queue.sv` (`rtl/core/frontend/fetch_queue.sv`) to decouple
//         the instruction fetch unit (`frontend.sv`) from `decode.sv` and
//         collapse fetch bubbles.
//       - In `uart.sv` (`rtl/periph/uart.sv`) as the 16-entry × 8-bit TX and
//         RX byte queues (`u_tx_fifo`, `u_rx_fifo`).
//       - In `qspi_ctrl.sv` and `ps2_hid.sv` (M2) for command/data buffering.
//
//   Architecture & Operation:
//     - Maintains `(PTR_WIDTH + 1)`-bit read and write pointers (`rptr_q`,
//       `wptr_q`), where the lower `PTR_WIDTH = $clog2(DEPTH)` bits index the
//       storage array `mem_q[0:DEPTH-1]` and the MSB tracks wrap-around parity:
//         * `empty_o = (wptr_q == rptr_q)`
//         * `full_o  = (wptr_q[PTR_WIDTH] != rptr_q[PTR_WIDTH]) &&
//                      (wptr_q[PTR_WIDTH-1:0] == rptr_q[PTR_WIDTH-1:0])`
//     - Simultaneous push and pop (`push_i && pop_i`) when neither empty nor
//       full (or when full if fall-through / simultaneous drain is enabled)
//       advances both pointers cleanly in the same clock cycle.
//     - Asserting `flush_i` synchronously resets `wptr_q`, `rptr_q`, and
//       `count_o` to zero on the next rising clock edge without requiring a
//       hardware reset pulse (critical for branch misprediction and trap
//       flushes in `fetch_queue.sv`).
//
// Connections:
//   - Instantiated by:
//       * `fetch_queue.sv` (`rtl/core/frontend/fetch_queue.sv`)
//       * `uart.sv` (`rtl/periph/uart.sv`)
//
// What Needs to Be Implemented:
//   1. Declare storage array `logic [DATA_WIDTH-1:0] mem_q [0:DEPTH-1]` and
//      `(PTR_WIDTH+1)`-bit read/write pointers `rptr_q`, `wptr_q`.
//   2. Implement combinational `empty_o`, `full_o`, `count_o`, and combinational
//      head read `rdata_o = mem_q[rptr_q[PTR_WIDTH-1:0]]`.
//   3. Implement sequential pointer updates on `clk_i` with priority:
//      `!rst_n_i` -> `flush_i` -> `do_push` / `do_pop`, writing `wdata_i` into
//      `mem_q[wptr_q[PTR_WIDTH-1:0]]` when `do_push` is active.
// =============================================================================

module fifo #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned DEPTH      = 4,
    parameter int unsigned CNT_WIDTH  = $clog2(DEPTH + 1)
) (
    input  logic                  clk_i,
    input  logic                  rst_n_i,

    // Synchronous clear (resets pointers to empty on branch/trap flush)
    input  logic                  flush_i,

    // Write / Push Interface (Upstream)
    input  logic                  push_i,
    input  logic [DATA_WIDTH-1:0] wdata_i,
    output logic                  full_o,

    // Read / Pop Interface (Downstream, First-Word-Fall-Through)
    input  logic                  pop_i,
    output logic [DATA_WIDTH-1:0] rdata_o,
    output logic                  empty_o,

    // Occupancy status
    output logic [CNT_WIDTH-1:0]  count_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement circular buffer storage array `mem_q`, `(PTR_WIDTH+1)`-bit
    //   pointers `wptr_q`/`rptr_q`, `flush_i` synchronous clear, and FWFT read
    //   output `rdata_o`.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign full_o  = 1'b0;
    assign rdata_o = '0;
    assign empty_o = 1'b1;
    assign count_o = '0;

endmodule : fifo
