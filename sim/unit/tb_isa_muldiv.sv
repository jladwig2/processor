`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_muldiv.sv
// Module:      tb_isa_muldiv
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite Stubs for the 8 RV32M Integer
//   Multiply and Divide Instructions:
//     - Multiplication (4): `mul`, `mulh`, `mulhsu`, `mulhu` (3-cycle pipe)
//     - Division/Rem (4):   `div`, `divu`, `rem`, `remu`     (32-cycle iter)
//
//   How Verification Works (Using `tb_core` Debug Harness Ports):
//     1. Preload `rs1` and `rs2` via `har_write_gpr`, load the RV32M instruction
//        (and dependent consumer instructions) into `axi_bram_mem` via
//        `har_write_mem`, and wait for retirement on `commit_trace`.
//     2. Verify multi-cycle pipeline interlocking: when an `add` immediately
//        follows a 3-cycle `mul` or 32-cycle `div` and reads its `rd`, verify
//        via `har_assert_gpr` that `dispatch.sv` stalls the dependent `add`
//        until `mul`/`div` completes and forwards the exact final result.
//     3. Verify RISC-V division corner cases (divide-by-zero and signed
//        overflow `-2^31 / -1`) complete with the exact mandated register
//        values and `commit_trace.trap_taken == 1'b0`.
// =============================================================================

module tb_isa_muldiv
    import rv_pkg::*;
    import core_pkg::*;
;

    // =========================================================================
    // 1. MUL / MULH / MULHSU / MULHU (3-Cycle Pipelined Multiplier)
    // =========================================================================
    // Intended Cases:
    //   - `mul` (lower 32 bits):
    //       * `7 * 6 = 42`; `(-7) * 6 = -42 (0xFFFF_FFD6)`; `(-7) * (-6) = 42`;
    //         `x * 0 = 0`; `x * 1 = x`.
    //   - `mulh` (upper 32 bits of signed × signed):
    //       * `0x4000_0000 * 4` (`2^30 * 4 = 2^32`): `mul = 0x0000_0000`,
    //         `mulh = 0x0000_0001`.
    //       * `(-2) * 2 = -4 (64'hFFFF_FFFF_FFFF_FFFC)`: `mulh = 0xFFFF_FFFF`.
    //       * `0x8000_0000 * 0x8000_0000` (`(-2^31) * (-2^31) = +2^62`):
    //         `mulh = 0x4000_0000`, `mul = 0x0000_0000`.
    //   - `mulhu` (upper 32 bits of unsigned × unsigned):
    //       * `0xFFFF_FFFF * 0xFFFF_FFFF = 64'hFFFF_FFFE_0000_0001`:
    //         `mulhu = 0xFFFF_FFFE`, `mul = 0x0000_0001`.
    //   - `mulhsu` (upper 32 bits of signed `rs1` × unsigned `rs2`):
    //       * `rs1 = -1 (0xFFFF_FFFF)`, `rs2 = 2`: product is `-2`
    //         (`64'hFFFF_FFFF_FFFF_FFFE`) -> `mulhsu = 0xFFFF_FFFF`.
    //       * Contrast with `rs1 = +2`, `rs2 = 0xFFFF_FFFF (2^32 - 1)`:
    //         product is `64'h0000_0001_FFFF_FFFE` -> `mulhsu = 0x0000_0001`!
    //   - Back-to-Back Multiplies & Dependent ALU Interlock:
    //       * `mul x3, x1, x2` -> `addi x4, x3, 1`: verify `x4 == (x1 * x2) + 1`.
    //
    // Unexpected / Corner / Error Cases:
    //   - Flush Mid-Multiply:
    //       * Issue an older faulting instruction (e.g., `lw` from unmapped
    //         address or `ecall`) followed by `mul x5, x1, x2`. Verify that the
    //         trap flushes `mul.sv` and `x5` retains its preloaded sentinel
    //         `32'hDEAD_BEEF`.
    //   - `HAS_MULDIV == 1'b0` Parameter Check:
    //       * When synthesized with `HAS_MULDIV = 0`, any `mul*` encoding must
    //         raise `EXC_ILLEGAL_INSTR` (`mcause = 2`).
    task automatic test_mul();
        // TODO: Implement stimulus & harness checks for `mul`, `mulh`, `mulhsu`, `mulhu`
    endtask

    // =========================================================================
    // 2. DIV / DIVU / REM / REMU (32-Cycle Iterative Divider)
    // =========================================================================
    // Intended Cases:
    //   - `div` / `rem` (Signed division & remainder, truncating toward zero):
    //       * `+20 / +6 = +3`,  `+20 % +6 = +2`  (`3*6 + 2 = 20`)
    //       * `-20 / +6 = -3`,  `-20 % +6 = -2`  (`(-3)*6 + (-2) = -20`)
    //       * `+20 / -6 = -3`,  `+20 % -6 = +2`  (`(-3)*(-6) + 2 = 20`)
    //       * `-20 / -6 = +3`,  `-20 % -6 = -2`  (`3*(-6) + (-2) = -20`)
    //       * Note: Remainder sign ALWAYS matches the dividend (`rs1`) sign!
    //   - `divu` / `remu` (Unsigned division & remainder):
    //       * `0x8000_0000 / 2 = 0x4000_0000`, `remu = 0`.
    //       * `0xFFFF_FFFF / 10 = 429496729 (0x1999_9999)`, `remu = 5`.
    //
    // Unexpected / Corner / Error Cases (RISC-V Unprivileged Spec §7.2 Table 7.1):
    //   - **Divide by Zero (`rs2 == 0`) — Must NOT Trap:**
    //       * `div  rd, rs1, x0` (for `rs1 = 42` and `rs1 = -42`):
    //         Verify `trap_taken == 0` and `har_assert_gpr(rd, 32'hFFFF_FFFF)`.
    //       * `divu rd, rs1, x0`:
    //         Verify `trap_taken == 0` and `har_assert_gpr(rd, 32'hFFFF_FFFF)`.
    //       * `rem  rd, rs1, x0` and `remu rd, rs1, x0`:
    //         Verify `trap_taken == 0` and `har_assert_gpr(rd, rs1)` (returns
    //         the dividend unchanged!).
    //   - **Signed Division Overflow (`-2^31 / -1`) — Must NOT Trap:**
    //       * `rs1 = 32'h8000_0000` (`-2147483648`), `rs2 = 32'hFFFF_FFFF` (`-1`):
    //       * `div rd, rs1, rs2`: Verify `trap_taken == 0` and
    //         `har_assert_gpr(rd, 32'h8000_0000)`.
    //       * `rem rd, rs1, rs2`: Verify `trap_taken == 0` and
    //         `har_assert_gpr(rd, 32'h0000_0000)`.
    //   - Note that unsigned `divu`/`remu` with `0x8000_0000` and `0xFFFF_FFFF`
    //     is NOT overflow (`2^31 / (2^32 - 1) = 0`, remainder `0x8000_0000`)!
    task automatic test_div_rem();
        // TODO: Implement stimulus & harness checks for `div`, `divu`, `rem`, `remu`
    endtask

endmodule : tb_isa_muldiv

