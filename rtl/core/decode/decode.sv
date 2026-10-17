`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/decode/decode.sv
// Module:      decode
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Logical Stage D (Instruction Decode) physical pipeline stage wrapper.
//   Accepts a fetched instruction packet (`fetch_pkt_t`) from `frontend.sv`,
//   decodes it into a canonical micro-op (`uop_t`) via `decoder_rv32.sv`, and
//   registers the result into the Stage D -> Stage I physical pipeline register
//   following the project's standardized valid/ready/flush handshake pattern.
//
//   Standardized Physical Pipeline Stage Contract:
//     - `fetch_ready_o = !dec_valid_q || issue_ready_i;`
//     - `step_en       = fetch_valid_i && fetch_ready_o;`
//     - `dec_valid_q` clears on `!rst_n_i` or `flush_i`, sets on `step_en`,
//       and clears when `issue_ready_i` drains the stage without a new arrival.
//     - `dec_uop_q` latches the combinational `dec_uop_d` from `decoder_rv32`
//       only when `step_en && !flush_i` (pure FDRE clock-enable, no reset).
//
// Connections:
//   - Instantiated by: `core.sv` (`u_decode`).
//   - Upstream (Stage F -> Stage D from `frontend.sv`):
//       * `fetch_valid_i`, `fetch_ready_o`, `fetch_pkt_i`
//   - Downstream (Stage D -> Stage I to `dispatch.sv`):
//       * `dec_valid_o`, `issue_ready_i`, `dec_uop_o`
//   - Control:
//       * `flush_i` <- `bru_redirect_valid || trap_redirect_valid`
//   - Child Module:
//       * `decoder_rv32 #(.HAS_MULDIV(HAS_MULDIV))` (`u_decoder_rv32`)
//
// What Needs to Be Implemented:
//   1. Instantiate `decoder_rv32` (`u_decoder_rv32`).
//   2. Implement the standardized physical pipeline stage (`dec_valid_q`,
//      `dec_uop_q`, `fetch_ready_o`, `step_en`).
// =============================================================================

module decode
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter bit HAS_MULDIV = 1'b1
) (
    input  logic       clk_i,
    input  logic       rst_n_i,

    // Pipeline flush (asserted on branch mispredict or commit trap/mret/fence.i)
    input  logic       flush_i,

    // Upstream Physical Pipeline Interface (from frontend.sv)
    input  logic       fetch_valid_i,
    output logic       fetch_ready_o,
    input  fetch_pkt_t fetch_pkt_i,

    // Downstream Physical Pipeline Interface (to dispatch.sv)
    output logic       dec_valid_o,
    input  logic       issue_ready_i,
    output uop_t       dec_uop_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Instantiate `decoder_rv32` (`u_decoder_rv32`).
    //   2. Implement the D -> I physical pipeline register (`dec_valid_q`,
    //      `dec_uop_q`) using the standard valid/ready/flush pattern.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign fetch_ready_o = 1'b0;
    assign dec_valid_o   = 1'b0;
    assign dec_uop_o     = '0;

endmodule : decode

