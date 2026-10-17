`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_muldiv.sv
// Module:      tb_isa_muldiv
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite for the 8 RV32M Integer Multiply
//   and Divide Instructions:
//     - Multiplication (4): `mul`, `mulh`, `mulhsu`, `mulhu` (3-cycle pipe)
//     - Division/Rem (4):   `div`, `divu`, `rem`, `remu`     (32-cycle iter)
// =============================================================================

module tb_isa_muldiv
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

    // =========================================================================
    // 1. MUL / MULH / MULHSU / MULHU
    // =========================================================================
    task automatic test_mul();
        $display("[INFO] Running test_mul...");

        // 1.1 MUL: 7 * 6 = 42
        tb_core.har_write_gpr(5'd1, 32'd7);
        tb_core.har_write_gpr(5'd2, 32'd6);
        exec_single_insn(asm_mul(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'd42, "mul 7 * 6 = 42");

        // 1.2 MUL negative: (-7) * 6 = -42 (0xFFFF_FFD6)
        tb_core.har_write_gpr(5'd1, -32'd7);
        exec_single_insn(asm_mul(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'hFFFF_FFD6, "mul (-7) * 6 = -42");

        // 1.3 MULH signed x signed: 0x4000_0000 * 4 = 2^32 -> mulh = 1, mul = 0
        tb_core.har_write_gpr(5'd1, 32'h4000_0000);
        tb_core.har_write_gpr(5'd2, 32'd4);
        exec_single_insn(asm_mulh(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'd1, "mulh 0x4000_0000 * 4 = 1");

        // 1.4 MULHU unsigned x unsigned: 0xFFFF_FFFF * 0xFFFF_FFFF -> mulhu = 0xFFFF_FFFE
        tb_core.har_write_gpr(5'd1, 32'hFFFF_FFFF);
        tb_core.har_write_gpr(5'd2, 32'hFFFF_FFFF);
        exec_single_insn(asm_mulhu(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'hFFFF_FFFE, "mulhu UINT_MAX * UINT_MAX");

        // 1.5 MULHSU signed x unsigned: (-1) * 2 = -2 -> mulhsu = 0xFFFF_FFFF
        tb_core.har_write_gpr(5'd1, 32'hFFFF_FFFF); // -1 signed
        tb_core.har_write_gpr(5'd2, 32'd2);          // +2 unsigned
        exec_single_insn(asm_mulhsu(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'hFFFF_FFFF, "mulhsu (-1) * 2 = high -1");

        // 1.6 MULHSU signed x unsigned contrast: (+2) * (0xFFFF_FFFF) -> mulhsu = 1
        tb_core.har_write_gpr(5'd1, 32'd2);          // +2 signed
        tb_core.har_write_gpr(5'd2, 32'hFFFF_FFFF); // 2^32 - 1 unsigned
        exec_single_insn(asm_mulhsu(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'd1, "mulhsu 2 * (2^32-1) = high 1");

        // 1.7 Multi-cycle pipeline RAW interlock: mul followed immediately by dependent addi
        tb_core.har_write_gpr(5'd1, 32'd10);
        tb_core.har_write_gpr(5'd2, 32'd20);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_mul(5'd3, 5'd1, 5'd2), 4'b1111, err); // x3 = 200
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_addi(5'd4, 5'd3, 12'd1), 4'b1111, err); // x4 = 201
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_gpr(5'd3, 32'd200, "mul x3 = 10 * 20 = 200");
        tb_core.har_assert_gpr(5'd4, 32'd201, "dependent addi x4 = x3 + 1 = 201");
    endtask

    // =========================================================================
    // 2. DIV / DIVU / REM / REMU
    // =========================================================================
    task automatic test_div_rem();
        $display("[INFO] Running test_div_rem...");

        // 2.1 DIV & REM signed positive: +20 / +6 = +3, rem = +2
        tb_core.har_write_gpr(5'd1, 32'd20);
        tb_core.har_write_gpr(5'd2, 32'd6);
        exec_single_insn(asm_div(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'd3, "div 20 / 6 = 3");
        exec_single_insn(asm_rem(5'd6, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd6, 32'd2, "rem 20 % 6 = 2");

        // 2.2 DIV & REM signed negative dividend: -20 / +6 = -3, rem = -2 (rem matches dividend sign!)
        tb_core.har_write_gpr(5'd1, -32'd20);
        tb_core.har_write_gpr(5'd2, 32'd6);
        exec_single_insn(asm_div(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, -32'd3, "div (-20) / 6 = -3");
        exec_single_insn(asm_rem(5'd6, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd6, -32'd2, "rem (-20) % 6 = -2");

        // 2.3 DIVU & REMU unsigned: 0xFFFF_FFFF / 10 = 429496729, rem = 5
        tb_core.har_write_gpr(5'd1, 32'hFFFF_FFFF);
        tb_core.har_write_gpr(5'd2, 32'd10);
        exec_single_insn(asm_divu(5'd5, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd5, 32'h1999_9999, "divu UINT_MAX / 10");
        exec_single_insn(asm_remu(5'd6, 5'd1, 5'd2));
        tb_core.har_assert_gpr(5'd6, 32'd5, "remu UINT_MAX % 10 = 5");

        // 2.4 Divide by Zero (DIV rd, rs1, x0) -> -1; REM -> rs1 (Must NOT trap!)
        tb_core.har_write_gpr(5'd1, 32'd42);
        tb_core.har_write_gpr(5'd2, 32'd0);
        exec_single_insn(asm_div(5'd5, 5'd1, 5'd2));
        if (!tr.trap_taken) $display("[PASS] div by zero does not trap"); else tb_core.test_errors++;
        tb_core.har_assert_gpr(5'd5, 32'hFFFF_FFFF, "div by zero returns -1");

        exec_single_insn(asm_rem(5'd6, 5'd1, 5'd2));
        if (!tr.trap_taken) $display("[PASS] rem by zero does not trap"); else tb_core.test_errors++;
        tb_core.har_assert_gpr(5'd6, 32'd42, "rem by zero returns dividend");

        // 2.5 Signed overflow (-2^31 / -1) -> -2^31, rem -> 0 (Must NOT trap!)
        tb_core.har_write_gpr(5'd1, 32'h8000_0000);
        tb_core.har_write_gpr(5'd2, 32'hFFFF_FFFF);
        exec_single_insn(asm_div(5'd5, 5'd1, 5'd2));
        if (!tr.trap_taken) $display("[PASS] div signed overflow does not trap"); else tb_core.test_errors++;
        tb_core.har_assert_gpr(5'd5, 32'h8000_0000, "div -2^31 / -1 returns -2^31");

        exec_single_insn(asm_rem(5'd6, 5'd1, 5'd2));
        if (!tr.trap_taken) $display("[PASS] rem signed overflow does not trap"); else tb_core.test_errors++;
        tb_core.har_assert_gpr(5'd6, 32'd0, "rem -2^31 / -1 returns 0");
    endtask

    // Runner for all MULDIV tests
    task automatic run_all();
        $display("----------------------------------------------------------------");
        $display("  tb_isa_muldiv: Starting 8 RV32M Multiply & Divide Tests       ");
        $display("----------------------------------------------------------------");
        test_mul();
        test_div_rem();
        $display("----------------------------------------------------------------");
        $display("  tb_isa_muldiv: Completed                                      ");
        $display("----------------------------------------------------------------");
    endtask

endmodule : tb_isa_muldiv
