`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_alu.sv
// Module:      tb_isa_alu
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite Stubs for the 21 RV32I Integer ALU
//   and Upper-Immediate Instructions:
//     - R-Type (10): `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`,
//                    `or`, `and`
//     - I-Type (9):  `addi`, `slli`, `slti`, `sltiu`, `xori`, `srli`, `srai`,
//                    `ori`, `andi`
//     - U-Type (2):  `lui`, `auipc`
//
//   How Verification Works (Using `tb_core` Debug Harness Ports):
//     1. Preload source GPRs (`rs1`, `rs2`) and a known sentinel (`0xDEAD_BEEF`)
//        into destination GPR `rd` via `har_write_gpr`, and write the 32-bit
//        instruction encoding into `axi_bram_mem` via `har_write_mem` (Debug SBA).
//     2. Release core reset (or step one instruction) and capture `commit_trace`
//        via `har_wait_retire`.
//     3. For **Intended Behavior Cases**:
//        - Verify `commit_trace.trap_taken == 1'b0`.
//        - Read `rd` from `prf.sv` via `har_assert_gpr(rd, expected_val, ...)`
//          and verify `har_assert_gpr(5'd0, 32'h0, "x0 hardwired zero")`.
//        - Verify `CSR_MINSTRET` incremented by 1 via `har_assert_csr`.
//     4. For **Unexpected / Error / Trap Cases**:
//        - Verify `commit_trace.trap_taken == 1'b1` with `EXC_ILLEGAL_INSTR`
//          (`mcause = 2`), `mepc == faulting_pc`, and `mtval == faulting_insn`
//          via `har_assert_trap`.
//        - Read `rd` via `har_assert_gpr(rd, 32'hDEAD_BEEF, ...)` to prove the
//          trapping instruction did NOT corrupt the destination register!
// =============================================================================

module tb_isa_alu
    import rv_pkg::*;
    import core_pkg::*;
;

    // =========================================================================
    // 1. ADD / ADDI / SUB
    // =========================================================================
    // Intended Cases:
    //   - `add`:  `15 + 27 = 42`; `(-10) + 10 = 0`; `0 + 0 = 0`.
    //   - `addi`: Sign-extension of 12-bit immediate:
    //       * Positive max `imm = +2047` (`12'h7FF`): `100 + 2047 = 2147`.
    //       * Negative `imm = -1` (`12'hFFF`): `100 + (-1) = 99`.
    //       * Negative min `imm = -2048` (`12'h800`): `2048 + (-2048) = 0`.
    //   - `sub`:  `50 - 18 = 32`; `18 - 50 = -32 (0xFFFF_FFE0)`; `x - x = 0`.
    //   - Pipeline Forwarding (RAW Bypass):
    //       * `addi x1, x0, 10` followed immediately by `add x2, x1, x1` (tests
    //         Stage X -> Stage I bypass: `x2 == 20`) followed by `sub x3, x2, x1`
    //         (tests StageX + Stage C simultaneous bypass: `x3 == 10`).
    //
    // Unexpected / Corner / Error Cases:
    //   - Signed Overflow Wrap-Around (Must NOT trap in RISC-V!):
    //       * `add`: `0x7FFF_FFFF + 1 = 0x8000_0000` (`INT32_MAX + 1 -> INT32_MIN`),
    //         verified with `trap_taken == 0` and `har_assert_gpr(rd, 32'h8000_0000)`.
    //       * `sub`: `0x8000_0000 - 1 = 0x7FFF_FFFF` (`INT32_MIN - 1 -> INT32_MAX`).
    //   - Destination `rd = x0`:
    //       * `addi x0, x0, 123`: Verify `x0` remains `32'h0000_0000` via
    //         `har_assert_gpr(5'd0, 32'h0)` and subsequent `add x4, x0, x0` -> `0`.
    //   - Illegal `funct7` Encoding on `OPCODE_OP` (`F3_ADD_SUB`):
    //       * `funct7 = 7'b0000010` (neither `0000000` nor `0100000` nor `0000001`):
    //         Must trap with `EXC_ILLEGAL_INSTR` (`mcause = 2`) and leave `rd`
    //         at `32'hDEAD_BEEF`.
    task automatic test_add_addi_sub();
        // TODO: Implement stimulus & harness checks for `add`, `addi`, `sub`
    endtask

    // =========================================================================
    // 2. SLL / SLLI / SRL / SRLI / SRA / SRAI (Barrel Shifter)
    // =========================================================================
    // Intended Cases:
    //   - `sll` / `slli`: Shift `32'h0000_0001` by `0` (`0x1`), `1` (`0x2`),
    //     `16` (`0x0001_0000`), and `31` (`0x8000_0000`).
    //   - `srl` / `srli`: Logical right-shift of negative value `32'h8000_0000`
    //     by `1` -> `32'h4000_0000` (zero-fills MSB), by `31` -> `32'h0000_0001`.
    //   - `sra` / `srai`: Arithmetic right-shift of negative value `32'h8000_0000`
    //     by `1` -> `32'hC000_0000` (sign-extends MSB), by `31` -> `32'hFFFF_FFFF`;
    //     and positive value `32'h4000_0000` by `1` -> `32'h2000_0000`.
    //
    // Unexpected / Corner / Error Cases:
    //   - Shift Amount > 31 in `rs2` (`sll`, `srl`, `sra`):
    //       * Only `rs2[4:0]` is used; upper bits `rs2[31:5]` must be ignored!
    //       * Set `rs2 = 32'hFFFF_FFE4` (`rs2[4:0] == 5'd4`): shifting `32'h1`
    //         left by `rs2` must produce `32'h0000_0010` (shift by 4, NOT 0).
    //   - Illegal `shamt[5]` / `funct7` in `slli`, `srli`, `srai` (RV32I rule):
    //       * On RV32I, `inst[25]` (`shamt[5]`) must be `0`. Encoding a 64-bit
    //         shift immediate (`inst[25] == 1'b1`) or setting `inst[30] == 1'b1`
    //         on `slli` must raise `EXC_ILLEGAL_INSTR` (`mcause = 2`) and leave
    //         `rd` unmodified (`32'hDEAD_BEEF`).
    task automatic test_shifts();
        // TODO: Implement stimulus & harness checks for `sll[i]`, `srl[i]`, `sra[i]`
    endtask

    // =========================================================================
    // 3. SLT / SLTI / SLTU / SLTIU (Signed & Unsigned Comparisons)
    // =========================================================================
    // Intended Cases:
    //   - `slt` / `slti` (Signed):
    //       * `(-1 < 1)` -> `32'd1`; `(1 < -1)` -> `32'd0`.
    //       * `(0x8000_0000 < 0x7FFF_FFFF)` -> `32'd1` (`INT32_MIN < INT32_MAX`).
    //       * Equal operands `(42 < 42)` -> `32'd0`.
    //   - `sltu` / `sltiu` (Unsigned):
    //       * `(32'hFFFF_FFFF < 32'd1)` -> `32'd0` (`UINT32_MAX` is > 1).
    //       * `(32'd0 < 32'hFFFF_FFFF)` -> `32'd1`.
    //       * `sltiu rd, rs1, -1` (`seqz` / `snez` idioms: `imm = 12'hFFF`
    //         sign-extends to `32'hFFFF_FFFF` first, then compares unsigned!).
    //
    // Unexpected / Corner / Error Cases:
    //   - Sign-Extension before Unsigned Compare in `sltiu`:
    //       * Verify `sltiu rd, x0, -1` (`imm = 12'hFFF`) compares `0 < 0xFFFF_FFFF`
    //         -> `1`, and `sltiu rd, rs1, -1` with `rs1 = 0xFFFF_FFFF` yields `0`.
    //   - Reserved `funct7 != 7'b0000000` on `slt` / `sltu`:
    //       * Setting `funct7 = 7'b0100000` on `slt` must raise `EXC_ILLEGAL_INSTR`
    //         (`mcause = 2`) and leave `rd` unmodified.
    task automatic test_compares();
        // TODO: Implement stimulus & harness checks for `slt[i]`, `sltu`/`sltiu`
    endtask

    // =========================================================================
    // 4. XOR / XORI / OR / ORI / AND / ANDI (Bitwise Logical)
    // =========================================================================
    // Intended Cases:
    //   - `xor` / `xori`: `0xAAAA_5555 ^ 0x5555_AAAA = 0xFFFF_FFFF`;
    //     `xori rd, rs1, -1` (`not` pseudo-instruction) inverts all 32 bits.
    //   - `or`  / `ori`:  `0xF0F0_0000 | 0x0000_0F0F = 0xF0F0_0F0F`.
    //   - `and` / `andi`: `0xFFFF_FFFF & 0x1234_5678 = 0x1234_5678`.
    //
    // Unexpected / Corner / Error Cases:
    //   - Negative 12-bit Immediate Sign-Extension on `andi` / `ori` / `xori`:
    //       * `andi rd, rs1, -1` (`imm = 12'hFFF`) sign-extends to `32'hFFFF_FFFF`
    //         (preserves all 32 bits of `rs1`, NOT masking to 12 bits!).
    //   - Reserved `funct7 != 7'b0000000` on `xor` / `or` / `and`:
    //       * Setting `funct7 = 7'b0100000` on `and` (no `andn` in base RV32I)
    //         must raise `EXC_ILLEGAL_INSTR` (`mcause = 2`) and leave `rd` untouched.
    task automatic test_bitwise();
        // TODO: Implement stimulus & harness checks for `xor[i]`, `or[i]`, `and[i]`
    endtask

    // =========================================================================
    // 5. LUI / AUIPC (Upper-Immediate Instructions)
    // =========================================================================
    // Intended Cases:
    //   - `lui`:   `lui x5, 0x12345` -> `x5 == 32'h1234_5000` (low 12 bits zeroed).
    //   - `auipc`: Executed at `PC = 32'h8000_0010` with `imm20 = 0x00001` ->
    //              `rd == 32'h8000_1010` (`PC + (imm20 << 12)`).
    //   - `auipc` + `addi` 32-bit PC-relative address formation pair.
    //
    // Unexpected / Corner / Error Cases:
    //   - `lui x0, 0xFFFFF`: Writing `x0` must be discarded (`x0 == 32'h0`).
    //   - `auipc` with negative upper immediate (`imm20 = 0xFFFFF`, i.e., `-4096`):
    //     Executed at `PC = 32'h8000_1000` -> wraps cleanly to `32'h8000_0000`
    //     without trapping.
    task automatic test_upper_imm();
        // TODO: Implement stimulus & harness checks for `lui` and `auipc`
    endtask

endmodule : tb_isa_alu

