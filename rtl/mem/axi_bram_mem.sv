`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/mem/axi_bram_mem.sv
// Module:      axi_bram_mem
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Parameterized Byte-Writeable Synchronous Block RAM (BRAM) Main Memory Slave
//   mapped at physical base address `0x8000_0000` (`MAIN_MEM_BASE` in
//   `soc_pkg.sv`).
//
//   Why This Module Exists:
//     - On the Digilent Basys 3 (`xc7a35t-1`), there is no external DDR3 DRAM,
//       so `axi_bram_mem` provides 96 KB (`MAIN_MEM_BYTES = 98_304`, i.e.,
//       24,576 × 32-bit words = 24 BRAM36 tiles) of on-chip main memory at
//       `0x8000_0000`.
//     - In Verilator / xsim simulation (`tb_core.sv`, `tb_soc.sv`), this module
//       serves as the main RAM into which `riscv-tests` (`rv32ui-p-*`,
//       `rv32um-p-*`) and bare-metal C benchmarks are loaded via
//       `+mem_hex=<path>` or `MEM_INIT_FILE`.
//
//   Architecture & Synthesis Inference Rules:
//     - Storage array `logic [31:0] mem_q [0:NUM_WORDS-1]` with 4-lane byte
//       write enables (`for (int b = 0; b < 4; b++) if (wstrb[b])
//       mem_q[word_idx][b*8 +: 8] <= wdata[b*8 +: 8];`) so Xilinx Vivado
//       cleanly infers true byte-writeable `RAMB36E1` primitives without LUTRAM
//       blowup.
//     - Word index calculation: `word_idx = (cbus_req_i.addr - MAIN_MEM_BASE) >> 2`.
//     - Follows the standardized physical pipeline handshake on `cbus_rsp_o`:
//       `cbus_req_ready_o = !rsp_valid_q || cbus_rsp_ready_i`.
//
// Connections:
//   - Instantiated by: `soc.sv` (`u_main_mem`) and `tb_core.sv`.
//   - Upstream `cbus` Slave Interface:
//       * `cbus_req_*` / `cbus_rsp_*` <- `soc_xbar.sv` (`s_ram_*`)
//
// What Needs to Be Implemented:
//   1. Declare `logic [31:0] mem_q [0:NUM_WORDS-1]` (`NUM_WORDS = MEM_BYTES / 4`)
//      with support for `MEM_INIT_FILE` and runtime `+mem_hex=<path>` loading
//      in simulation.
//   2. Implement 1-cycle synchronous byte-masked write and 32-bit read with
//      standard valid/ready response buffering (`rsp_valid_q`, `rsp_q`).
// =============================================================================

module axi_bram_mem
    import soc_pkg::*;
    import cbus_pkg::*;
#(
    parameter int unsigned MEM_BYTES     = 96 * 1024, // 96 KB default on Basys 3
    parameter string       MEM_INIT_FILE = ""
) (
    input  logic      clk_i,
    input  logic      rst_n_i,

    // cbus Slave Interface (from soc_xbar, mapped at 0x8000_0000)
    input  logic      cbus_req_valid_i,
    output logic      cbus_req_ready_o,
    input  cbus_req_t cbus_req_i,

    output logic      cbus_rsp_valid_o,
    input  logic      cbus_rsp_ready_i,
    output cbus_rsp_t cbus_rsp_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement `mem_q[0:(MEM_BYTES/4)-1]` BRAM array with byte-lane write
    //   strobes, `$readmemh` / `+mem_hex` initialization, and 1-cycle `cbus`
    //   response register.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign cbus_req_ready_o = 1'b0;
    assign cbus_rsp_valid_o = 1'b0;
    assign cbus_rsp_o       = '0;

endmodule : axi_bram_mem

