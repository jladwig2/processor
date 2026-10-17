`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_lsu.sv
// Module:      tb_isa_lsu
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite for the 8 RV32I Load and Store
//   Instructions:
//     - Loads (5):  `lb`, `lh`, `lw`, `lbu`, `lhu`
//     - Stores (3): `sb`, `sh`, `sw`
//     - Hardware Misaligned Split-Transfer Handling (`misalign.sv`)
//     - PMA Permission & Alignment Exception Detection
// =============================================================================

module tb_isa_lsu
    import soc_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
    import tb_asm_pkg::*;
;

    commit_trace_t tr;
    logic err;

    task automatic exec_single_insn(input logic [31:0] insn);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, insn, 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(100, tr);
    endtask

    // Data test address in main RAM (well above code at MAIN_MEM_BASE)
    localparam logic [31:0] DATA_ADDR = soc_pkg::MAIN_MEM_BASE + 32'h0000_2000;

    // =========================================================================
    // 1. Aligned Loads: LB / LBU / LH / LHU / LW
    // =========================================================================
    task automatic test_aligned_loads();
        $display("[INFO] Running test_aligned_loads...");

        // Preload DATA_ADDR with 0x807F_8001
        //   Byte 0: 0x01
        //   Byte 1: 0x80
        //   Byte 2: 0x7F
        //   Byte 3: 0x80
        tb_core.har_write_mem(DATA_ADDR, 32'h807F_8001, 4'b1111, err);
        tb_core.har_write_gpr(5'd1, DATA_ADDR); // base address in x1

        // 1.1 LB byte 0 (0x01): sign-extended -> 0x0000_0001
        exec_single_insn(asm_lb(5'd5, 5'd1, 12'd0));
        tb_core.har_assert_gpr(5'd5, 32'h0000_0001, "lb byte 0 (0x01)");

        // 1.2 LB byte 1 (0x80): sign-extended -> 0xFFFF_FF80
        exec_single_insn(asm_lb(5'd5, 5'd1, 12'd1));
        tb_core.har_assert_gpr(5'd5, 32'hFFFF_FF80, "lb byte 1 (0x80 sign-extended)");

        // 1.3 LBU byte 1 (0x80): zero-extended -> 0x0000_0080
        exec_single_insn(asm_lbu(5'd5, 5'd1, 12'd1));
        tb_core.har_assert_gpr(5'd5, 32'h0000_0080, "lbu byte 1 (0x80 zero-extended)");

        // 1.4 LH halfword 0 (0x8001): sign-extended -> 0xFFFF_8001
        exec_single_insn(asm_lh(5'd5, 5'd1, 12'd0));
        tb_core.har_assert_gpr(5'd5, 32'hFFFF_8001, "lh halfword 0 (0x8001 sign-extended)");

        // 1.5 LHU halfword 0 (0x8001): zero-extended -> 0x0000_8001
        exec_single_insn(asm_lhu(5'd5, 5'd1, 12'd0));
        tb_core.har_assert_gpr(5'd5, 32'h0000_8001, "lhu halfword 0 (0x8001 zero-extended)");

        // 1.6 LW word 0: full word -> 0x807F_8001
        exec_single_insn(asm_lw(5'd5, 5'd1, 12'd0));
        tb_core.har_assert_gpr(5'd5, 32'h807F_8001, "lw full word 0x807F_8001");

        // 1.7 Load-to-Use RAW hazard interlock (lw followed immediately by addi)
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_lw(5'd5, 5'd1, 12'd0), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_addi(5'd6, 5'd5, 12'd1), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd6, 32'h807F_8002, "load-use RAW interlock lw -> addi");
    endtask

    // =========================================================================
    // 2. Aligned Stores: SB / SH / SW (Byte-Lane Masking Check via SBA)
    // =========================================================================
    task automatic test_aligned_stores();
        $display("[INFO] Running test_aligned_stores...");

        tb_core.har_write_gpr(5'd1, DATA_ADDR); // base address
        tb_core.har_write_gpr(5'd2, 32'hDEAD_BEEF); // store data

        // 2.1 SB to byte 0: memory changes from 0x1122_3344 -> 0x1122_33EF
        tb_core.har_write_mem(DATA_ADDR, 32'h1122_3344, 4'b1111, err);
        exec_single_insn(asm_sb(5'd2, 5'd1, 12'd0));
        tb_core.har_assert_mem(DATA_ADDR, 32'h1122_33EF, "sb byte 0 masking");

        // 2.2 SB to byte 1: memory changes to 0x1122_EF44
        tb_core.har_write_mem(DATA_ADDR, 32'h1122_3344, 4'b1111, err);
        exec_single_insn(asm_sb(5'd2, 5'd1, 12'd1));
        tb_core.har_assert_mem(DATA_ADDR, 32'h1122_EF44, "sb byte 1 masking");

        // 2.3 SH to halfword 0 (offset 0): 0x1122_3344 -> 0x1122_BEEF
        tb_core.har_write_mem(DATA_ADDR, 32'h1122_3344, 4'b1111, err);
        exec_single_insn(asm_sh(5'd2, 5'd1, 12'd0));
        tb_core.har_assert_mem(DATA_ADDR, 32'h1122_BEEF, "sh halfword 0 masking");

        // 2.4 SH to halfword 1 (offset 2): 0x1122_3344 -> 0xBEEF_3344
        tb_core.har_write_mem(DATA_ADDR, 32'h1122_3344, 4'b1111, err);
        exec_single_insn(asm_sh(5'd2, 5'd1, 12'd2));
        tb_core.har_assert_mem(DATA_ADDR, 32'hBEEF_3344, "sh halfword 1 masking");

        // 2.5 SW to word 0: full word write -> 0xDEAD_BEEF
        exec_single_insn(asm_sw(5'd2, 5'd1, 12'd0));
        tb_core.har_assert_mem(DATA_ADDR, 32'hDEAD_BEEF, "sw full word 0xDEAD_BEEF");
    endtask

    // =========================================================================
    // 3. Hardware Misaligned Loads & Stores (Split Across Word Boundaries)
    // =========================================================================
    task automatic test_misaligned_ram_access();
        $display("[INFO] Running test_misaligned_ram_access...");

        // Preload Word 0 (0x4433_2211) and Word 1 (0x8877_6655)
        tb_core.har_write_mem(DATA_ADDR + 0, 32'h4433_2211, 4'b1111, err);
        tb_core.har_write_mem(DATA_ADDR + 4, 32'h8877_6655, 4'b1111, err);
        tb_core.har_write_gpr(5'd1, DATA_ADDR);

        // 3.1 Misaligned LH at offset 1: bytes {0x33, 0x22} -> 0x0000_3322
        exec_single_insn(asm_lh(5'd5, 5'd1, 12'd1));
        tb_core.har_assert_gpr(5'd5, 32'h0000_3322, "misaligned lh at offset 1");

        // 3.2 Misaligned LH at offset 3 (crosses Word 0 -> Word 1!):
        // byte 3 of Word 0 (0x44) and byte 0 of Word 1 (0x55) -> 0x0000_5544
        exec_single_insn(asm_lh(5'd5, 5'd1, 12'd3));
        tb_core.har_assert_gpr(5'd5, 32'h0000_5544, "misaligned lh at offset 3 (word boundary crossing)");

        // 3.3 Misaligned LW at offset 1 (crosses Word 0 -> Word 1!):
        // bytes {0x55, 0x44, 0x33, 0x22} -> 0x5544_3322
        exec_single_insn(asm_lw(5'd5, 5'd1, 12'd1));
        tb_core.har_assert_gpr(5'd5, 32'h5544_3322, "misaligned lw at offset 1");

        // 3.4 Misaligned SW at offset 1: store 0x1234_5678 to DATA_ADDR + 1
        // Word 0 was 0xAAAA_AAAA, Word 1 was 0xBBBB_BBBB
        tb_core.har_write_mem(DATA_ADDR + 0, 32'hAAAA_AAAA, 4'b1111, err);
        tb_core.har_write_mem(DATA_ADDR + 4, 32'hBBBB_BBBB, 4'b1111, err);
        tb_core.har_write_gpr(5'd2, 32'h1234_5678);
        exec_single_insn(asm_sw(5'd2, 5'd1, 12'd1));
        tb_core.har_assert_mem(DATA_ADDR + 0, 32'h3456_78AA, "misaligned sw Word 0");
        tb_core.har_assert_mem(DATA_ADDR + 4, 32'hBBBB_BB12, "misaligned sw Word 1");
    endtask

    // =========================================================================
    // 4. Unexpected / Error / PMA & Alignment Trap Cases
    // =========================================================================
    task automatic test_lsu_exceptions();
        $display("[INFO] Running test_lsu_exceptions...");

        // 4.1 Store to Read-Only Boot ROM (0x0000_1000): raises EXC_STORE_ACCESS_FAULT (7)
        tb_core.har_write_gpr(5'd1, soc_pkg::BOOT_ROM_BASE);
        tb_core.har_write_gpr(5'd2, 32'hCAFE_BABE);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_sw(5'd2, 5'd1, 12'd0), 4'b1111, err);
        tb_core.har_assert_trap(EXC_STORE_ACCESS_FAULT, soc_pkg::MAIN_MEM_BASE, soc_pkg::BOOT_ROM_BASE, "store to read-only boot rom");
        // Verify boot rom was NOT modified
        tb_core.har_assert_mem(soc_pkg::BOOT_ROM_BASE, 32'h8000_02B7, "boot rom contents preserved");

        // 4.2 Null Pointer Dereference: load from 0x0000_0000 raises EXC_LOAD_ACCESS_FAULT (5)
        tb_core.har_write_gpr(5'd5, 32'hDEAD_BEEF);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_lw(5'd5, 5'd0, 12'd0), 4'b1111, err);
        tb_core.har_assert_trap(EXC_LOAD_ACCESS_FAULT, soc_pkg::MAIN_MEM_BASE, 32'h0000_0000, "null pointer load");
        tb_core.har_assert_gpr(5'd5, 32'hDEAD_BEEF, "faulting load does not overwrite rd");

        // 4.3 Misaligned load to non-idempotent MMIO raises EXC_LOAD_ADDR_MISALIGNED (4)
        tb_core.har_write_gpr(5'd1, soc_pkg::GPIO_BASE + 32'd1); // 0x1000_1001
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_lw(5'd5, 5'd1, 12'd0), 4'b1111, err);
        tb_core.har_assert_trap(EXC_LOAD_ADDR_MISALIGNED, soc_pkg::MAIN_MEM_BASE, soc_pkg::GPIO_BASE + 32'd1, "misaligned load to mmio");
    endtask

    // Runner for all LSU tests
    task automatic run_all();
        $display("----------------------------------------------------------------");
        $display("  tb_isa_lsu: Starting 8 RV32I Load & Store Tests               ");
        $display("----------------------------------------------------------------");
        test_aligned_loads();
        test_aligned_stores();
        test_misaligned_ram_access();
        test_lsu_exceptions();
        $display("----------------------------------------------------------------");
        $display("  tb_isa_lsu: Completed                                         ");
        $display("----------------------------------------------------------------");
    endtask

endmodule : tb_isa_lsu
