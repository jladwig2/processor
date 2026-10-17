`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/commit/debug_ctrl.sv
// Module:      debug_ctrl
// Project:     processor-complex
// Milestone:   M1 (Verification Inspection Stub) / M4 (Full JTAG Debug Mode)
//
// Description:
//   Core-Side Debug & Architectural State Inspection Controller.
//   **Synthesis Gating (`HAS_DEBUG`):** This module is instantiated inside
//   `core.sv` strictly under `generate if (HAS_DEBUG)`. When `HAS_DEBUG == 0`,
//   this module and all its connections to `prf.sv` and `csr_unit.sv` are
//   completely omitted from synthesis.
//
//   Dual Role Across Milestones:
//     1. In Milestone 1 (Verification & Directed Test Harness):
//        - Bridges the core's external `dbg_reg_req_i` / `dbg_reg_rsp_o` bundle
//          directly to the `HAS_DEBUG` inspection ports on `prf.sv` (`x0..x31`)
//          and `csr_unit.sv` (`mstatus`, `mepc`, `mcause`, `mtval`, `mtvec`,
//          `mcycle`, `minstret`, etc.).
//        - Allows the unit/directed test harness (`tb_core.sv` and
//          `sim/unit/tb_isa_*.sv`) to inspect or preload any GPR or CSR on any
//          clock cycle to verify whether an instruction completed with the
//          expected state or whether an exception/trap occurred and left
//          architectural state untouched.
//     2. In Milestone 2 / Milestone 4 (Full RISC-V External Debug v0.13.2):
//        - Handles external `debug_req_i` halt requests from `debug_module.sv`
//          at the Commit boundary, manages `dcsr`, `dpc`, and `dscratch0..1`
//          CSRs, supports single-stepping (`dcsr.step`), and services JTAG
//          Abstract `Access Register` commands while `dbg_halted_o == 1'b1`.
//
// Connections:
//   - Instantiated by: `core.sv` (`gen_debug.u_debug_ctrl` when `HAS_DEBUG == 1`).
//   - External Debug / Harness Interface (on `core.sv`):
//       * `debug_req_i`   <- `debug_module.sv` or testbench halt control
//       * `dbg_halted_o`  -> `debug_module.sv` or testbench status
//       * `dbg_reg_req_i` <- `debug_module.sv` or testbench harness (`dbg_reg_req_t`)
//       * `dbg_reg_rsp_o` -> `debug_module.sv` or testbench harness (`dbg_reg_rsp_t`)
//   - Internal Core Inspection Ports:
//       * `prf_dbg_addr_o`, `prf_dbg_rdata_i`, `prf_dbg_wen_o`, `prf_dbg_wdata_o` <-> `prf.sv`
//       * `csr_dbg_addr_o`, `csr_dbg_rdata_i`, `csr_dbg_wen_o`, `csr_dbg_wdata_o`,
//         `csr_dbg_err_i` <-> `csr_unit.sv`
//
// What Needs to Be Implemented:
//   1. For M1: Route `dbg_reg_req_i` (`is_csr == 0` -> `prf_dbg_*`,
//      `is_csr == 1` -> `csr_dbg_*`) and return `dbg_reg_rsp_o`.
//   2. For M4: Add `dcsr`/`dpc` registers, commit-boundary halt FSM, and
//      single-step control.
// =============================================================================

module debug_ctrl
    import rv_pkg::*;
    import core_pkg::*;
(
    input  logic                   clk_i,
    input  logic                   rst_n_i,

    // External Halt Request & Halted Status
    input  logic                   debug_req_i,
    output logic                   dbg_halted_o,

    // Abstract Register / Verification Harness Access Bundle
    input  dbg_reg_req_t           dbg_reg_req_i,
    output dbg_reg_rsp_t           dbg_reg_rsp_o,

    // GPR Inspection Port (to/from prf.sv)
    output logic [PRF_ADDR_W-1:0]  prf_dbg_addr_o,
    input  logic [31:0]            prf_dbg_rdata_i,
    output logic                   prf_dbg_wen_o,
    output logic [31:0]            prf_dbg_wdata_o,

    // CSR Inspection Port (to/from csr_unit.sv)
    output logic [CSR_ADDR_W-1:0]  csr_dbg_addr_o,
    input  logic [31:0]            csr_dbg_rdata_i,
    output logic                   csr_dbg_wen_o,
    output logic [31:0]            csr_dbg_wdata_o,
    input  logic                   csr_dbg_err_i
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Route `dbg_reg_req_i` to `prf_dbg_*` (when `!dbg_reg_req_i.is_csr`)
    //      or `csr_dbg_*` (when `dbg_reg_req_i.is_csr`) and multiplex
    //      `dbg_reg_rsp_o`.
    //   2. (M4) Implement halt FSM, `dcsr`/`dpc`, and single-step trigger.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign dbg_halted_o    = 1'b0;
    assign dbg_reg_rsp_o   = '0;
    assign prf_dbg_addr_o  = '0;
    assign prf_dbg_wen_o   = 1'b0;
    assign prf_dbg_wdata_o = 32'h0;
    assign csr_dbg_addr_o  = '0;
    assign csr_dbg_wen_o   = 1'b0;
    assign csr_dbg_wdata_o = 32'h0;

endmodule : debug_ctrl

