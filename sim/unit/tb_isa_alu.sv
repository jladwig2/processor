`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_alu.sv
// Module:      tb_isa_alu
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite for the 21 RV32I Integer ALU
//   and Upper-Immediate Instructions:
//     - R-Type (10): `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`,
//                    `or`, `and`
//     - I-Type (9):  `addi`, `slli`, `slti`, `sltiu`, `xori`, `srli`, `srai`,
//                    `ori`, `andi`
//     - U-Type (2):  `lui`, `auipc`
// =============================================================================

module tb_isa_alu
    import soc_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
    import tb_asm_pkg::*;
;

    commit_trace_t tr;
    logic err;

    // Helper task to execute a single instruction at MAIN_MEM_BASE and wait for retirement
    task automatic exec_single_insn(input logic [31:0] insn);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, insn, 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
    endtask

    // =========================================================================
    // 1. ADD / ADDI / SUB
    // =========================================================================
    task automatic test_add_addi_sub();
        $display("[INFO] Running test_add_addi_sub...");

        // 1.1 ADD: 15 + 27 = 42
        tb_core.har_write_gpr(5'd1, 32'd15);
        tb_core.har_write_gpr(5'd2, 32'd27);
        tb_core.har_write_gpr(5'd5, 32'hDEAD_BEEF);
        exec_single_insn(asm_add(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'd42, "add 15 + 27 = 42");

        // 1.2 ADDI positive max immediate: 100 + 2047 = 2147
        tb_core.har_write_gpr(5'd1, 32'd100);
        exec_single_insn(asm_addi(5'd5, 5'd1, 12'h7FF));
        tb_core.har_assert_gpr(5'd5, 32'd2147, "addi 100 + 2047 = 2147");

        // 1.3 ADDI negative immediate sign-extension: 100 + (-1) = 99
        exec_single_insn(asm_addi(5'd5, 5'd1, 12'hFFF));
        tb_core.har_assert_gpr(5'd5, 32'd99, "addi 100 + (-1) = 99");

        // 1.4 SUB: 50 - 18 = 32
        tb_core.har_write_gpr(5'd1, 32'd50);
        tb_core.har_write_gpr(5'd2, 32'd18);
        exec_single_insn(asm_sub(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'd32, "sub 50 - 18 = 32");

        // 1.5 Signed overflow wrap-around (must NOT trap): 0x7FFF_FFFF + 1 = 0x8000_0000
        tb_core.har_write_gpr(5'd1, 32'h7FFF_FFFF);
        tb_core.har_write_gpr(5'd2, 32'd1);
        exec_single_insn(asm_add(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'h8000_0000, "add overflow wrap to INT_MIN");

        // 1.6 Destination x0 write suppression
        exec_single_insn(asm_addi(5'd0, 5'd0, 12'd123));
        tb_core.har_assert_gpr(5'd0, 32'd0, "x0 hardwired to zero");

        // 1.7 Illegal funct7 encoding on OPCODE_OP
        tb_core.har_write_gpr(5'd5, 32'hDEAD_BEEF);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, enc_r(7'b0000010, 5'd2, 5'd1, F3_ADD_SUB, 5'd5, OPCODE_OP), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, enc_r(7'b0000010, 5'd2, 5'd1, F3_ADD_SUB, 5'd5, OPCODE_OP), "illegal funct7 on ADD");
        tb_core.har_assert_gpr(5'd5, 32'hDEAD_BEEF, "illegal instruction does not modify rd");
    endtask

    // =========================================================================
    // 2. SLL / SLLI / SRL / SRLI / SRA / SRAI (Barrel Shifter)
    // =========================================================================
    task automatic test_shifts();
        $display("[INFO] Running test_shifts...");

        // 2.1 SLL: 1 << 4 = 16
        tb_core.har_write_gpr(5'd1, 32'h0000_0001);
        tb_core.har_write_gpr(5'd2, 32'd4);
        exec_single_insn(asm_sll(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'h0000_0010, "sll 1 << 4 = 16");

        // 2.2 SLLI: 1 << 31 = 0x8000_0000
        exec_single_insn(asm_slli(5'd5, 5'd1, 5'd31));
        tb_core.har_assert_gpr(5'd5, 32'h8000_0000, "slli 1 << 31 = 0x8000_0000");

        // 2.3 SRL: 0x8000_0000 >> 1 = 0x4000_0000 (logical right shift zero-fills)
        tb_core.har_write_gpr(5'd1, 32'h8000_0000);
        tb_core.har_write_gpr(5'd2, 32'd1);
        exec_single_insn(asm_srl(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'h4000_0000, "srl logical right shift 0x8000_0000 >> 1");

        // 2.4 SRA: 0x8000_0000 >>> 1 = 0xC000_0000 (arithmetic right shift sign-extends)
        exec_single_insn(asm_sra(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'hC000_0000, "sra arithmetic right shift 0x8000_0000 >>> 1");

        // 2.5 Shift amount masking rs2[4:0] (ignoring upper bits)
        tb_core.har_write_gpr(5'd1, 32'h0000_0001);
        tb_core.har_write_gpr(5'd2, 32'hFFFF_FFE4); // rs2[4:0] == 4
        exec_single_insn(asm_sll(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'h0000_0010, "sll shamt masked to rs2[4:0]");

        // 2.6 Illegal shamt[5]=1 on RV32
        tb_core.har_write_gpr(5'd5, 32'hDEAD_BEEF);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, enc_i(12'h820, 5'd1, F3_SLL, 5'd5, OPCODE_OP_IMM), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, enc_i(12'h820, 5'd1, F3_SLL, 5'd5, OPCODE_OP_IMM), "illegal shamt[5]=1 on slli");
        tb_core.har_assert_gpr(5'd5, 32'hDEAD_BEEF, "illegal instruction does not modify rd");
    endtask

    // =========================================================================
    // 3. SLT / SLTI / SLTU / SLTIU (Comparisons)
    // =========================================================================
    task automatic test_compares();
        $display("[INFO] Running test_compares...");

        // 3.1 SLT signed: -1 < 1 -> 1
        tb_core.har_write_gpr(5'd1, 32'hFFFF_FFFF); // -1
        tb_core.har_write_gpr(5'd2, 32'd1);          // +1
        exec_single_insn(asm_slt(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'd1, "slt (-1 < 1) = 1");

        // 3.2 SLTU unsigned: 0xFFFF_FFFF < 1 -> 0
        exec_single_insn(asm_sltu(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'd0, "sltu (0xFFFF_FFFF < 1) = 0");

        // 3.3 SLTIU sign-extension before unsigned compare: 0 < -1 -> 1
        tb_core.har_write_gpr(5'd1, 32'd0);
        exec_single_insn(asm_sltiu(5'd5, 5'd1, 12'hFFF)); // imm sign-extends to 0xFFFF_FFFF
        tb_core.har_assert_gpr(5'd5, 32'd1, "sltiu (0 < 0xFFFF_FFFF) = 1");
    endtask

    // =========================================================================
    // 4. XOR / XORI / OR / ORI / AND / ANDI (Bitwise)
    // =========================================================================
    task automatic test_bitwise();
        $display("[INFO] Running test_bitwise...");

        // 4.1 XOR: 0xAAAA_5555 ^ 0x5555_AAAA = 0xFFFF_FFFF
        tb_core.har_write_gpr(5'd1, 32'hAAAA_5555);
        tb_core.har_write_gpr(5'd2, 32'h5555_AAAA);
        exec_single_insn(asm_xor(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'hFFFF_FFFF, "xor 0xAAAA_5555 ^ 0x5555_AAAA");

        // 4.2 XORI bitwise inversion: xori rd, rs1, -1
        exec_single_insn(asm_xori(5'd5, 5'd1, 12'hFFF));
        tb_core.har_assert_gpr(5'd5, 32'h5555_AAAA, "xori bitwise NOT");

        // 4.3 OR: 0xF0F0_0000 | 0x0000_0F0F = 0xF0F0_0F0F
        tb_core.har_write_gpr(5'd1, 32'hF0F0_0000);
        tb_core.har_write_gpr(5'd2, 32'h0000_0F0F);
        exec_single_insn(asm_or(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'hF0F0_0F0F, "or 0xF0F0_0000 | 0x0000_0F0F");

        // 4.4 AND: 0xFFFF_FFFF & 0x1234_5678 = 0x1234_5678
        tb_core.har_write_gpr(5'd1, 32'hFFFF_FFFF);
        tb_core.har_write_gpr(5'd2, 32'h1234_5678);
        exec_single_insn(asm_and(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'h1234_5678, "and 0xFFFF_FFFF & 0x1234_5678");
    endtask

    // =========================================================================
    // 5. LUI / AUIPC (Upper Immediate)
    // =========================================================================
    task automatic test_upper_imm();
        $display("[INFO] Running test_upper_imm...");

        // 5.1 LUI: lui x5, 0x12345 -> 0x1234_5000
        exec_single_insn(asm_lui(5'd5, 20'h12345));
        tb_core.har_assert_gpr(5'd5, 32'h1234_5000, "lui 0x12345 -> 0x1234_5000");

        // 5.2 AUIPC: executed at MAIN_MEM_BASE (0x8000_0000) with imm20=1 -> 0x8000_1000
        exec_single_insn(asm_auipc(5'd5, 20'h00001));
        tb_core.har_assert_gpr(5'd5, soc_pkg::MAIN_MEM_BASE + 32'h0000_1000, "auipc PC + 0x1000");
    endtask

    // Runner for all ALU tests
    task automatic run_all();
        $display("----------------------------------------------------------------");
        $display("  tb_isa_alu: Starting 21 RV32I ALU & Upper-Imm Tests           ");
        $display("----------------------------------------------------------------");
        test_add_addi_sub();
        test_shifts();
        test_compares();
        test_bitwise();
        test_upper_imm();
        $display("----------------------------------------------------------------");
        $display("  tb_isa_alu: Completed                                         ");
        $display("----------------------------------------------------------------");
    endtask

endmodule : tb_isa_alu
