`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/lsu/lsu.sv
// Module:      lsu
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Top-level Load-Store Unit (LSU) in Logical Stage X. Coordinates address
//   calculation (`agu.sv`), Physical Memory Attribute validation (`pma.sv`),
//   aligned and hardware-split misaligned memory transfers (`misalign.sv`),
//   and precise load/store exception generation.
//
//   Pre-Bus Exception Checks (Checked Before Issuing Any `cbus` Request):
//     1. Misaligned Access to Non-Idempotent Memory (MMIO) or Region Boundary:
//        - If `is_misaligned` is true AND (`!pma_start.is_idempotent` ||
//          `!pma_end.is_idempotent` || `(pma_start.is_ram != pma_end.is_ram)` ||
//          `(pma_start.is_rom != pma_end.is_rom)`):
//            * Load:  Raises `EXC_LOAD_ADDR_MISALIGNED` (`mcause = 4`,
//                     `mtval = eff_addr`).
//            * Store: Raises `EXC_STORE_ADDR_MISALIGNED` (`mcause = 6`,
//                     `mtval = eff_addr`).
//     2. PMA Permission or Unmapped Address Violation:
//        - Load:  If `!pma_start.is_mapped || !pma_start.is_readable ||
//                 !pma_end.is_mapped || !pma_end.is_readable`, raises
//                 `EXC_LOAD_ACCESS_FAULT` (`mcause = 5`, `mtval = eff_addr`).
//        - Store: If `!pma_start.is_mapped || !pma_start.is_writable ||
//                 !pma_end.is_mapped || !pma_end.is_writable` (which catches
//                 any store to Boot ROM `0x0000_1000` or QSPI XIP `0x2000_0000`),
//                 raises `EXC_STORE_ACCESS_FAULT` (`mcause = 7`, `mtval = eff_addr`).
//     3. Downstream Bus Fault (`bus_err` from `misalign.sv` / `cbus`):
//        - If a `cbus` slave returns `dmem_rsp_i.err == 1'b1` (e.g., APB
//          `pslverr`), raises `EXC_LOAD_ACCESS_FAULT` (5) or
//          `EXC_STORE_ACCESS_FAULT` (7) with `mtval = eff_addr`.
//
// Connections:
//   - Instantiated by: `core.sv` (`u_lsu`).
//   - Upstream (from Stage X issue in `core.sv`):
//       * `in_valid_i`, `in_ready_o`, `uop_i`, `rs1_val_i`, `rs2_val_i`
//   - Downstream Completion (to Stage X -> C in `core.sv`):
//       * `out_valid_o`, `out_ready_i`, `rdata_o`, `eff_addr_o`,
//         `exc_valid_o`, `exc_cause_o`, `exc_tval_o`
//   - Data Memory `cbus` Master Interface (to `core_cbus_arb.sv`, `src_id = 1`):
//       * `dmem_req_valid_o`, `dmem_req_ready_i`, `dmem_req_o`
//       * `dmem_rsp_valid_i`, `dmem_rsp_ready_o`, `dmem_rsp_i`
//   - Child Modules:
//       * `agu.sv` (`u_agu`)
//       * `pma.sv` (`u_pma_start`, `u_pma_end`)
//       * `misalign.sv` (`u_misalign`)
//
// What Needs to Be Implemented:
//   1. Instantiate `agu`, `u_pma_start`, `u_pma_end`, and `misalign`.
//   2. Implement pre-bus exception detection so faulting loads/stores complete
//      immediately with `exc_valid_o = 1'b1` without issuing a `cbus` request.
//   3. Connect non-faulting accesses to `u_misalign` and forward completion
//      status and read data to `out_valid_o` / `rdata_o`.
// =============================================================================

module lsu
    import soc_pkg::*;
    import cbus_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter int unsigned MAIN_MEM_BYTES = 96 * 1024
) (
    input  logic       clk_i,
    input  logic       rst_n_i,
    input  logic       flush_i,

    // Upstream Physical Pipeline Interface (from Stage X in core.sv)
    input  logic       in_valid_i,
    output logic       in_ready_o,
    input  uop_t       uop_i,
    input  logic [31:0] rs1_val_i,
    input  logic [31:0] rs2_val_i,

    // Downstream Physical Pipeline Interface (to Stage X -> C in core.sv)
    output logic       out_valid_o,
    input  logic       out_ready_i,
    output logic [31:0] rdata_o,
    output logic [31:0] eff_addr_o,
    output logic       exc_valid_o,
    output exc_cause_e exc_cause_o,
    output logic [31:0] exc_tval_o,

    // Data Memory cbus Master Interface (to core_cbus_arb, src_id = 1)
    output logic       dmem_req_valid_o,
    input  logic       dmem_req_ready_i,
    output cbus_req_t  dmem_req_o,

    input  logic       dmem_rsp_valid_i,
    output logic       dmem_rsp_ready_o,
    input  cbus_rsp_t  dmem_rsp_i
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Instantiate `agu` (`u_agu`), `pma` (`u_pma_start`, `u_pma_end`),
    //      and `misalign` (`u_misalign`).
    //   2. Implement PMA/alignment fault check and connect to `u_misalign`.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign in_ready_o       = 1'b0;
    assign out_valid_o      = 1'b0;
    assign rdata_o          = 32'h0;
    assign eff_addr_o       = 32'h0;
    assign exc_valid_o      = 1'b0;
    assign exc_cause_o      = EXC_LOAD_ACCESS_FAULT;
    assign exc_tval_o       = 32'h0;
    assign dmem_req_valid_o = 1'b0;
    assign dmem_req_o       = '0;
    assign dmem_rsp_ready_o = 1'b1;

endmodule : lsu

