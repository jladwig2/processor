`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/execute/bru.sv
// Module:      bru
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Single-cycle Branch & Jump Resolution Unit (BRU) executing all RV32I
//   control-transfer instructions (`beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`,
//   `jal`, `jalr`) in Logical Stage X.
//
//   Architecture & Operation:
//     1. Condition Evaluation (`uop_i.bru_op`):
//        - `BRU_BEQ`:  `taken = (rs1_val_i == rs2_val_i)`
//        - `BRU_BNE`:  `taken = (rs1_val_i != rs2_val_i)`
//        - `BRU_BLT`:  `taken = ($signed(rs1_val_i) <  $signed(rs2_val_i))`
//        - `BRU_BGE`:  `taken = ($signed(rs1_val_i) >= $signed(rs2_val_i))`
//        - `BRU_BLTU`: `taken = (rs1_val_i <  rs2_val_i)`
//        - `BRU_BGEU`: `taken = (rs1_val_i >= rs2_val_i)`
//        - `BRU_JAL`:  `taken = 1'b1`
//        - `BRU_JALR`: `taken = 1'b1`
//     2. Target & Link Address Computation:
//        - Link Value (`link_pc_o`): `uop_i.pc + 32'd4` (written to `rd` for
//          `jal` and `jalr`).
//        - Target Address (`target_pc`):
//            * For `BRU_JALR`: `(rs1_val_i + uop_i.imm) & 32'hFFFF_FFFE`
//              (LSB cleared per RISC-V Unprivileged Spec §2.5).
//            * For `BRU_JAL` and conditional branches: `uop_i.pc + uop_i.imm`.
//        - Architectural Next PC (`arch_next_pc`):
//            * `taken ? target_pc : (uop_i.pc + 32'd4)`
//     3. 4-Byte Target Alignment Exception Check:
//        - Because the `C` (16-bit compressed) extension is not enabled, all
//          instruction addresses must be 4-byte aligned (`target_pc[1:0] == 2'b00`).
//        - If `valid_i && taken && (target_pc[1:0] != 2'b00)`:
//            * Raises `misaligned_exc_o = 1'b1` and `misaligned_tval_o = target_pc`.
//            * Suppresses `redirect_valid_o` so the faulting branch/jump flows
//              into Stage C (`commit.sv` / `trap_ctrl.sv`), where it takes a
//              precise `EXC_INSTR_ADDR_MISALIGNED` (`mcause = 0`, `mtval =
//              target_pc`) without writing `rd`!
//     4. Branch Misprediction Detection & Pipeline Redirect:
//        - Compares `(taken, arch_next_pc)` against the frontend prediction
//          `(uop_i.pred_taken, uop_i.pred_target)` carried in `uop_i`:
//            * `mispredicted = (taken != uop_i.pred_taken) ||
//                              (taken && (target_pc != uop_i.pred_target))`
//        - When `valid_i && !uop_i.exc_valid && !misaligned_exc_o && mispredicted`,
//          asserts `redirect_valid_o = 1'b1` and `redirect_pc_o = arch_next_pc`
//          to flush younger instructions in Stages F/D/I and redirect `pc_gen`.
//
// Connections:
//   - Instantiated by: `core.sv` (`u_bru`).
//   - Inputs:  `valid_i`, `uop_i`, `rs1_val_i`, `rs2_val_i`
//   - Outputs:
//       * `link_pc_o`                         -> Stage X result mux (`rd_wdata`)
//       * `misaligned_exc_o`, `misaligned_tval_o` -> Stage X -> C exception mux
//       * `redirect_valid_o`, `redirect_pc_o` -> `frontend.sv`, `decode.sv`, `dispatch.sv`
//       * `bpu_upd_*_o`                       -> `frontend.sv` (`bpu.sv` training in M5)
//
// What Needs to Be Implemented:
//   1. Implement branch comparator, `target_pc` adder, and `link_pc_o` adder.
//   2. Implement target 4-byte alignment check (`misaligned_exc_o`) and
//      misprediction redirect outputs (`redirect_valid_o`, `redirect_pc_o`).
// =============================================================================

module bru
    import rv_pkg::*;
    import core_pkg::*;
(
    // Asserted when the instruction in Stage X is valid and targets FU_BRU
    input  logic        valid_i,
    input  uop_t        uop_i,
    input  logic [31:0] rs1_val_i,
    input  logic [31:0] rs2_val_i,

    // Link address (`pc + 4`) for `jal` / `jalr` destination register writeback
    output logic [31:0] link_pc_o,

    // Target address misalignment exception (`EXC_INSTR_ADDR_MISALIGNED`)
    output logic        misaligned_exc_o,
    output logic [31:0] misaligned_tval_o,

    // Pipeline redirect outputs (to frontend, decode, dispatch)
    output logic        redirect_valid_o,
    output logic [31:0] redirect_pc_o,

    // Branch Predictor training outputs (to frontend -> bpu in M5+)
    output logic        bpu_upd_valid_o,
    output logic [31:0] bpu_upd_pc_o,
    output logic        bpu_upd_taken_o,
    output logic [31:0] bpu_upd_target_o,
    output logic        bpu_upd_is_call_o,
    output logic        bpu_upd_is_ret_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement branch condition evaluation, `target_pc` calculation, 4-byte
    //   alignment check (`misaligned_exc_o`), and `redirect_valid_o` generation.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign link_pc_o         = 32'h0;
    assign misaligned_exc_o  = 1'b0;
    assign misaligned_tval_o = 32'h0;
    assign redirect_valid_o  = 1'b0;
    assign redirect_pc_o     = 32'h0;
    assign bpu_upd_valid_o   = 1'b0;
    assign bpu_upd_pc_o      = 32'h0;
    assign bpu_upd_taken_o   = 1'b0;
    assign bpu_upd_target_o  = 32'h0;
    assign bpu_upd_is_call_o = 1'b0;
    assign bpu_upd_is_ret_o  = 1'b0;

endmodule : bru

