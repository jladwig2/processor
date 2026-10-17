`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/issue/bypass.sv
// Module:      bypass
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Combinational Operand Forwarding (Bypass) Network located in Logical Stage I
//   (`dispatch.sv`) immediately ahead of the Stage I -> Stage X physical
//   pipeline registers.
//
//   Why This Module Exists & Placement Rationale:
//     - Eliminates Read-After-Write (RAW) data hazard stalls between back-to-back
//       instructions by intercepting results from older instructions currently
//       completing in Stage X (`ex_fwd_*`) or awaiting retirement in Stage C
//       (`wb_fwd_*`) before they are written back to `prf.sv`.
//     - By resolving forwarding in Stage I and latching the resolved 32-bit
//       operands (`rs1_val_o`, `rs2_val_o`) into the Stage I -> Stage X
//       pipeline flip-flops, all Execute functional units (`alu.sv`, `bru.sv`,
//       `agu.sv`, `mul.sv`) receive their inputs directly from registers
//       without a 3:1 bypass mux in series with the 32-bit carry chains!
//
//   Forwarding Priority Hierarchy (for both `rs1` and `rs2`):
//     1. Register `x0` (`rs_addr_i == '0`):
//        - Always resolves to `32'h0000_0000`.
//     2. Stage X Forwarding (`ex_fwd_valid_i && (ex_fwd_rd_i == rs_addr_i)`):
//        - Highest priority because the instruction in Stage X is younger than
//          the instruction in Stage C (most recent writer of `rs_addr_i`).
//     3. Stage C / Writeback Forwarding (`wb_fwd_valid_i && (wb_fwd_rd_i == rs_addr_i)`):
//        - Second priority when the instruction in Stage X does not write the
//          requested register, but the instruction in Stage C does.
//     4. Physical Register File (`prf_rs_data_i`):
//        - Default architectural value read from `prf.sv` (which already
//          includes same-cycle commit write-through).
//
// Connections:
//   - Instantiated by: `dispatch.sv` (`u_bypass`).
//   - Inputs:
//       * `rs1_addr_i`, `rs2_addr_i`             <- `dispatch.sv` (`dec_uop_i`)
//       * `prf_rs1_data_i`, `prf_rs2_data_i`     <- `prf.sv`
//       * `ex_fwd_valid_i`, `ex_fwd_rd_i`, `ex_fwd_data_i` <- `core.sv` (Stage X completion)
//       * `wb_fwd_valid_i`, `wb_fwd_rd_i`, `wb_fwd_data_i` <- `core.sv` (Stage C register)
//   - Outputs:
//       * `rs1_val_o`, `rs2_val_o`               -> `dispatch.sv` (latched into I -> X stage)
//
// What Needs to Be Implemented:
//   1. Implement the priority multiplexers for `rs1_val_o` and `rs2_val_o`
//      following the 4-level priority hierarchy above.
// =============================================================================

module bypass
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter int unsigned ADDR_W = core_pkg::PRF_ADDR_W
) (
    // Source register addresses requested by instruction in Stage I
    input  logic [ADDR_W-1:0] rs1_addr_i,
    input  logic [ADDR_W-1:0] rs2_addr_i,

    // Raw values read from Physical Register File (`prf.sv`)
    input  logic [31:0]       prf_rs1_data_i,
    input  logic [31:0]       prf_rs2_data_i,

    // Forwarding tap 1 (Younger): Stage X completion bus
    input  logic              ex_fwd_valid_i,
    input  logic [ADDR_W-1:0] ex_fwd_rd_i,
    input  logic [31:0]       ex_fwd_data_i,

    // Forwarding tap 2 (Older): Stage C / Writeback register
    input  logic              wb_fwd_valid_i,
    input  logic [ADDR_W-1:0] wb_fwd_rd_i,
    input  logic [31:0]       wb_fwd_data_i,

    // Resolved operand values to be latched into Stage I -> Stage X register
    output logic [31:0]       rs1_val_o,
    output logic [31:0]       rs2_val_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement combinational forwarding priority multiplexers for
    //   `rs1_val_o` and `rs2_val_o` (`x0` > `ex_fwd` > `wb_fwd` > `prf`).
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign rs1_val_o = 32'h0;
    assign rs2_val_o = 32'h0;

endmodule : bypass

