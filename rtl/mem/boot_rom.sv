`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/mem/boot_rom.sv
// Module:      boot_rom
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   8 KB Synchronous Read-Only Memory (Boot ROM) mapped at physical base
//   address `0x0000_1000` (`BOOT_ROM_BASE = RESET_PC` in `soc_pkg.sv`).
//
//   Why This Module Exists:
//     - Serves as the architectural reset vector (`0x0000_1000`) for all harts.
//     - In M1 (before full QSPI/UART boot firmware in `sw/boot/` is compiled in
//       M2), `boot_rom` initializes its first two words by default to a
//       minimal trampoline that jumps straight to `MAIN_MEM_BASE` (`0x8000_0000`):
//         * `0x0000_1000`: `32'h8000_02B7` (`lui t0, 0x80000`)
//         * `0x0000_1004`: `32'h0002_8067` (`jalr x0, 0(t0)`)
//         * Remaining words: `32'h0000_0013` (`nop`)
//       If `MEM_INIT_FILE` is non-empty (or `+rom_hex=<path>` is passed in
//       simulation), `$readmemh` overrides the array with the compiled boot
//       image.
//     - Hardware Write Protection: Any `CBUS_PUT_FULL` or `CBUS_PUT_PARTIAL`
//       request targeting `boot_rom` is ignored by the memory array and
//       answered with `cbus_rsp_o.err = 1'b1`.
//
// Connections:
//   - Instantiated by: `soc.sv` (`u_boot_rom`) and `tb_core.sv`.
//   - Upstream `cbus` Slave Interface:
//       * `cbus_req_*` / `cbus_rsp_*` <- `soc_xbar.sv` (`s_rom_*`)
//
// What Needs to Be Implemented:
//   1. Declare `logic [31:0] rom_q [0:NUM_WORDS-1]` (`NUM_WORDS = ROM_BYTES / 4`),
//      initialized with the `0x8000_0000` jump trampoline and optional
//      `$readmemh(MEM_INIT_FILE, rom_q)`.
//   2. Implement 1-cycle synchronous read response (`CBUS_ACCESS_ACK_DATA`)
//      and write-error rejection (`err = 1'b1` on `CBUS_PUT_*`).
// =============================================================================

module boot_rom
    import soc_pkg::*;
    import cbus_pkg::*;
#(
    parameter int unsigned ROM_BYTES     = soc_pkg::BOOT_ROM_SIZE, // 8 KB (2048 words)
    parameter string       MEM_INIT_FILE = ""
) (
    input  logic      clk_i,
    input  logic      rst_n_i,

    // cbus Slave Interface (from soc_xbar, mapped at 0x0000_1000)
    input  logic      cbus_req_valid_i,
    output logic      cbus_req_ready_o,
    input  cbus_req_t cbus_req_i,

    output logic      cbus_rsp_valid_o,
    input  logic      cbus_rsp_ready_i,
    output cbus_rsp_t cbus_rsp_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement 2048 x 32-bit synchronous ROM array (`rom_q`), default
    //   `0x8000_0000` jump trampoline, optional `$readmemh` loading, and
    //   1-cycle `cbus` read/error response logic.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign cbus_req_ready_o = 1'b0;
    assign cbus_rsp_valid_o = 1'b0;
    assign cbus_rsp_o       = '0;

endmodule : boot_rom

