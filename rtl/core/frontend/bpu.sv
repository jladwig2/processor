`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/frontend/bpu.sv
// Module:      bpu
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Branch Prediction Unit (BPU) top-level wrapper for the instruction fetch
//   stage (`frontend.sv`).
//
//   Architecture Across Milestones:
//     - In Milestone 1 (M1): Operates as a zero-overhead static
//       predict-not-taken predictor:
//         * `pred_taken_o  = 1'b0`
//         * `pred_target_o = pc_i + 32'd4`
//       All taken branches and jumps (`jal`, `jalr`, taken `beq`..`bgeu`) are
//       resolved in Stage X by `bru.sv` and redirected via
//       `bru_redirect_valid_i`.
//     - In Milestone 5 (M5): Instantiates `l0_btb.sv` (16-entry 1-cycle next-
//       line predictor), `bp_btb.sv` (512-entry 2-way BTB), `bp_gshare.sv`
//       (4K × 2-bit counter table with 12-bit GHR), and `bp_ras.sv` (16-entry
//       Return Address Stack) behind this exact same module interface so
//       `frontend.sv` and `bru.sv` require no port changes.
//
// Connections:
//   - Instantiated by: `frontend.sv` (`u_bpu`).
//   - Query Interface (Stage F):
//       * `pc_i`          <- `pc_gen.sv` (`pc_o`)
//       * `pred_taken_o`  -> `pc_gen.sv` and `frontend.sv` (`fetch_pkt_t`)
//       * `pred_target_o` -> `pc_gen.sv` and `frontend.sv` (`fetch_pkt_t`)
//   - Update Interface (Stage X from `bru.sv`, used in M5):
//       * `upd_valid_i`, `upd_pc_i`, `upd_taken_i`, `upd_target_i`,
//         `upd_is_call_i`, `upd_is_ret_i`
//
// What Needs to Be Implemented:
//   1. For M1: Drive `pred_taken_o = 1'b0` and `pred_target_o = pc_i + 32'd4`.
//   2. For M5: Instantiate `l0_btb`, `bp_btb`, `bp_gshare`, and `bp_ras`.
// =============================================================================

module bpu (
    input  logic        clk_i,
    input  logic        rst_n_i,

    // Fetch-stage prediction query (from pc_gen)
    input  logic [31:0] pc_i,
    output logic        pred_taken_o,
    output logic [31:0] pred_target_o,

    // Execute-stage predictor update / training (from bru, used in M5+)
    input  logic        upd_valid_i,
    input  logic [31:0] upd_pc_i,
    input  logic        upd_taken_i,
    input  logic [31:0] upd_target_i,
    input  logic        upd_is_call_i,
    input  logic        upd_is_ret_i
);

    // -------------------------------------------------------------------------
    // M1 Static Predict-Not-Taken Implementation
    // (In M5, replace with L0-BTB + BTB + GShare + RAS sub-modules)
    // -------------------------------------------------------------------------
    assign pred_taken_o  = 1'b0;
    assign pred_target_o = pc_i + 32'd4;

endmodule : bpu

