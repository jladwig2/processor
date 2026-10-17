`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/decode/decoder_rv32.sv
// Module:      decoder_rv32
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Purely combinational single-instruction RISC-V 32-bit decoder. Translates
//   a fetched instruction packet (`fetch_pkt_t`) into the unified micro-op
//   structure (`uop_t` defined in `core_pkg.sv`).
//
//   Why This Module Exists & Reusability Across Milestones:
//     - In M1 (1-wide in-order), `decode.sv` instantiates one `decoder_rv32`.
//     - In M4 (2-wide superscalar OoO), `decode.sv` instantiates two parallel
//       `decoder_rv32` instances (`u_dec0`, `u_dec1`) with zero modifications
//       to this module.
//     - Feature parameter `HAS_MULDIV` allows synthesizing the core with or
//       without the `M` extension; if `HAS_MULDIV == 0`, `M` encodings raise
//       `EXC_ILLEGAL_INSTR` (`mcause = 2`).
//
//   Supported Instruction Classes (57 Instructions in M1):
//     1. `OPCODE_LUI` (`7'b0110111`):
//        - `fu_type = FU_ALU`, `alu_op = ALU_ADD`, `op1_sel = OP1_ZERO`,
//          `op2_sel = OP2_IMM`, `imm = imm_u`, `rd_wen = (rd != 0)`.
//     2. `OPCODE_AUIPC` (`7'b0010111`):
//        - `fu_type = FU_ALU`, `alu_op = ALU_ADD`, `op1_sel = OP1_PC`,
//          `op2_sel = OP2_IMM`, `imm = imm_u`, `rd_wen = (rd != 0)`.
//     3. `OPCODE_JAL` (`7'b1101111`):
//        - `fu_type = FU_BRU`, `bru_op = BRU_JAL`, `imm = imm_j`,
//          `rd_wen = (rd != 0)`.
//     4. `OPCODE_JALR` (`7'b1100111`, requires `funct3 == 3'b000`):
//        - `fu_type = FU_BRU`, `bru_op = BRU_JALR`, `rs1_ren = 1`,
//          `imm = imm_i`, `rd_wen = (rd != 0)`.
//     5. `OPCODE_BRANCH` (`7'b1100011`, `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`):
//        - `fu_type = FU_BRU`, `rs1_ren = 1`, `rs2_ren = 1`, `imm = imm_b`,
//          `rd_wen = 0`. Reserved `funct3` (`3'b010`, `3'b011`) -> illegal!
//     6. `OPCODE_LOAD` (`7'b0000011`, `lb`, `lh`, `lw`, `lbu`, `lhu`):
//        - `fu_type = FU_LSU`, `is_load = 1`, `rs1_ren = 1`, `imm = imm_i`,
//          `rd_wen = (rd != 0)`, `lsu_size`, `lsu_unsigned`.
//     7. `OPCODE_STORE` (`7'b0100011`, `sb`, `sh`, `sw`):
//        - `fu_type = FU_LSU`, `is_store = 1`, `rs1_ren = 1`, `rs2_ren = 1`,
//          `imm = imm_s`, `rd_wen = 0`, `lsu_size`.
//     8. `OPCODE_OP_IMM` (`7'b0010011`, `addi`..`andi`, `slli`, `srli`, `srai`):
//        - `fu_type = FU_ALU`, `op1_sel = OP1_RS1`, `op2_sel = OP2_IMM`,
//          `rs1_ren = 1`, `imm = imm_i`, `rd_wen = (rd != 0)`.
//        - Shift immediates (`slli`, `srli`, `srai`) must validate `funct7`:
//          `slli` requires `funct7 == 7'b0000000`; `srli`/`srai` require
//          `funct7 == 7'b0000000` or `7'b0100000`; otherwise raise
//          `EXC_ILLEGAL_INSTR`!
//     9. `OPCODE_OP` (`7'b0110011`):
//        - If `funct7 == F7_BASE (7'b0000000)` or `F7_SUB_SRA (7'b0100000)`
//          (only valid for `sub` and `sra`): `fu_type = FU_ALU`, `op1_sel =
//          OP1_RS1`, `op2_sel = OP2_RS2`, `rs1_ren = 1`, `rs2_ren = 1`,
//          `rd_wen = (rd != 0)`.
//        - If `funct7 == F7_MULDIV (7'b0000001)` and `HAS_MULDIV == 1`:
//            * `funct3[2] == 1'b0` (`mul`, `mulh`, `mulhsu`, `mulhu`):
//              `fu_type = FU_MUL`, `mul_op = mul_op_e'(funct3[1:0])`.
//            * `funct3[2] == 1'b1` (`div`, `divu`, `rem`, `remu`):
//              `fu_type = FU_DIV`, `div_op = div_op_e'(funct3[1:0])`.
//    10. `OPCODE_MISC_MEM` (`7'b0001111`):
//        - `F3_FENCE (3'b000)`:   `fu_type = FU_NONE`, `is_fence = 1`.
//        - `F3_FENCE_I (3'b001)`: `fu_type = FU_NONE`, `is_fence_i = 1`,
//          `is_serializing = 1`.
//    11. `OPCODE_SYSTEM` (`7'b1110011`):
//        - `funct3 == F3_PRIV (3'b000)` (requires `rs1 == 0` and `rd == 0`):
//            * `funct12 == F12_ECALL`:  `exc_valid = 1`, `exc_cause = EXC_ECALL_M`,
//              `is_ecall = 1`, `is_serializing = 1`.
//            * `funct12 == F12_EBREAK`: `exc_valid = 1`, `exc_cause = EXC_BREAKPOINT`,
//              `exc_tval = pc`, `is_ebreak = 1`, `is_serializing = 1`.
//            * `funct12 == F12_MRET`:   `is_mret = 1`, `is_serializing = 1`.
//            * `funct12 == F12_WFI`:    `is_wfi = 1`, `is_serializing = 1`.
//        - `funct3 != 3'b000` and `funct3 != 3'b100` (`csrrw/s/c[i]`):
//            * `fu_type = FU_CSR`, `is_serializing = 1`, `imm = {20'b0, inst[31:20]}`,
//              `csr_use_imm = funct3[2]`, `rs1_ren = !funct3[2]`,
//              `rd_wen = (rd != 0)`.
//    12. Exception Propagation Priority:
//        - If `pkt_i.exc_valid` is already set by `frontend.sv` (instruction
//          address misaligned or instruction access fault), preserve
//          `pkt_i.exc_cause` and set `exc_tval = pkt_i.pc`.
//        - Else if instruction encoding is unrecognized/reserved, set
//          `uop_o.exc_valid = 1'b1`, `uop_o.exc_cause = EXC_ILLEGAL_INSTR`,
//          and `uop_o.exc_tval = pkt_i.insn`.
//
// Connections:
//   - Instantiated by: `decode.sv` (`u_decoder_rv32`).
//   - Inputs:  `pkt_i` (`fetch_pkt_t` from `decode.sv`)
//   - Outputs: `uop_o` (`uop_t` to `decode.sv` pipeline register)
//
// What Needs to Be Implemented:
//   1. Extract I, S, B, U, and J immediate formats with proper sign extension.
//   2. Implement the combinational `always_comb` opcode/funct3/funct7 case
//      decoder populating all fields of `uop_o`.
// =============================================================================

module decoder_rv32
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter bit HAS_MULDIV = 1'b1
) (
    input  fetch_pkt_t pkt_i,
    output uop_t       uop_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Extract `imm_i`, `imm_s`, `imm_b`, `imm_u`, `imm_j` from `pkt_i.insn`.
    //   2. Decode all 57 RV32IM + Zicsr + Zifencei + M-mode system instructions
    //      into `uop_o`, flagging any unknown/reserved bit pattern with
    //      `exc_valid = 1'b1` and `exc_cause = EXC_ILLEGAL_INSTR`.
    // -------------------------------------------------------------------------

    // Temporary stub tie-off
    assign uop_o = '0;

endmodule : decoder_rv32

