`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/lsu/agu.sv
// Module:      agu
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Combinational Address Generation Unit (AGU) for the Load-Store Unit
//   (`lsu.sv`). Computes the 32-bit effective byte address (`rs1_val_i + imm_i`),
//   the last byte address touched by the transfer (for boundary-crossing PMA
//   checks), natural alignment status, and whether the transfer crosses a
//   32-bit word boundary.
//
//   Alignment & Word-Boundary Rules:
//     1. Natural Misalignment (`is_misaligned_o`):
//        - `LSU_BYTE`: Never misaligned (`1'b0`)
//        - `LSU_HALF`: Misaligned if `eff_addr_o[0] != 1'b0`
//        - `LSU_WORD`: Misaligned if `eff_addr_o[1:0] != 2'b00`
//        Used by `lsu.sv` to raise `EXC_LOAD_ADDR_MISALIGNED` (4) or
//        `EXC_STORE_ADDR_MISALIGNED` (6) when accessing non-idempotent MMIO
//        regions (or AMO/LR/SC in M6).
//     2. 32-Bit Word Boundary Crossing (`crosses_word_o`):
//        - True when the access spans two consecutive 32-bit aligned words:
//            * `LSU_HALF` at byte offset `2'b11`
//            * `LSU_WORD` at byte offset `2'b01`, `2'b10`, or `2'b11`
//        Used by `misalign.sv` / `lsu.sv` to determine whether the access must
//        be split into two back-to-back 32-bit `cbus` transfers.
//     3. End Byte Address (`last_byte_addr_o`):
//        - `eff_addr_o` (`LSU_BYTE`), `eff_addr_o + 32'd1` (`LSU_HALF`), or
//          `eff_addr_o + 32'd3` (`LSU_WORD`). Checked by a second `pma.sv`
//          instance so a misaligned access that straddles the boundary between
//          valid RAM and an unmapped/MMIO/ROM region faults before issuing!
//
// Connections:
//   - Instantiated by: `lsu.sv` (`u_agu`).
//   - Inputs:  `rs1_val_i`, `imm_i`, `lsu_size_i`
//   - Outputs: `eff_addr_o`, `last_byte_addr_o`, `is_misaligned_o`, `crosses_word_o`
//
// What Needs to Be Implemented:
//   1. Compute `eff_addr_o = rs1_val_i + imm_i` and `last_byte_addr_o`.
//   2. Compute `is_misaligned_o` and `crosses_word_o` from `lsu_size_i` and
//      `eff_addr_o[1:0]`.
// =============================================================================

module agu
    import rv_pkg::*;
    import core_pkg::*;
(
    input  logic [31:0] rs1_val_i,
    input  logic [31:0] imm_i,
    input  lsu_size_e   lsu_size_i,

    output logic [31:0] eff_addr_o,
    output logic [31:0] last_byte_addr_o,
    output logic        is_misaligned_o,
    output logic        crosses_word_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement `eff_addr_o`, `last_byte_addr_o`, `is_misaligned_o`, and
    //   `crosses_word_o` combinational logic.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign eff_addr_o       = 32'h0;
    assign last_byte_addr_o = 32'h0;
    assign is_misaligned_o  = 1'b0;
    assign crosses_word_o   = 1'b0;

endmodule : agu

