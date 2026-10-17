`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/frontend/fetch_queue.sv
// Module:      fetch_queue
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Elastic instruction fetch decoupling queue located at the output of
//   Logical Stage F (`frontend.sv`), feeding Logical Stage D (`decode.sv`).
//
//   Why This Module Exists:
//     - Decouples variable-latency instruction memory fetches (`cbus` / BRAM /
//       L1I cache misses) from downstream decode/issue stalls (`div.sv`,
//       `lsu.sv`).
//     - Wraps `fifo.sv` (`rtl/common/fifo.sv`) with our standardized physical
//       pipeline valid/ready/flush handshake interface transporting typed
//       `fetch_pkt_t` bundles (`{pc, insn, pred_taken, pred_target, exc_valid,
//       exc_cause}`).
//     - Supports single-cycle synchronous clearing (`flush_i`) whenever a
//       branch redirect (`bru_redirect_valid`) or trap/MRET/FENCE.I redirect
//       (`trap_redirect_valid`) occurs.
//
// Connections:
//   - Instantiated by: `frontend.sv` (`u_fetch_queue`).
//   - Upstream (from `frontend.sv` response capture logic):
//       * `in_valid_i`, `in_ready_o`, `in_pkt_i`
//   - Downstream (to `decode.sv` in `core.sv`):
//       * `out_valid_o`, `out_ready_i`, `out_pkt_o`
//   - Control:
//       * `flush_i` <- `bru_redirect_valid_i || trap_redirect_valid_i`
//   - Child Module:
//       * `fifo #(.DATA_WIDTH($bits(fetch_pkt_t)), .DEPTH(DEPTH))`
//         (`rtl/common/fifo.sv`)
//
// What Needs to Be Implemented:
//   1. Instantiate `fifo` parameterized to `$bits(fetch_pkt_t)` and `DEPTH`.
//   2. Map `in_ready_o = !fifo_full`, `push = in_valid_i && in_ready_o`,
//      `out_valid_o = !fifo_empty`, and `pop = out_valid_o && out_ready_i`.
// =============================================================================

module fetch_queue
    import core_pkg::*;
#(
    parameter int unsigned DEPTH = core_pkg::FETCH_Q_DEPTH
) (
    input  logic       clk_i,
    input  logic       rst_n_i,

    // Synchronous pipeline flush (branch mispredict or trap redirect)
    input  logic       flush_i,

    // Upstream Physical Pipeline Interface (from frontend fetch FSM)
    input  logic       in_valid_i,
    output logic       in_ready_o,
    input  fetch_pkt_t in_pkt_i,

    // Downstream Physical Pipeline Interface (to decode stage)
    output logic       out_valid_o,
    input  logic       out_ready_i,
    output fetch_pkt_t out_pkt_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Instantiate `fifo #(.DATA_WIDTH($bits(fetch_pkt_t)), .DEPTH(DEPTH))`
    //   and connect valid/ready/flush signals.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign in_ready_o  = 1'b0;
    assign out_valid_o = 1'b0;
    assign out_pkt_o   = '0;

endmodule : fetch_queue

