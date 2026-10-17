`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/common/rr_arbiter.sv
// Module:      rr_arbiter
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Parameterized, starvation-free Round-Robin Arbiter for `N_REQ` requestors.
//
//   Why This Module Exists:
//     Multiple subsystems across `processor-complex` share a single downstream
//     channel and require fair, single-cycle combinational grant arbitration:
//       - `core_cbus_arb.sv` (`rtl/core/mem/core_cbus_arb.sv`) and
//         `soc_xbar.sv` (`rtl/interconnect/soc_xbar.sv`) arbitrate multiple
//         `cbus` masters onto shared slave ports.
//       - `l2_cache.sv` (M3/M6) arbitrates requests from `N_CORES` harts and
//         the JTAG System Bus Access master (`dm_sba.sv`).
//
//   Architecture & Operation:
//     - Maintains a rotating priority pointer or thermometer mask `mask_q` that
//       identifies requestors with higher priority than the most recently
//       granted requestor.
//     - Uses the dual-priority-encoder (masked vs. unmasked) technique:
//         1. `req_masked = req_i & mask_q`
//         2. If `|req_masked` is non-zero, grant the lowest-indexed bit in
//            `req_masked`.
//         3. Otherwise, grant the lowest-indexed bit in the raw `req_i` vector.
//     - When a grant is accepted (`ack_i && |req_i`), `mask_q` updates on the
//       rising clock edge to mask out the winning index `grant_idx_o` and all
//       lower indices, rotating highest priority to `(grant_idx_o + 1) % N_REQ`.
//
// Connections:
//   - Instantiated by:
//       * `core_cbus_arb.sv` (`rtl/core/mem/core_cbus_arb.sv`)
//       * `soc_xbar.sv` (`rtl/interconnect/soc_xbar.sv`)
//       * `l2_cache.sv` (`rtl/mem/l2_cache.sv` in M3+)
//
// What Needs to Be Implemented:
//   1. Implement the masked/unmasked priority selection logic producing
//      one-hot `grant_o`, binary index `grant_idx_o`, and `grant_valid_o`.
//   2. Implement the sequential priority mask register `mask_q` updated when
//      `ack_i && grant_valid_o` is asserted.
// =============================================================================

module rr_arbiter #(
    parameter int unsigned N_REQ = 2,
    parameter int unsigned IDX_W = (N_REQ > 1) ? $clog2(N_REQ) : 1
) (
    input  logic             clk_i,
    input  logic             rst_n_i,

    // Request vector (1 bit per requestor) and downstream acceptance strobe
    input  logic [N_REQ-1:0] req_i,
    input  logic             ack_i,

    // Arbitration outputs
    output logic             grant_valid_o,
    output logic [N_REQ-1:0] grant_o,
    output logic [IDX_W-1:0] grant_idx_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement thermometer priority mask `mask_q` and dual-priority-encoder
    //   round-robin selection logic.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign grant_valid_o = 1'b0;
    assign grant_o       = '0;
    assign grant_idx_o   = '0;

endmodule : rr_arbiter

