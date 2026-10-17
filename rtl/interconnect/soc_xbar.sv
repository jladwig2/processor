`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/interconnect/soc_xbar.sv
// Module:      soc_xbar
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   System-on-Chip `cbus` Address-Decoding Crossbar. Connects the processor
//   core's unified `cbus` master port (`m_core_*`) and the optional Debug
//   System Bus Access master port (`m_sba_*`, gated by `HAS_DEBUG`) to the
//   SoC's memory and peripheral slaves according to the physical address map
//   in `soc_pkg.sv`.
//
//   Master Ports:
//     - Master 0 (`m_core_*`): Processor core unified `cbus` master (`core.sv`).
//     - Master 1 (`m_sba_*`, active only when `HAS_DEBUG == 1'b1`): Debug
//       System Bus Access master (`debug_module.sv` / `dm_sba.sv`), used by
//       the simulation verification harness in M1 and JTAG OpenOCD in M2 to
//       preload or inspect physical memory directly. When `HAS_DEBUG == 1'b0`,
//       Master 1 arbitration logic is omitted in synthesis.
//
//   Address Decoding & Slave Routing Table (M1 Configuration):
//     1. Boot ROM (`0x0000_1000 .. 0x0000_2FFF`, 8 KB):
//        - Routed to Slave Port 0 (`s_rom_*` -> `boot_rom.sv`).
//     2. APB Peripheral MMIO Window (`0x1000_0000 .. 0x1000_FFFF`, 64 KB):
//        - Routed to Slave Port 1 (`s_mmio_*` -> `cbus2apb.sv`).
//     3. Main Memory (`0x8000_0000 .. 0x8000_0000 + MAIN_MEM_BYTES - 1`):
//        - Routed to Slave Port 2 (`s_ram_*` -> `axi_bram_mem.sv`).
//     4. Default / Unmapped Region (e.g., Null Guard Page `0x0000_0000`):
//        - Handled internally by an error responder that accepts the request
//          and returns `rsp.err = 1'b1` with echoed `src_id` so neither the
//          core nor the debug SBA master ever hangs on an unmapped address.
//
// Connections:
//   - Instantiated by: `soc.sv` (`u_soc_xbar`) and `tb_core.sv`.
//   - Upstream Master Ports:
//       * `m_core_req_*` / `m_core_rsp_*` <- `core.sv` (`u_core`)
//       * `m_sba_req_*`  / `m_sba_rsp_*`  <- `debug_module.sv` (`u_debug_module`,
//                                            gated by `HAS_DEBUG`)
//   - Downstream Slave Ports:
//       * `s_rom_req_*`  / `s_rom_rsp_*`  -> `boot_rom.sv`     (`0x0000_1000`)
//       * `s_mmio_req_*` / `s_mmio_rsp_*` -> `cbus2apb.sv`     (`0x1000_0000`)
//       * `s_ram_req_*`  / `s_ram_rsp_*`  -> `axi_bram_mem.sv` (`0x8000_0000`)
//
// What Needs to Be Implemented:
//   1. Arbitrate between `m_core_*` and (when `HAS_DEBUG == 1`) `m_sba_*`.
//   2. Decode target slave (`sel_rom`, `sel_mmio`, `sel_ram`, `sel_err`) from
//      the winning request's `addr`.
//   3. Route the slave response back to `m_core_rsp_*` or `m_sba_rsp_*` and
//      generate `rsp.err = 1'b1` for unmapped addresses.
// =============================================================================

module soc_xbar
    import soc_pkg::*;
    import cbus_pkg::*;
#(
    parameter int unsigned MAIN_MEM_BYTES = 96 * 1024,
    parameter bit          HAS_DEBUG      = 1'b1
) (
    input  logic      clk_i,
    input  logic      rst_n_i,

    // Upstream Master Port 0: Processor Core (from core.sv)
    input  logic      m_core_req_valid_i,
    output logic      m_core_req_ready_o,
    input  cbus_req_t m_core_req_i,

    output logic      m_core_rsp_valid_o,
    input  logic      m_core_rsp_ready_i,
    output cbus_rsp_t m_core_rsp_o,

    // Upstream Master Port 1: Debug SBA / Test Harness (gated by HAS_DEBUG)
    input  logic      m_sba_req_valid_i,
    output logic      m_sba_req_ready_o,
    input  cbus_req_t m_sba_req_i,

    output logic      m_sba_rsp_valid_o,
    input  logic      m_sba_rsp_ready_i,
    output cbus_rsp_t m_sba_rsp_o,

    // Downstream Slave Port 0: Boot ROM (0x0000_1000 .. 0x0000_2FFF)
    output logic      s_rom_req_valid_o,
    input  logic      s_rom_req_ready_i,
    output cbus_req_t s_rom_req_o,

    input  logic      s_rom_rsp_valid_i,
    output logic      s_rom_rsp_ready_o,
    input  cbus_rsp_t s_rom_rsp_i,

    // Downstream Slave Port 1: APB MMIO Bridge (0x1000_0000 .. 0x1000_FFFF)
    output logic      s_mmio_req_valid_o,
    input  logic      s_mmio_req_ready_i,
    output cbus_req_t s_mmio_req_o,

    input  logic      s_mmio_rsp_valid_i,
    output logic      s_mmio_rsp_ready_o,
    input  cbus_rsp_t s_mmio_rsp_i,

    // Downstream Slave Port 2: Main Memory BRAM (0x8000_0000 .. +MAIN_MEM_BYTES)
    output logic      s_ram_req_valid_o,
    input  logic      s_ram_req_ready_i,
    output cbus_req_t s_ram_req_o,

    input  logic      s_ram_rsp_valid_i,
    output logic      s_ram_rsp_ready_o,
    input  cbus_rsp_t s_ram_rsp_i
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement master arbitration (`m_core_*` and `HAS_DEBUG`-gated
    //   `m_sba_*`), address decoder (`BOOT_ROM_BASE`, `MMIO_BASE`,
    //   `MAIN_MEM_BASE`), request/response routing, and unmapped-address error
    //   responder.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign m_core_req_ready_o = 1'b0;
    assign m_core_rsp_valid_o = 1'b0;
    assign m_core_rsp_o       = '0;

    assign m_sba_req_ready_o  = 1'b0;
    assign m_sba_rsp_valid_o  = 1'b0;
    assign m_sba_rsp_o        = '0;

    assign s_rom_req_valid_o  = 1'b0;
    assign s_rom_req_o        = '0;
    assign s_rom_rsp_ready_o  = 1'b1;

    assign s_mmio_req_valid_o = 1'b0;
    assign s_mmio_req_o       = '0;
    assign s_mmio_rsp_ready_o = 1'b1;

    assign s_ram_req_valid_o  = 1'b0;
    assign s_ram_req_o        = '0;
    assign s_ram_rsp_ready_o  = 1'b1;

endmodule : soc_xbar
