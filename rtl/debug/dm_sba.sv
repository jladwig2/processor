`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/debug/dm_sba.sv
// Module:      dm_sba
// Project:     processor-complex
// Milestone:   M1 (Verification Memory Inspection Stub) / M2 (JTAG SBA Master)
//
// Description:
//   Debug Module System Bus Access (`dm_sba`) Master.
//   **Synthesis Gating (`HAS_DEBUG`):** Instantiated inside `debug_module.sv`
//   (or `soc.sv`) strictly under `generate if (HAS_DEBUG)`. When
//   `HAS_DEBUG == 1'b0`, this module and the `m_sba_*` port on `soc_xbar.sv`
//   are omitted from synthesis.
//
//   Why This Module Exists:
//     1. In Milestone 1 (Verification & Directed Test Harness):
//        - Provides an independent `cbus` master port (`sba_req_o` / `sba_rsp_i`,
//          tagged with `src_id = 4'hF`) into `soc_xbar.sv`.
//        - Allows the verification test harness (`tb_core.sv` and
//          `sim/unit/tb_isa_*.sv`) to preload test instructions or data into
//          `axi_bram_mem` and inspect memory words after an instruction
//          executes (e.g., verifying that a `sb`/`sh`/`sw` modified only the
//          intended byte lanes, or verifying that a faulting store to
//          `boot_rom` left the ROM untouched).
//     2. In Milestone 2 (RISC-V External Debug Spec §3.9 System Bus Access):
//        - Translates Debug Module `sbaddress0`, `sbdata0`, and `sbcs` register
//          accesses into `CBUS_GET`, `CBUS_PUT_FULL`, and `CBUS_PUT_PARTIAL`
//          transactions so GDB/OpenOCD can download ELF binaries into RAM or
//          inspect memory without halting the processor cores!
//
// Connections:
//   - Instantiated by: `debug_module.sv` (`u_dm_sba`, gated by `HAS_DEBUG`).
//   - Control Interface (from `debug_module.sv` or verification harness):
//       * `req_valid_i`, `req_ready_o`, `req_write_i`, `req_addr_i`,
//         `req_wdata_i`, `req_wstrb_i`
//       * `rsp_valid_o`, `rsp_rdata_o`, `rsp_err_o`
//   - Downstream `cbus` Master Port (to `soc_xbar.sv` `m_sba_*`):
//       * `sba_req_valid_o`, `sba_req_ready_i`, `sba_req_o`
//       * `sba_rsp_valid_i`, `sba_rsp_ready_o`, `sba_rsp_i`
//
// What Needs to Be Implemented:
//   1. Map `req_*` into a `cbus_req_t` (`src_id = 4'hF`, `opcode = req_write_i ?
//      ((req_wstrb_i == 4'b1111) ? CBUS_PUT_FULL : CBUS_PUT_PARTIAL) : CBUS_GET`).
//   2. Capture `sba_rsp_i` and present `rsp_valid_o`, `rsp_rdata_o`, and
//      `rsp_err_o`.
// =============================================================================

module dm_sba
    import cbus_pkg::*;
(
    input  logic        clk_i,
    input  logic        rst_n_i,

    // Upstream Command Interface (from debug_module.sv or verification harness)
    input  logic        req_valid_i,
    output logic        req_ready_o,
    input  logic        req_write_i,
    input  logic [31:0] req_addr_i,
    input  logic [31:0] req_wdata_i,
    input  logic [3:0]  req_wstrb_i,

    output logic        rsp_valid_o,
    output logic [31:0] rsp_rdata_o,
    output logic        rsp_err_o,

    // Downstream cbus Master Interface (to soc_xbar.sv m_sba_*)
    output logic        sba_req_valid_o,
    input  logic        sba_req_ready_i,
    output cbus_req_t   sba_req_o,

    input  logic        sba_rsp_valid_i,
    output logic        sba_rsp_ready_o,
    input  cbus_rsp_t   sba_rsp_i
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement `cbus` request formation (`src_id = 4'hF`) and response
    //   capture for System Bus Access reads and writes.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign req_ready_o     = 1'b0;
    assign rsp_valid_o     = 1'b0;
    assign rsp_rdata_o     = 32'h0;
    assign rsp_err_o       = 1'b0;
    assign sba_req_valid_o = 1'b0;
    assign sba_req_o       = '0;
    assign sba_rsp_ready_o = 1'b1;

endmodule : dm_sba

