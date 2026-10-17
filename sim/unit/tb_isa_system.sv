`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_system.sv
// Module:      tb_isa_system
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite Stubs for the 12 Zicsr, Zifencei,
//   Zicntr, and Machine-Mode System/Trap Instructions:
//     - Zicsr (6):        `csrrw`, `csrrs`, `csrrc`, `csrrwi`, `csrrsi`, `csrrci`
//     - Memory Fence (2): `fence`, `fence.i`
//     - System/Trap (4):  `ecall`, `ebreak`, `mret`, `wfi`
//
//   How Verification Works (Using `tb_core` Debug Harness Ports):
//     1. Uses `har_read_csr` / `har_assert_csr` and `har_assert_gpr` to verify
//        atomic CSR read-modify-write semantics, counter increments (`mcycle`,
//        `minstret`), and WARL bit masking (`mstatus`, `misa`, `mtvec`).
//     2. Uses `har_assert_trap` to verify synchronous exceptions (`ecall`,
//        `ebreak`, illegal CSR access, read-only CSR write) and asynchronous
//        interrupt entry (`meip`, `mtip`, `msip`), checking `mepc`, `mcause`,
//        `mtval`, `mstatus.MIE`/`MPIE`, and `mtvec` direct vs. vectored jumps.
// =============================================================================

module tb_isa_system
    import rv_pkg::*;
    import core_pkg::*;
;

    // =========================================================================
    // 1. Zicsr Atomic Read-Modify-Write (`csrrw[i]`, `csrrs[i]`, `csrrc[i]`)
    // =========================================================================
    // Intended Cases:
    //   - `csrrw` / `csrrwi` on `CSR_MSCRATCH` (`0x340`):
    //       * Preload `mscratch = 32'h1111_2222`, `x1 = 32'hAABB_CCDD`.
    //       * Execute `csrrw x2, mscratch, x1`: verify `x2 == 32'h1111_2222`
    //         via `har_assert_gpr` and `mscratch == 32'hAABB_CCDD` via
    //         `har_assert_csr`.
    //       * Same-register swap `csrrw x1, mscratch, x1`: verify old `mscratch`
    //         goes into `x1` and old `x1` goes into `mscratch` atomically!
    //       * `csrrwi x3, mscratch, 5'd19`: zero-extends 5-bit `zimm` to
    //         `32'h0000_0013`.
    //   - `csrrs` / `csrrsi` (Atomic Read and Set Bits):
    //       * Sets only bits where mask is `1` (`new_csr = old_csr | mask`),
    //         returning `old_csr` in `rd`.
    //   - `csrrc` / `csrrci` (Atomic Read and Clear Bits):
    //       * Clears only bits where mask is `1` (`new_csr = old_csr & ~mask`),
    //         returning `old_csr` in `rd`.
    //   - Read-Only CSR Inspection via `csrrs rd, csr, x0` (`csrr` pseudo-op):
    //       * Because `rs1 == x0` (`zimm == 0`), `csrrs`/`csrrc` do NOT write
    //         the CSR and must succeed without trapping on Read-Only CSRs:
    //         `mhartid` (`0xF14` == 0), `mimpid` (`0xF13` == 2), `cycle`
    //         (`0xC00`), `time` (`0xC01`), `instret` (`0xC02`).
    //   - Zicntr / Machine Performance Counters (`mcycle[h]`, `minstret[h]`):
    //       * Read `minstret` before and after a 5-instruction sequence; verify
    //         `minstret` increased by exactly 5.
    //       * Write a known value to `mcycle` and `minstret` via `csrrw` and
    //         verify subsequent reads reflect the new value.
    //
    // Unexpected / Corner / Error Cases:
    //   - **Write to Read-Only CSR (`csr_addr[11:10] == 2'b11`):**
    //       * `csrrw x1, mhartid, x2` (even if `x2 == 0` or `rs1 == x0`,
    //         `csrrw` ALWAYS performs a write per RISC-V Spec §9.1!):
    //         Must raise `EXC_ILLEGAL_INSTR` (`mcause = 2`) and leave `x1`
    //         unmodified (`32'hDEAD_BEEF`).
    //       * `csrrs x1, cycle, x2` with `rs1 != x0`:
    //         Must raise `EXC_ILLEGAL_INSTR` (`mcause = 2`).
    //   - **Access to Unimplemented / Non-Existent CSR (Probed by `riscv_test.h`):**
    //       * Attempt `csrr x1, satp` (`0x180`), `csrr x1, medeleg` (`0x302`),
    //         `csrr x1, pmpcfg0` (`0x3A0`), and `csrr x1, 0x744` (`mnstatus`):
    //         Each must raise `EXC_ILLEGAL_INSTR` (`mcause = 2`, `mepc = csrr_pc`,
    //         `mtval = insn`) and leave `x1` untouched!
    task automatic test_zicsr_and_counters();
        // TODO: Implement stimulus & harness checks for `csrrw[i]`, `csrrs[i]`, `csrrc[i]`
    endtask

    // =========================================================================
    // 2. FENCE / FENCE.I (Self-Modifying Code Pipeline Flush)
    // =========================================================================
    // Intended Cases:
    //   - `fence`: Retires as a 1-cycle architectural no-op in M1's in-order
    //     single-core pipeline without trapping.
    //   - `fence.i` (Self-Modifying Code Test):
    //       * Place `addi x5, x0, 1` at `PC = 0x8000_0010` right after `fence.i`
    //         at `PC = 0x8000_000C` (so `frontend.sv` has already pre-fetched
    //         the old `addi x5, x0, 1` into `fetch_queue`!).
    //       * At `PC = 0x8000_0008` (just before `fence.i`), execute `sw` to
    //         overwrite `0x8000_0010` with `addi x5, x0, 99`.
    //       * When `fence.i` commits at `0x8000_000C`, it flushes the stale
    //         pre-fetched instruction in `fetch_queue`/`decode` and redirects
    //         Fetch to `0x8000_0010`.
    //       * Verify via `har_assert_gpr(5'd5, 32'd99, ...)` that the newly
    //         stored instruction (`99`) executed, NOT the stale pre-fetched (`1`)!
    task automatic test_fence_and_fence_i();
        // TODO: Implement stimulus & harness checks for `fence` and `fence.i`
    endtask

    // =========================================================================
    // 3. ECALL / EBREAK / MRET / WFI & Interrupt Entry (`trap_ctrl.sv`)
    // =========================================================================
    // Intended Cases:
    //   - `ecall` (at `PC = 0x8000_0020`, with `mtvec = 0x8000_0100`,
    //     `mstatus.MIE = 1`):
    //       * Raises synchronous exception `EXC_ECALL_M` (`mcause = 32'd11`).
    //       * Verify via `har_assert_csr`:
    //           - `CSR_MEPC`    == `32'h8000_0020`
    //           - `CSR_MCAUSE`  == `32'h0000_000B` (11)
    //           - `CSR_MTVAL`   == `32'h0000_0000`
    //           - `CSR_MSTATUS`: `MPIE == 1`, `MIE == 0`, `MPP == 2'b11`
    //       * Verify next retired instruction is at `mtvec` (`0x8000_0100`),
    //         and `minstret` did NOT increment on the trapping `ecall`!
    //   - `ebreak` (at `PC = 0x8000_0024`):
    //       * Raises `EXC_BREAKPOINT` (`mcause = 32'd3`, `mepc = 0x8000_0024`,
    //         `mtval = 0x8000_0024`).
    //   - `mret`:
    //       * Handler adds 4 to `mepc` (`csrrw`), executes `mret`.
    //       * Verify `mstatus.MIE` restored from `MPIE` (`1`), `MPIE` set to `1`,
    //         and execution resumes at `mepc` (`0x8000_0024`).
    //   - `wfi`:
    //       * Retires cleanly without trapping.
    //   - Asynchronous Interrupt Entry (`meip`, `mtip`, `msip`):
    //       * Enable `mstatus.MIE = 1` and `mie.MTIE = 1`; assert `mtip = 1`.
    //       * Verify interrupt is taken at the Commit boundary with
    //         `mcause = 32'h8000_0007` (MSB = 1, cause = 7) and test both
    //         Direct (`mtvec[1:0] == 2'b00` -> `base`) and Vectored
    //         (`mtvec[1:0] == 2'b01` -> `base + 4 * 7`) modes!
    //
    // Unexpected / Corner / Error Cases:
    //   - Simultaneous Interrupt Priority Check (`meip && mtip && msip` all high):
    //       * Per RISC-V Privileged Spec §3.1.9, priority must be:
    //         `MEI (11) > MSI (3) > MTI (7)`. Verify `mcause == 32'h8000_000B`.
    //   - Malformed `OPCODE_SYSTEM` with `funct3 == 3'b000` (`F3_PRIV`):
    //       * If `rs1 != 5'd0` or `rd != 5'd0` on `ecall`/`ebreak`/`mret`/`wfi`,
    //         or if `funct12` is unrecognized, must raise `EXC_ILLEGAL_INSTR`
    //         (`mcause = 2`).
    task automatic test_traps_mret_and_interrupts();
        // TODO: Implement stimulus & harness checks for `ecall`, `ebreak`, `mret`, `wfi`, and IRQs
    endtask

endmodule : tb_isa_system

