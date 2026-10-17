`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/lsu/pma.sv
// Module:      pma
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Combinational Physical Memory Attributes (PMA) Checker. Evaluates any
//   32-bit physical byte address against the SoC address map defined in
//   `soc_pkg.sv` and returns a `pma_attr_t` bundle (`core_pkg.sv`) describing
//   the region's type, cacheability, idempotency, and R/W/X permissions.
//
//   Why This Module Exists:
//     1. Hardware Firmware/ROM Write Protection:
//        - Enforces that Boot ROM (`0x0000_1000..0x0000_2FFF`) and the QSPI
//          Flash XIP window (`0x2000_0000..0x2FFF_FFFF`) have
//          `is_writable = 1'b0`. Any store instruction targeting these regions
//          immediately raises `EXC_STORE_ACCESS_FAULT` (`mcause = 7`).
//     2. Null-Pointer & Unmapped Address Guard:
//        - Addresses outside valid regions (including the 4 KB null guard page
//          `0x0000_0000..0x0000_0FFF` and addresses above
//          `MAIN_MEM_BASE + MAIN_MEM_BYTES - 1`) return `is_mapped = 1'b0`,
//          causing instruction fetches, loads, or stores to take a precise
//          Access Fault (`mcause = 1, 5, or 7`).
//     3. MMIO Side-Effect Protection:
//        - Marks CLINT (`0x0200_0000`), PLIC (`0x0C00_0000`), and APB MMIO
//          (`0x1000_0000..0x1000_FFFF`) as `is_mmio = 1'b1`,
//          `is_cacheable = 1'b0`, `is_idempotent = 1'b0`, and
//          `is_executable = 1'b0`.
//        - Prevents instruction fetches from MMIO, prevents misaligned hardware
//          splitting across MMIO registers, and tells the M4 OoO LSU to execute
//          MMIO accesses non-speculatively at the ROB head.
//
//   Address Map Region Table (from `soc_pkg.sv`):
//     - Boot ROM (`0x0000_1000 .. +8 KB`):
//         `mapped=1, rom=1, cacheable=1, idempotent=1, R=1, W=0, X=1`
//     - CLINT (`0x0200_0000 .. +64 KB`):
//         `mapped=1, mmio=1, cacheable=0, idempotent=0, R=1, W=1, X=0`
//     - PLIC (`0x0C00_0000 .. +64 MB`):
//         `mapped=1, mmio=1, cacheable=0, idempotent=0, R=1, W=1, X=0`
//     - APB MMIO (`0x1000_0000 .. +64 KB`):
//         `mapped=1, mmio=1, cacheable=0, idempotent=0, R=1, W=1, X=0`
//     - QSPI XIP (`0x2000_0000 .. +256 MB`):
//         `mapped=1, rom=1, cacheable=1, idempotent=1, R=1, W=0, X=1`
//     - Main Memory (`0x8000_0000 .. +MAIN_MEM_BYTES`):
//         `mapped=1, ram=1, cacheable=1, idempotent=1, R=1, W=1, X=1`
//     - All other addresses:
//         `mapped=0` (all flags `0`)
//
// Connections:
//   - Instantiated by:
//       * `frontend.sv` (`u_ifetch_pma`) to check instruction fetch PC.
//       * `lsu.sv` (`u_pma_start`, `u_pma_end`) to check load/store start and
//         end byte addresses.
//
// What Needs to Be Implemented:
//   1. Implement the combinational address range comparators populating all
//      fields of `attr_o`.
// =============================================================================

module pma
    import soc_pkg::*;
    import core_pkg::*;
#(
    parameter int unsigned MAIN_MEM_BYTES = 96 * 1024
) (
    input  logic [31:0] addr_i,
    output pma_attr_t   attr_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement combinational range decode against `soc_pkg` regions and
    //   `MAIN_MEM_BYTES` parameter.
    // -------------------------------------------------------------------------

    // Temporary stub tie-off
    assign attr_o = '0;

endmodule : pma

