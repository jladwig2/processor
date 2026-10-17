`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/frontend/pc_gen.sv
// Module:      pc_gen
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Program Counter (PC) register and next-PC redirect priority multiplexer for
//   the instruction fetch stage (`frontend.sv`).
//
//   Why This Module Exists:
//     Separates next-PC selection and priority resolution from the instruction
//     memory request FSM. In any cycle, multiple pipeline stages may request a
//     control-flow redirect simultaneously; `pc_gen` enforces architectural
//     age order so older instructions always override younger speculative work.
//
//   Next-PC Priority Hierarchy (Highest to Lowest):
//     1. Hardware Reset (`!rst_n_i`):
//        - Initializes `pc_q <= RESET_PC` (`0x0000_1000` for Boot ROM or
//          `0x8000_0000` when overridden for bare-metal `riscv-tests`).
//     2. Commit / Trap / `mret` / `fence.i` Redirect (`trap_redirect_valid_i`):
//        - Originating from the oldest instruction in the pipeline (`commit.sv`
//          / `trap_ctrl.sv`). Redirects `pc_q <= trap_redirect_pc_i` (`mtvec`,
//          `mepc`, or `pc + 4` after `fence.i`).
//     3. Execute Branch/Jump Misprediction Redirect (`bru_redirect_valid_i`):
//        - Originating from `bru.sv` in Stage X when a conditional branch or
//          `jal`/`jalr` outcome disagrees with `pred_taken`/`pred_target`.
//          Redirects `pc_q <= bru_redirect_pc_i`.
//     4. Sequential / Predicted Fetch Advance (`fetch_step_i`):
//        - When the fetch engine launches a new instruction request and no
//          redirect is active, advances `pc_q <= bpu_pred_taken_i ?
//          bpu_pred_target_i : (pc_q + 32'd4)`.
//     5. Stall (`!fetch_step_i` and no redirect):
//        - Holds `pc_q` unchanged.
//
// Connections:
//   - Instantiated by: `frontend.sv` (`u_pc_gen`).
//   - Inputs:
//       * `trap_redirect_valid_i` / `trap_redirect_pc_i` <- `trap_ctrl.sv`
//       * `bru_redirect_valid_i`  / `bru_redirect_pc_i`  <- `bru.sv`
//       * `bpu_pred_taken_i`      / `bpu_pred_target_i`  <- `bpu.sv`
//       * `fetch_step_i`                                 <- `frontend.sv`
//   - Outputs:
//       * `pc_o` -> `frontend.sv` (current fetch PC) and `bpu.sv`
//
// What Needs to Be Implemented:
//   1. Implement the combinational next-PC priority multiplexer (`pc_d`).
//   2. Implement the 32-bit `pc_q` flip-flop reset to `RESET_PC` on `!rst_n_i`
//      and updated whenever a redirect is valid or `fetch_step_i` is asserted.
// =============================================================================

module pc_gen
    import soc_pkg::*;
#(
    parameter logic [31:0] RESET_ADDR = soc_pkg::RESET_PC
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    // Highest-priority redirect: Commit-stage Trap / MRET / FENCE.I (from trap_ctrl)
    input  logic        trap_redirect_valid_i,
    input  logic [31:0] trap_redirect_pc_i,

    // Second-priority redirect: Execute-stage Branch/Jump resolution (from bru)
    input  logic        bru_redirect_valid_i,
    input  logic [31:0] bru_redirect_pc_i,

    // Third-priority: Branch Predictor next-PC suggestion (from bpu)
    input  logic        bpu_pred_taken_i,
    input  logic [31:0] bpu_pred_target_i,

    // Fetch engine advance strobe (asserted when current PC request is accepted)
    input  logic        fetch_step_i,

    // Current Program Counter output
    output logic [31:0] pc_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement `pc_q` register (reset to `RESET_ADDR`) and priority mux `pc_d`
    //   (`trap_redirect` > `bru_redirect` > `fetch_step` BPU/PC+4 > hold).
    // -------------------------------------------------------------------------

    // Temporary stub tie-off
    assign pc_o = RESET_ADDR;

endmodule : pc_gen
