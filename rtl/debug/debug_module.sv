`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/debug/debug_module.sv
// Module:      debug_module
// Project:     processor-complex
// Milestone:   M1 (Verification Harness Hub Stub) / M2 (RISC-V Debug Module)
//
// Description:
//   Top-Level RISC-V Debug Module (`debug_module`) and Verification Inspection
//   Hub.
//   **Synthesis Gating (`HAS_DEBUG`):** Instantiated in `soc.sv` / `tb_core.sv`
//   strictly inside `generate if (HAS_DEBUG)`. When `HAS_DEBUG == 1'b0`, this
//   entire subsystem (`dtm_bscan`, `dmi_cdc`, `debug_module`, `dm_sba`, and
//   `debug_ctrl`) is excluded from synthesis.
//
//   Dual Role Across Milestones:
//     1. In Milestone 1 (Verification Harness Inspection Hub):
//        - Provides a single clean entry point for `tb_core.sv` and the
//          unit/directed instruction tests (`sim/unit/tb_isa_*.sv`) to:
//            a. Inspect or write any GPR (`x0..x31`) or CSR (`mstatus`, `mepc`,
//               `mcause`, `mtval`, `mtvec`, etc.) inside `core.sv` via
//               `core_dbg_reg_req_o` / `core_dbg_reg_rsp_i`.
//            b. Read or write any physical memory address (`boot_rom`,
//               `axi_bram_mem`, or APB MMIO) via `dm_sba.sv` (`sba_req_o` /
//               `sba_rsp_i` connected to `soc_xbar.sv`).
//     2. In Milestone 2 (Full JTAG / OpenOCD Debug Support):
//        - Implements the RISC-V Debug Spec v0.13.2 DMI register map
//          (`data0..1`, `dmcontrol`, `dmstatus`, `hartinfo`, `abstractcs`,
//          `command`, `sbcs`, `sbaddress0`, `sbdata0`) driven by `dtm_bscan.sv`
//          and `dmi_cdc.sv`.
//
// Connections:
//   - Instantiated by: `soc.sv` and `tb_core.sv` (gated by `HAS_DEBUG`).
//   - Core Debug Interface (to/from `core.sv` -> `debug_ctrl.sv`):
//       * `core_debug_req_o`, `core_dbg_halted_i`
//       * `core_dbg_reg_req_o`, `core_dbg_reg_rsp_i`
//   - System Bus Access Master Port (to/from `soc_xbar.sv` via `dm_sba.sv`):
//       * `sba_req_valid_o`, `sba_req_ready_i`, `sba_req_o`
//       * `sba_rsp_valid_i`, `sba_rsp_ready_o`, `sba_rsp_i`
//
// What Needs to Be Implemented:
//   1. For M1: Instantiate `dm_sba` (`u_dm_sba`) and route verification harness
//      register (`har_reg_*`) and memory (`har_mem_*`) inspection requests to
//      `core_dbg_reg_*` and `u_dm_sba`.
//   2. For M2: Add DMI slave state machine (`dmcontrol`, `dmstatus`,
//      `abstractcs`, `command`, `sbcs`).
// =============================================================================

module debug_module
    import cbus_pkg::*;
    import core_pkg::*;
#(
    parameter int unsigned N_CORES = 1
) (
    input  logic         clk_i,
    input  logic         rst_n_i,

    // Verification Harness Direct Register/CSR Inspection Port (M1)
    input  dbg_reg_req_t har_reg_req_i,
    output dbg_reg_rsp_t har_reg_rsp_o,

    // Verification Harness Direct Memory Inspection Port via SBA (M1)
    input  logic         har_mem_req_valid_i,
    output logic         har_mem_req_ready_o,
    input  logic         har_mem_req_write_i,
    input  logic [31:0]  har_mem_req_addr_i,
    input  logic [31:0]  har_mem_req_wdata_i,
    input  logic [3:0]   har_mem_req_wstrb_i,
    output logic         har_mem_rsp_valid_o,
    output logic [31:0]  har_mem_rsp_rdata_o,
    output logic         har_mem_rsp_err_o,

    // Core Debug Control & Register Access Interface (to/from core.sv)
    output logic         core_debug_req_o,
    input  logic         core_dbg_halted_i,
    output dbg_reg_req_t core_dbg_reg_req_o,
    input  dbg_reg_rsp_t core_dbg_reg_rsp_i,

    // System Bus Access (SBA) cbus Master Interface (to soc_xbar.sv)
    output logic         sba_req_valid_o,
    input  logic         sba_req_ready_i,
    output cbus_req_t    sba_req_o,

    input  logic         sba_rsp_valid_i,
    output logic         sba_rsp_ready_o,
    input  cbus_rsp_t    sba_rsp_i
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Instantiate `dm_sba` (`u_dm_sba`) and wire `har_mem_*` and
    //      `har_reg_*` pass-throughs for M1 verification.
    //   2. (M2) Implement DMI register file and abstract command engine.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign har_reg_rsp_o       = '0;
    assign har_mem_req_ready_o = 1'b0;
    assign har_mem_rsp_valid_o = 1'b0;
    assign har_mem_rsp_rdata_o = 32'h0;
    assign har_mem_rsp_err_o   = 1'b0;
    assign core_debug_req_o    = 1'b0;
    assign core_dbg_reg_req_o  = '0;
    assign sba_req_valid_o     = 1'b0;
    assign sba_req_o           = '0;
    assign sba_rsp_ready_o     = 1'b1;

endmodule : debug_module

