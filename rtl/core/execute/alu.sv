`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/execute/alu.sv
// Module:      alu
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Single-cycle 32-bit Integer Arithmetic Logic Unit (ALU) executing all
//   RV32I computational instructions (`add[i]`, `sub`, `sll[i]`, `slt[i]`,
//   `sltu`/`sltiu`, `xor[i]`, `srl[i]`, `sra[i]`, `or[i]`, `and[i]`, `lui`,
//   `auipc`).
//
//   Architecture & Operation:
//     1. Operand Selection:
//        - `op_a`: selected via `uop_i.op1_sel`:
//            * `OP1_RS1`:  `rs1_val_i`
//            * `OP1_PC`:   `uop_i.pc` (`auipc`)
//            * `OP1_ZERO`: `32'h0000_0000` (`lui`)
//        - `op_b`: selected via `uop_i.op2_sel`:
//            * `OP2_RS2`:  `rs2_val_i`
//            * `OP2_IMM`:  `uop_i.imm`
//            * `OP2_FOUR`: `32'h0000_0004`
//     2. Arithmetic & Logical Operations (`uop_i.alu_op`):
//        - `ALU_ADD`:  `op_a + op_b`
//        - `ALU_SUB`:  `op_a - op_b`
//        - `ALU_SLL`:  `op_a << op_b[4:0]`
//        - `ALU_SLT`:  `{31'b0, $signed(op_a) < $signed(op_b)}`
//        - `ALU_SLTU`: `{31'b0, op_a < op_b}`
//        - `ALU_XOR`:  `op_a ^ op_b`
//        - `ALU_SRL`:  `op_a >> op_b[4:0]`
//        - `ALU_SRA`:  `$signed(op_a) >>> op_b[4:0]`
//        - `ALU_OR`:   `op_a | op_b`
//        - `ALU_AND`:  `op_a & op_b`
//
// Connections:
//   - Instantiated by: `core.sv` (`u_alu` in M1; `u_alu0` and `u_alu1` in M4).
//   - Inputs:  `uop_i`, `rs1_val_i`, `rs2_val_i` (from Stage I -> Stage X register)
//   - Outputs: `result_o` (to Stage X completion mux & forwarding bus)
//
// What Needs to Be Implemented:
//   1. Implement the combinational `op_a` and `op_b` input multiplexers.
//   2. Implement the combinational `alu_op` case statement driving `result_o`.
// =============================================================================

module alu
    import rv_pkg::*;
    import core_pkg::*;
(
    input  uop_t        uop_i,
    input  logic [31:0] rs1_val_i,
    input  logic [31:0] rs2_val_i,
    output logic [31:0] result_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement `op_a`/`op_b` muxes and 10-operation ALU case block.
    // -------------------------------------------------------------------------

    // Temporary stub tie-off
    assign result_o = 32'h0;

endmodule : alu

