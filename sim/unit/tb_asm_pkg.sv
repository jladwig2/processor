`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_asm_pkg.sv
// Package:     tb_asm_pkg
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Lightweight in-simulation RISC-V 32-bit instruction assembler package.
//   Provides human-readable encoding functions for all 57 RV32IM + Zicsr +
//   Zifencei + M-Mode System instructions used by the directed unit tests
//   (`sim/unit/tb_isa_*.sv`).
// =============================================================================

package tb_asm_pkg;

    import rv_pkg::*;

    // Base instruction formats
    function automatic logic [31:0] enc_r(
        logic [6:0] funct7,
        logic [4:0] rs2,
        logic [4:0] rs1,
        logic [2:0] funct3,
        logic [4:0] rd,
        logic [6:0] opcode
    );
        return {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_i(
        logic [11:0] imm,
        logic [4:0]  rs1,
        logic [2:0]  funct3,
        logic [4:0]  rd,
        logic [6:0]  opcode
    );
        return {imm, rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_s(
        logic [11:0] imm,
        logic [4:0]  rs2,
        logic [4:0]  rs1,
        logic [2:0]  funct3,
        logic [6:0]  opcode
    );
        return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    endfunction

    function automatic logic [31:0] enc_b(
        logic [12:0] imm,
        logic [4:0]  rs2,
        logic [4:0]  rs1,
        logic [2:0]  funct3,
        logic [6:0]  opcode
    );
        return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    endfunction

    function automatic logic [31:0] enc_u(
        logic [19:0] imm20,
        logic [4:0]  rd,
        logic [6:0]  opcode
    );
        return {imm20, rd, opcode};
    endfunction

    function automatic logic [31:0] enc_j(
        logic [20:0] imm21,
        logic [4:0]  rd,
        logic [6:0]  opcode
    );
        return {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, opcode};
    endfunction

    // --- RV32I ALU R-Type ---
    function automatic logic [31:0] asm_add(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_BASE, rs2, rs1, F3_ADD_SUB, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_sub(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_SUB_SRA, rs2, rs1, F3_ADD_SUB, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_sll(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_BASE, rs2, rs1, F3_SLL, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_slt(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_BASE, rs2, rs1, F3_SLT, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_sltu(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_BASE, rs2, rs1, F3_SLTU, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_xor(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_BASE, rs2, rs1, F3_XOR, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_srl(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_BASE, rs2, rs1, F3_SRL_SRA, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_sra(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_SUB_SRA, rs2, rs1, F3_SRL_SRA, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_or(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_BASE, rs2, rs1, F3_OR, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_and(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_BASE, rs2, rs1, F3_AND, rd, OPCODE_OP);
    endfunction

    // --- RV32I ALU I-Type ---
    function automatic logic [31:0] asm_addi(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_ADD_SUB, rd, OPCODE_OP_IMM);
    endfunction

    function automatic logic [31:0] asm_slli(logic [4:0] rd, logic [4:0] rs1, logic [4:0] shamt);
        return enc_i({7'b0000000, shamt}, rs1, F3_SLL, rd, OPCODE_OP_IMM);
    endfunction

    function automatic logic [31:0] asm_slti(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_SLT, rd, OPCODE_OP_IMM);
    endfunction

    function automatic logic [31:0] asm_sltiu(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_SLTU, rd, OPCODE_OP_IMM);
    endfunction

    function automatic logic [31:0] asm_xori(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_XOR, rd, OPCODE_OP_IMM);
    endfunction

    function automatic logic [31:0] asm_srli(logic [4:0] rd, logic [4:0] rs1, logic [4:0] shamt);
        return enc_i({7'b0000000, shamt}, rs1, F3_SRL_SRA, rd, OPCODE_OP_IMM);
    endfunction

    function automatic logic [31:0] asm_srai(logic [4:0] rd, logic [4:0] rs1, logic [4:0] shamt);
        return enc_i({7'b0100000, shamt}, rs1, F3_SRL_SRA, rd, OPCODE_OP_IMM);
    endfunction

    function automatic logic [31:0] asm_ori(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_OR, rd, OPCODE_OP_IMM);
    endfunction

    function automatic logic [31:0] asm_andi(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_AND, rd, OPCODE_OP_IMM);
    endfunction

    // --- RV32I Upper Immediate ---
    function automatic logic [31:0] asm_lui(logic [4:0] rd, logic [19:0] imm20);
        return enc_u(imm20, rd, OPCODE_LUI);
    endfunction

    function automatic logic [31:0] asm_auipc(logic [4:0] rd, logic [19:0] imm20);
        return enc_u(imm20, rd, OPCODE_AUIPC);
    endfunction

    // --- RV32I Branches ---
    function automatic logic [31:0] asm_beq(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] imm);
        return enc_b(imm, rs2, rs1, F3_BEQ, OPCODE_BRANCH);
    endfunction

    function automatic logic [31:0] asm_bne(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] imm);
        return enc_b(imm, rs2, rs1, F3_BNE, OPCODE_BRANCH);
    endfunction

    function automatic logic [31:0] asm_blt(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] imm);
        return enc_b(imm, rs2, rs1, F3_BLT, OPCODE_BRANCH);
    endfunction

    function automatic logic [31:0] asm_bge(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] imm);
        return enc_b(imm, rs2, rs1, F3_BGE, OPCODE_BRANCH);
    endfunction

    function automatic logic [31:0] asm_bltu(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] imm);
        return enc_b(imm, rs2, rs1, F3_BLTU, OPCODE_BRANCH);
    endfunction

    function automatic logic [31:0] asm_bgeu(logic [4:0] rs1, logic [4:0] rs2, logic [12:0] imm);
        return enc_b(imm, rs2, rs1, F3_BGEU, OPCODE_BRANCH);
    endfunction

    // --- RV32I Jumps ---
    function automatic logic [31:0] asm_jal(logic [4:0] rd, logic [20:0] imm);
        return enc_j(imm, rd, OPCODE_JAL);
    endfunction

    function automatic logic [31:0] asm_jalr(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, 3'b000, rd, OPCODE_JALR);
    endfunction

    // --- RV32I Loads & Stores ---
    function automatic logic [31:0] asm_lb(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_LB_SB, rd, OPCODE_LOAD);
    endfunction

    function automatic logic [31:0] asm_lh(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_LH_SH, rd, OPCODE_LOAD);
    endfunction

    function automatic logic [31:0] asm_lw(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_LW_SW, rd, OPCODE_LOAD);
    endfunction

    function automatic logic [31:0] asm_lbu(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_LBU, rd, OPCODE_LOAD);
    endfunction

    function automatic logic [31:0] asm_lhu(logic [4:0] rd, logic [4:0] rs1, logic [11:0] imm);
        return enc_i(imm, rs1, F3_LHU, rd, OPCODE_LOAD);
    endfunction

    function automatic logic [31:0] asm_sb(logic [4:0] rs2, logic [4:0] rs1, logic [11:0] imm);
        return enc_s(imm, rs2, rs1, F3_LB_SB, OPCODE_STORE);
    endfunction

    function automatic logic [31:0] asm_sh(logic [4:0] rs2, logic [4:0] rs1, logic [11:0] imm);
        return enc_s(imm, rs2, rs1, F3_LH_SH, OPCODE_STORE);
    endfunction

    function automatic logic [31:0] asm_sw(logic [4:0] rs2, logic [4:0] rs1, logic [11:0] imm);
        return enc_s(imm, rs2, rs1, F3_LW_SW, OPCODE_STORE);
    endfunction

    // --- RV32M Multiply & Divide ---
    function automatic logic [31:0] asm_mul(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_MULDIV, rs2, rs1, F3_MUL, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_mulh(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_MULDIV, rs2, rs1, F3_MULH, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_mulhsu(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_MULDIV, rs2, rs1, F3_MULHSU, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_mulhu(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_MULDIV, rs2, rs1, F3_MULHU, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_div(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_MULDIV, rs2, rs1, F3_DIV, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_divu(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_MULDIV, rs2, rs1, F3_DIVU, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_rem(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_MULDIV, rs2, rs1, F3_REM, rd, OPCODE_OP);
    endfunction

    function automatic logic [31:0] asm_remu(logic [4:0] rd, logic [4:0] rs1, logic [4:0] rs2);
        return enc_r(F7_MULDIV, rs2, rs1, F3_REMU, rd, OPCODE_OP);
    endfunction

    // --- Zicsr & System ---
    function automatic logic [31:0] asm_csrrw(logic [4:0] rd, logic [11:0] csr, logic [4:0] rs1);
        return enc_i(csr, rs1, F3_CSRRW, rd, OPCODE_SYSTEM);
    endfunction

    function automatic logic [31:0] asm_csrrs(logic [4:0] rd, logic [11:0] csr, logic [4:0] rs1);
        return enc_i(csr, rs1, F3_CSRRS, rd, OPCODE_SYSTEM);
    endfunction

    function automatic logic [31:0] asm_csrrc(logic [4:0] rd, logic [11:0] csr, logic [4:0] rs1);
        return enc_i(csr, rs1, F3_CSRRC, rd, OPCODE_SYSTEM);
    endfunction

    function automatic logic [31:0] asm_csrrwi(logic [4:0] rd, logic [11:0] csr, logic [4:0] zimm);
        return enc_i(csr, zimm, F3_CSRRWI, rd, OPCODE_SYSTEM);
    endfunction

    function automatic logic [31:0] asm_csrrsi(logic [4:0] rd, logic [11:0] csr, logic [4:0] zimm);
        return enc_i(csr, zimm, F3_CSRRSI, rd, OPCODE_SYSTEM);
    endfunction

    function automatic logic [31:0] asm_csrrci(logic [4:0] rd, logic [11:0] csr, logic [4:0] zimm);
        return enc_i(csr, zimm, F3_CSRRCI, rd, OPCODE_SYSTEM);
    endfunction

    function automatic logic [31:0] asm_fence();
        return enc_i(12'h000, 5'd0, F3_FENCE, 5'd0, OPCODE_MISC_MEM);
    endfunction

    function automatic logic [31:0] asm_fence_i();
        return enc_i(12'h000, 5'd0, F3_FENCE_I, 5'd0, OPCODE_MISC_MEM);
    endfunction

    function automatic logic [31:0] asm_ecall();
        return {F12_ECALL, 5'd0, F3_PRIV, 5'd0, OPCODE_SYSTEM};
    endfunction

    function automatic logic [31:0] asm_ebreak();
        return {F12_EBREAK, 5'd0, F3_PRIV, 5'd0, OPCODE_SYSTEM};
    endfunction

    function automatic logic [31:0] asm_mret();
        return {F12_MRET, 5'd0, F3_PRIV, 5'd0, OPCODE_SYSTEM};
    endfunction

    function automatic logic [31:0] asm_wfi();
        return {F12_WFI, 5'd0, F3_PRIV, 5'd0, OPCODE_SYSTEM};
    endfunction

endpackage : tb_asm_pkg
