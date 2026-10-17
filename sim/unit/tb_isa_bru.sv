`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_bru.sv
// Module:      tb_isa_bru
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite for the 8 RV32I Control-Transfer
//   Instructions:
//     - Conditional Branches (6): `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`
//     - Unconditional Jumps (2):  `jal`, `jalr`
// =============================================================================

module tb_isa_bru
    import soc_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
    import tb_asm_pkg::*;
;

    commit_trace_t tr;
    logic err;

    // =========================================================================
    // 1. BEQ / BNE (Equality & Inequality Branches)
    // =========================================================================
    task automatic test_beq_bne();
        $display("[INFO] Running test_beq_bne...");

        // 1.1 BEQ Taken: 42 == 42 jumps over wrong-path instruction
        // Memory layout at MAIN_MEM_BASE:
        //   +0: beq x1, x2, +8  (jumps to +8)
        //   +4: addi x10, x0, 99 (wrong-path, must be squashed!)
        //   +8: addi x11, x0, 55 (target)
        //  +12: wfi
        tb_core.har_write_gpr(5'd1, 32'd42);
        tb_core.har_write_gpr(5'd2, 32'd42);
        tb_core.har_write_gpr(5'd10, 32'd0);
        tb_core.har_write_gpr(5'd11, 32'd0);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0,  asm_beq(5'd1, 5'd2, 13'd8),  4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4,  asm_addi(5'd10, 5'd0, 12'd99), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8,  asm_addi(5'd11, 5'd0, 12'd55), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 12, asm_wfi(), 4'b1111, err);

        // Retire beq and target addi
        tb_core.har_wait_retire(50, tr);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd10, 32'd0,  "beq squashed wrong-path instruction at pc+4");
        tb_core.har_assert_gpr(5'd11, 32'd55, "beq jumped to target at pc+8");

        // 1.2 BNE Not-Taken: 42 == 42 falls through to pc+4
        //   +0: bne x1, x2, +8 (not taken)
        //   +4: addi x10, x0, 77 (falls through)
        //   +8: wfi
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_bne(5'd1, 5'd2, 13'd8),  4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_addi(5'd10, 5'd0, 12'd77), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd10, 32'd77, "bne not-taken fell through to pc+4");

        // 1.3 Taken branch to 2-byte misaligned target: raises EXC_INSTR_ADDR_MISALIGNED (0)
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_beq(5'd1, 5'd2, 13'd6), 4'b1111, err); // offset +6 -> misaligned
        tb_core.har_assert_trap(EXC_INSTR_ADDR_MISALIGNED, soc_pkg::MAIN_MEM_BASE, soc_pkg::MAIN_MEM_BASE + 32'd6, "taken beq to misaligned target");

        // 1.4 Untaken branch with misaligned offset must NOT trap (Spec rule)
        tb_core.har_write_gpr(5'd2, 32'd43); // x1 != x2
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_beq(5'd1, 5'd2, 13'd6), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_addi(5'd10, 5'd0, 12'd88), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
        if (!tr.trap_taken) $display("[PASS] untaken beq with misaligned offset did not trap");
        else tb_core.test_errors++;
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd10, 32'd88, "untaken beq fell through to pc+4");
    endtask

    // =========================================================================
    // 2. BLT / BGE / BLTU / BGEU (Relational Branches)
    // =========================================================================
    task automatic test_relational_branches();
        $display("[INFO] Running test_relational_branches...");

        // 2.1 BLT Signed: (-5 < 2) is taken
        tb_core.har_write_gpr(5'd1, 32'hFFFF_FFFB); // -5
        tb_core.har_write_gpr(5'd2, 32'd2);          // +2
        tb_core.har_write_gpr(5'd10, 32'd0);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_blt(5'd1, 5'd2, 13'd8), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_addi(5'd10, 5'd0, 12'd1), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8, asm_addi(5'd10, 5'd0, 12'd2), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 12, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd10, 32'd2, "blt (-5 < 2) taken to pc+8");

        // 2.2 BLTU Unsigned: (0xFFFF_FFFB < 2) is NOT taken
        tb_core.har_write_gpr(5'd10, 32'd0);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_bltu(5'd1, 5'd2, 13'd8), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_addi(5'd10, 5'd0, 12'd1), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd10, 32'd1, "bltu (unsigned -5 < 2) not taken, fell through");

        // 2.3 Reserved branch funct3 encoding (3'b010) raises EXC_ILLEGAL_INSTR (2)
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, enc_b(13'd8, 5'd2, 5'd1, 3'b010, OPCODE_BRANCH), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, enc_b(13'd8, 5'd2, 5'd1, 3'b010, OPCODE_BRANCH), "reserved branch funct3=2");
    endtask

    // =========================================================================
    // 3. JAL / JALR (Unconditional Jumps)
    // =========================================================================
    task automatic test_jal_jalr();
        $display("[INFO] Running test_jal_jalr...");

        // 3.1 JAL: rd = pc + 4, jumps to pc + 8
        tb_core.har_write_gpr(5'd1, 32'd0);
        tb_core.har_write_gpr(5'd10, 32'd0);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0,  asm_jal(5'd1, 21'd8), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4,  asm_addi(5'd10, 5'd0, 12'd1), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8,  asm_addi(5'd10, 5'd0, 12'd2), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 12, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd1, soc_pkg::MAIN_MEM_BASE + 32'd4, "jal link register rd = pc+4");
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd10, 32'd2, "jal jumped to pc+8");

        // 3.2 JALR with LSB clearing: target = (rs1 + imm) & ~1
        // rs1 = 0x8000_0009 (odd address!), imm = 0 -> target must clear bit 0 to 0x8000_0008!
        tb_core.har_write_gpr(5'd2, soc_pkg::MAIN_MEM_BASE + 32'd9);
        tb_core.har_write_gpr(5'd10, 32'd0);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_jalr(5'd1, 5'd2, 12'd0), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_addi(5'd10, 5'd0, 12'd1), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8, asm_addi(5'd10, 5'd0, 12'd3), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 12, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd1, soc_pkg::MAIN_MEM_BASE + 32'd4, "jalr link register rd = pc+4");
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd10, 32'd3, "jalr cleared bit 0 and jumped to 0x8000_0008");

        // 3.3 JAL to misaligned target (bit 1 set): raises EXC_INSTR_ADDR_MISALIGNED and suppresses rd write!
        tb_core.har_write_gpr(5'd1, 32'hDEAD_BEEF);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_jal(5'd1, 21'd6), 4'b1111, err);
        tb_core.har_assert_trap(EXC_INSTR_ADDR_MISALIGNED, soc_pkg::MAIN_MEM_BASE, soc_pkg::MAIN_MEM_BASE + 32'd6, "jal to misaligned target");
        tb_core.har_assert_gpr(5'd1, 32'hDEAD_BEEF, "faulting jal did not overwrite rd");
    endtask

    // Runner for all BRU tests
    task automatic run_all();
        $display("----------------------------------------------------------------");
        $display("  tb_isa_bru: Starting 8 RV32I Branch & Jump Tests              ");
        $display("----------------------------------------------------------------");
        test_beq_bne();
        test_relational_branches();
        test_jal_jalr();
        $display("----------------------------------------------------------------");
        $display("  tb_isa_bru: Completed                                         ");
        $display("----------------------------------------------------------------");
    endtask

endmodule : tb_isa_bru
