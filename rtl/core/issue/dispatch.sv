`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/issue/dispatch.sv
// Module:      dispatch
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Logical Stage I (Issue / Scoreboard / Operand Latch) physical pipeline
//   stage wrapper.
//
//   Architecture Across Milestones:
//     - In Milestone 1 (M1): Implements the single-issue in-order Issue &
//       Operand Read stage:
//         1. Drives `prf_rs1_addr_o` and `prf_rs2_addr_o` to `prf.sv` and
//            instantiates `bypass.sv` (`u_bypass`) to resolve `rs1_val` and
//            `rs2_val` with zero-cycle forwarding from Stage X and Stage C.
//         2. Enforces serialization for system/CSR/fence.i/trap instructions
//            (`dec_uop_i.is_serializing || dec_uop_i.exc_valid`): if a
//            serializing instruction arrives from Decode, it waits until both
//            Stage X (`issue_valid_q`) and Stage C (`wb_valid_i`) have drained
//            before stepping into Stage X. Similarly, if a serializing
//            instruction is currently in Stage X or Stage C, younger
//            instructions wait in Decode until it retires.
//         3. Enforces RAW hazard interlocking if an older instruction currently
//            in Stage X has not yet produced its result (`issue_valid_q &&
//            issue_uop_q.rd_wen && !ex_fwd_valid_i`) and the incoming instruction
//            reads that destination register.
//         4. Registers the ready micro-op and its resolved 32-bit operands
//            (`issue_uop_q`, `issue_rs1_val_q`, `issue_rs2_val_q`) into the
//            Stage I -> Stage X physical pipeline register following the
//            standardized valid/ready/flush contract.
//     - In Milestone 4 (M4): Routes 2-wide renamed micro-ops from `rename.sv`
//       into the distributed `issue_queue.sv` units (`ALU0`, `ALU1`, `MEM`,
//       `MULDIV/CSR`) and `rob.sv`.
//
// Connections:
//   - Instantiated by: `core.sv` (`u_dispatch`).
//   - Upstream (Stage D -> Stage I from `decode.sv`):
//       * `dec_valid_i`, `dec_ready_o`, `dec_uop_i`
//   - Register File & Forwarding Taps:
//       * `prf_rs1_addr_o`, `prf_rs2_addr_o`, `prf_rs1_data_i`, `prf_rs2_data_i` <-> `prf.sv`
//       * `ex_fwd_valid_i`, `ex_fwd_rd_i`, `ex_fwd_data_i` <- Stage X
//       * `wb_fwd_valid_i`, `wb_fwd_rd_i`, `wb_fwd_data_i`, `wb_valid_i`, `wb_serializing_i` <- Stage C
//   - Downstream (Stage I -> Stage X to Execute units in `core.sv`):
//       * `issue_valid_o`, `ex_ready_i`, `issue_uop_o`, `issue_rs1_val_o`, `issue_rs2_val_o`
//   - Control:
//       * `flush_i` <- `bru_redirect_valid || trap_redirect_valid`
//   - Child Module:
//       * `bypass.sv` (`u_bypass`)
//
// What Needs to Be Implemented:
//   1. Instantiate `bypass` (`u_bypass`) to resolve `rs1_val_d` and `rs2_val_d`.
//   2. Compute `hazard_stall` (when an older instruction in Stage X writes a
//      register read by `dec_uop_i` and `!ex_fwd_valid_i`, or when a
//      serializing instruction is in flight).
//   3. Implement the standardized Stage I -> Stage X physical pipeline register
//      (`issue_valid_q`, `issue_uop_q`, `issue_rs1_val_q`, `issue_rs2_val_q`).
// =============================================================================

module dispatch
    import rv_pkg::*;
    import core_pkg::*;
(
    input  logic                   clk_i,
    input  logic                   rst_n_i,

    // Pipeline flush (branch mispredict or commit trap/mret/fence.i)
    input  logic                   flush_i,

    // Upstream Physical Pipeline Interface (from decode.sv)
    input  logic                   dec_valid_i,
    output logic                   dec_ready_o,
    input  uop_t                   dec_uop_i,

    // Physical Register File Read Interface (to/from prf.sv)
    output logic [PRF_ADDR_W-1:0]  prf_rs1_addr_o,
    output logic [PRF_ADDR_W-1:0]  prf_rs2_addr_o,
    input  logic [31:0]            prf_rs1_data_i,
    input  logic [31:0]            prf_rs2_data_i,

    // Forwarding & Status from Stage X (Execute)
    input  logic                   ex_fwd_valid_i,
    input  logic [PRF_ADDR_W-1:0]  ex_fwd_rd_i,
    input  logic [31:0]            ex_fwd_data_i,

    // Forwarding & Status from Stage C (Commit / Writeback)
    input  logic                   wb_valid_i,
    input  logic                   wb_serializing_i,
    input  logic                   wb_fwd_valid_i,
    input  logic [PRF_ADDR_W-1:0]  wb_fwd_rd_i,
    input  logic [31:0]            wb_fwd_data_i,

    // Downstream Physical Pipeline Interface (Stage I -> Stage X)
    output logic                   issue_valid_o,
    input  logic                   ex_ready_i,
    output uop_t                   issue_uop_o,
    output logic [31:0]            issue_rs1_val_o,
    output logic [31:0]            issue_rs2_val_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Instantiate `bypass` (`u_bypass`).
    //   2. Implement RAW hazard and serialization interlock (`hazard_stall`).
    //   3. Implement Stage I -> Stage X physical pipeline register (`issue_valid_q`,
    //      `issue_uop_q`, `issue_rs1_val_q`, `issue_rs2_val_q`).
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign dec_ready_o     = 1'b0;
    assign prf_rs1_addr_o  = '0;
    assign prf_rs2_addr_o  = '0;
    assign issue_valid_o   = 1'b0;
    assign issue_uop_o     = '0;
    assign issue_rs1_val_o = 32'h0;
    assign issue_rs2_val_o = 32'h0;

endmodule : dispatch

