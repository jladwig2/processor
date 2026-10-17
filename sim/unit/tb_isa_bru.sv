`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_bru.sv
// Module:      tb_isa_bru
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite Stubs for the 8 RV32I Control-Transfer
//   Instructions:
//     - Conditional Branches (6): `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`
//     - Unconditional Jumps (2):  `jal`, `jalr`
//
//   How Verification Works (Using `tb_core` Debug Harness Ports):
//     1. Preload `rs1`, `rs2`, and sentinel values into GPRs that would be
//        clobbered by wrong-path instructions (`x10 = 32'hCAFE_0000`) via
//        `har_write_gpr`, and write the branch/jump test sequence into
//        `axi_bram_mem` via `har_write_mem` (Debug SBA).
//     2. Step through retirement using `har_wait_retire`:
//        - Verify that the next retired `commit_trace.pc` equals the expected
//          branch target (when taken) or `pc + 4` (when not taken).
//        - Read `x10` via `har_assert_gpr` to prove that younger instructions
//          fetched along the wrong path in Stages F/D/I were squashed by
//          `bru.sv` (`redirect_valid_o`) and NEVER wrote the register file!
//     3. For **Misaligned Target / Exception Cases**:
//        - Verify `har_assert_trap(EXC_INSTR_ADDR_MISALIGNED, branch_pc,
//          bad_target_pc, ...)` (`mcause = 0`, `mepc = branch_pc`,
//          `mtval = bad_target_pc`).
//        - For `jal` / `jalr` to a misaligned target, read `rd` via
//          `har_assert_gpr` to prove that `rd` was NOT overwritten with
//          `pc + 4` when the jump faulted!
// =============================================================================

module tb_isa_bru
    import rv_pkg::*;
    import core_pkg::*;
;

    // =========================================================================
    // 1. BEQ / BNE (Equality & Inequality Branches)
    // =========================================================================
    // Intended Cases:
    //   - `beq`: Taken when `rs1 == rs2` (`42 == 42`, `0 == 0`, `-1 == -1`);
    //     Not-taken when `rs1 != rs2` (`42 != 43`), advancing to `pc + 4`.
    //   - `bne`: Taken when `rs1 != rs2`; Not-taken when `rs1 == rs2`.
    //   - Both forward branch offset (`+16` bytes) and backward branch offset
    //     (`-8` bytes loop counter).
    //   - Wrong-Path Squash Verification:
    //       * Place `addi x10, x0, 99` immediately after a taken `beq` at
    //         `pc + 4` and `addi x11, x0, 55` at `target`. Verify via
    //         `har_assert_gpr` that `x10` retains its initial value (`0`) while
    //         `x11 == 55`.
    //
    // Unexpected / Corner / Error Cases:
    //   - Taken Branch to 2-Byte Misaligned Target (`offset = +6`, `target[1:0] == 2'b10`):
    //       * Because `C` extension is not enabled, a taken branch to `pc + 6`
    //         must raise `EXC_INSTR_ADDR_MISALIGNED` (`mcause = 0`,
    //         `mepc = branch_pc`, `mtval = branch_pc + 6`).
    //   - **Critical Spec Rule — Untaken Branch with Misaligned Offset Must NOT Trap:**
    //       * Execute `beq x1, x2, +6` when `x1 != x2` (branch NOT taken):
    //         Per RISC-V Unprivileged Spec §2.5, instruction-address-misaligned
    //         exceptions are NOT raised by conditional branches that are not
    //         taken! Verify `trap_taken == 0` and execution continues at `pc + 4`.
    task automatic test_beq_bne();
        // TODO: Implement stimulus & harness checks for `beq` and `bne`
    endtask

    // =========================================================================
    // 2. BLT / BGE / BLTU / BGEU (Signed & Unsigned Relational Branches)
    // =========================================================================
    // Intended Cases:
    //   - `blt` (Signed `<`):
    //       * Taken for `(-5 < 2)` and `(0x8000_0000 < 0x7FFF_FFFF)`.
    //       * Not-taken for `(2 < -5)` and equal operands `(-5 < -5)`.
    //   - `bge` (Signed `>=`):
    //       * Taken for `(2 >= -5)` and equal operands `(-5 >= -5)`.
    //       * Not-taken for `(-5 >= 2)`.
    //   - `bltu` (Unsigned `<`):
    //       * Taken for `(32'd1 < 32'hFFFF_FFFF)`.
    //       * Not-taken for `(32'hFFFF_FFFF < 32'd1)` and equal operands.
    //   - `bgeu` (Unsigned `>=`):
    //       * Taken for `(32'hFFFF_FFFF >= 32'd1)` and equal operands.
    //       * Not-taken for `(32'd1 >= 32'hFFFF_FFFF)`.
    //
    // Unexpected / Corner / Error Cases:
    //   - Reserved `OPCODE_BRANCH` `funct3` Encodings (`3'b010` and `3'b011`):
    //       * Must raise `EXC_ILLEGAL_INSTR` (`mcause = 2`, `mtval = insn`).
    //   - Taken Branch into Non-Executable MMIO (`0x1000_0000`) or Unmapped Space:
    //       * Branch itself retires cleanly, and the subsequent instruction
    //         fetch at the target raises `EXC_INSTR_ACCESS_FAULT` (`mcause = 1`,
    //         `mepc = target_pc`, `mtval = target_pc`).
    task automatic test_relational_branches();
        // TODO: Implement stimulus & harness checks for `blt`, `bge`, `bltu`, `bgeu`
    endtask

    // =========================================================================
    // 3. JAL / JALR (Unconditional Jumps & Subroutine Calls)
    // =========================================================================
    // Intended Cases:
    //   - `jal rd, offset`:
    //       * Writes link address `rd = pc + 4` (verified via `har_assert_gpr`)
    //         and redirects execution to `pc + offset`.
    //       * `jal x0, offset` (`j` pseudo-op): jumps without modifying `x0`.
    //   - `jalr rd, rs1, imm`:
    //       * Computes target `(rs1 + imm) & ~32'd1` and writes `rd = pc + 4`.
    //       * **LSB Clearing Check:** Set `rs1 = 32'h8000_0101` and `imm = 0`;
    //         verify `jalr` clears bit 0 and jumps cleanly to `32'h8000_0100`
    //         without raising a misaligned exception!
    //       * **Same-Register `rd == rs1` Check (`jalr x5, 8(x5)`):**
    //         Verify target uses the old value of `x5` while `x5` receives
    //         `pc + 4` upon retirement.
    //
    // Unexpected / Corner / Error Cases:
    //   - `jal` or `jalr` with Bit [1] Set in Target (`target[1:0] == 2'b10`):
    //       * Raises `EXC_INSTR_ADDR_MISALIGNED` (`mcause = 0`, `mepc = jal_pc`,
    //         `mtval = target_pc`).
    //       * **Critical Atomic Trap Rule:** Verify via `har_assert_gpr(rd,
    //         32'hDEAD_BEEF)` that the faulting `jal`/`jalr` did NOT write
    //         `pc + 4` into `rd`!
    //   - `jalr` with Non-Zero `funct3` (`funct3 != 3'b000`):
    //       * Must raise `EXC_ILLEGAL_INSTR` (`mcause = 2`) and leave `rd`
    //         unmodified.
    task automatic test_jal_jalr();
        // TODO: Implement stimulus & harness checks for `jal` and `jalr`
    endtask

endmodule : tb_isa_bru

