`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_lsu.sv
// Module:      tb_isa_lsu
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite Stubs for the 8 RV32I Load and Store
//   Instructions:
//     - Loads (5):  `lb`, `lh`, `lw`, `lbu`, `lhu`
//     - Stores (3): `sb`, `sh`, `sw`
//
//   How Verification Works (Using `tb_core` Debug Harness Ports):
//     1. Preload target memory words in `axi_bram_mem` via the Debug SBA port
//        (`har_write_mem`) and preload base/data GPRs (`rs1`, `rs2`, `rd`) via
//        `har_write_gpr`.
//     2. After a Load instruction retires:
//        - Inspect `rd` via `har_assert_gpr` to verify byte lane extraction and
//          sign/zero extension.
//     3. After a Store instruction retires:
//        - Read the modified 32-bit word (and adjacent words) directly from
//          `axi_bram_mem` via `har_assert_mem` (Debug SBA) to prove that ONLY
//          the intended byte lanes were modified!
//     4. After a Faulting Load or Store (ROM write, unmapped address, or
//        misaligned MMIO):
//        - Verify `har_assert_trap` with the exact `mcause` (`4, 5, 6, 7`) and
//          `mtval == faulting_eff_addr`.
//        - Verify via `har_assert_gpr` (for loads) or `har_assert_mem` (for
//          stores to ROM) that neither the destination register nor memory was
//          modified!
// =============================================================================

module tb_isa_lsu
    import soc_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
;

    // =========================================================================
    // 1. Aligned Loads: LB / LBU / LH / LHU / LW
    // =========================================================================
    // Intended Cases:
    //   - Preload `0x8000_2000` with `32'h807F_8001` via `har_write_mem`:
    //       * `lb`  offset `0` (`0x01`) -> `32'h0000_0001`
    //       * `lb`  offset `1` (`0x80`) -> `32'hFFFF_FF80` (sign-extended!)
    //       * `lbu` offset `1` (`0x80`) -> `32'h0000_0080` (zero-extended!)
    //       * `lb`  offset `2` (`0x7F`) -> `32'h0000_007F`
    //       * `lb`  offset `3` (`0x80`) -> `32'hFFFF_FF80`
    //       * `lh`  offset `0` (`0x8001`) -> `32'hFFFF_8001` (sign-extended!)
    //       * `lhu` offset `0` (`0x8001`) -> `32'h0000_8001` (zero-extended!)
    //       * `lh`  offset `2` (`0x807F`) -> `32'hFFFF_807F`
    //       * `lw`  offset `0` -> `32'h807F_8001`
    //   - Positive and Negative 12-bit Address Offset (`imm = +2047`, `imm = -2048`).
    //   - Load-to-Use RAW Hazard Interlock:
    //       * `lw x5, 0(x1)` followed immediately by `addi x6, x5, 1`: verify
    //         `x6 == 32'h807F_8002`.
    task automatic test_aligned_loads();
        // TODO: Implement stimulus & harness checks for aligned `lb`, `lbu`, `lh`, `lhu`, `lw`
    endtask

    // =========================================================================
    // 2. Aligned Stores: SB / SH / SW (Byte-Lane Masking Verification via SBA)
    // =========================================================================
    // Intended Cases:
    //   - Preload `0x8000_2000` with `32'h1122_3344` via `har_write_mem`:
    //       * Execute `sb` with `rs2 = 32'hDEAD_BEEF` at offset `0`:
    //         Verify via `har_assert_mem(32'h8000_2000, 32'h1122_33EF)` (only
    //         low byte `rs2[7:0]` written to lane 0; upper 24 bits of `rs2`
    //         ignored; lanes 1..3 of memory preserved!).
    //       * Execute `sb` at offsets `1`, `2`, and `3`, checking memory via
    //         `har_assert_mem` after each store.
    //       * Re-initialize `0x8000_2000` to `32'h1122_3344`; execute `sh` with
    //         `rs2 = 32'hAAAA_CAFE` at offset `0` -> `32'h1122_CAFE`, and at
    //         offset `2` -> `32'hCAFE_CAFE`.
    //       * Execute `sw` with `rs2 = 32'hCAFE_BABE` at offset `0` ->
    //         `32'hCAFE_BABE`.
    task automatic test_aligned_stores();
        // TODO: Implement stimulus & harness checks for aligned `sb`, `sh`, `sw`
    endtask

    // =========================================================================
    // 3. Hardware Misaligned Loads & Stores (`misalign.sv` Split Engine)
    // =========================================================================
    // Intended Cases (Idempotent RAM `0x8000_2000` & `0x8000_2004`):
    //   - Preload Word 0 (`0x8000_2000 = 32'h4433_2211`) and Word 1
    //     (`0x8000_2004 = 32'h8877_6655`) via `har_write_mem`:
    //       * `lh` / `lhu` at offset `1` (`0x8000_2001`, within Word 0):
    //         returns `0x0000_3322`.
    //       * `lh` / `lhu` at offset `3` (`0x8000_2003`, crosses Word 0 -> Word 1!):
    //         merges byte 3 of Word 0 (`0x44`) and byte 0 of Word 1 (`0x55`) ->
    //         `0x0000_5544` (and sign-extends if bit 15 is 1, e.g. `0x8844` ->
    //         `0xFFFF_8844` for `lh` vs. `0x0000_8844` for `lhu`).
    //       * `lw` at offset `1` (`0x8000_2001`): `32'h5544_3322`.
    //       * `lw` at offset `2` (`0x8000_2002`): `32'h6655_4433`.
    //       * `lw` at offset `3` (`0x8000_2003`): `32'h7766_5544`.
    //   - Misaligned Stores (`sh` at offsets `1, 3`; `sw` at offsets `1, 2, 3`):
    //       * Preload Word 0 and Word 1 with `32'hAAAA_AAAA` and `32'hBBBB_BBBB`.
    //       * Execute `sw` of `32'h1234_5678` to `0x8000_2001` (offset 1):
    //         Verify via `har_assert_mem` that Word 0 == `32'h3456_78AA` and
    //         Word 1 == `32'hBBBB_BB12`!
    //       * Repeat for `sw` at offsets `2` and `3`, and `sh` at offset `3`.
    task automatic test_misaligned_ram_access();
        // TODO: Implement stimulus & harness checks for misaligned RAM loads/stores
    endtask

    // =========================================================================
    // 4. Unexpected / Error / PMA & Alignment Trap Cases
    // =========================================================================
    // Error & Trap Cases:
    //   1. Store to Read-Only Boot ROM (`0x0000_1000`):
    //      - Read original word at `0x0000_1000` via `har_read_mem`.
    //      - Execute `sw x1, 0(x2)` where `x2 = 32'h0000_1000`.
    //      - Verify `har_assert_trap(EXC_STORE_ACCESS_FAULT, sw_pc, 32'h0000_1000, ...)`
    //        (`mcause = 7`, `mtval = 0x0000_1000`).
    //      - Verify via `har_assert_mem(32'h0000_1000, orig_rom_word, ...)`
    //        that the Boot ROM was NOT modified!
    //   2. Load & Store to Null Guard Page (`0x0000_0000`) or Unmapped Address
    //      Above RAM (`0x8001_8000` when `MAIN_MEM_BYTES = 96 KB`):
    //      - `lw x5, 0(x0)` (null pointer dereference):
    //        Verify `EXC_LOAD_ACCESS_FAULT` (`mcause = 5`, `mtval = 0x0000_0000`)
    //        and `har_assert_gpr(5'd5, 32'hDEAD_BEEF)` (`x5` untouched!).
    //      - `sw x5, 0(x0)`:
    //        Verify `EXC_STORE_ACCESS_FAULT` (`mcause = 7`, `mtval = 0x0000_0000`).
    //   3. Misaligned Load or Store to Non-Idempotent MMIO (`0x1000_1001`):
    //      - Because MMIO (`pma.is_idempotent == 0`) cannot be split into
    //        multiple bus reads/writes without corrupting device side effects,
    //        `lw` at `0x1000_1001` must raise `EXC_LOAD_ADDR_MISALIGNED`
    //        (`mcause = 4`, `mtval = 0x1000_1001`) and `sw` at `0x1000_1002`
    //        must raise `EXC_STORE_ADDR_MISALIGNED` (`mcause = 6`).
    //   4. Boundary-Straddling Misaligned Access (Last Word of RAM -> Unmapped):
    //      - Execute `lw` or `sw` at `0x8001_7FFE` (2 bytes inside the end of
    //        96 KB RAM, 2 bytes in unmapped `0x8001_8000`).
    //      - Because `u_pma_end` checks `last_byte_addr_o = 0x8001_8001` BEFORE
    //        issuing Phase 1 on `cbus`, the store faults immediately with
    //        `EXC_STORE_ACCESS_FAULT` (`mcause = 7`) and does NOT write the
    //        first half into `0x8001_7FFC`! Verify via `har_assert_mem`.
    //   5. Reserved Load/Store `funct3` Encodings:
    //      - `OPCODE_LOAD` with `funct3 inside {3'b011 (ld), 3'b110 (lwu), 3'b111}`
    //        or `OPCODE_STORE` with `funct3 >= 3'b011` on RV32 must raise
    //        `EXC_ILLEGAL_INSTR` (`mcause = 2`).
    task automatic test_lsu_exceptions();
        // TODO: Implement stimulus & harness checks for PMA/alignment/encoding faults
    endtask

endmodule : tb_isa_lsu

