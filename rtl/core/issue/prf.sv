`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/issue/prf.sv
// Module:      prf
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Physical Register File (PRF) storing `N_PHYS_REGS` × 32-bit general-purpose
//   integer registers.
//
//   Architecture Across Milestones:
//     - In Milestone 1 (M1): `N_PHYS_REGS = 32`, directly representing the 32
//       architectural RISC-V integer registers (`x0`..`x31`) with 2 read ports
//       and 1 write port (2R1W).
//     - In Milestone 4 (M4): Scales via parameter `N_PHYS_REGS = 96` to serve
//       as the merged Physical Register File for out-of-order register renaming.
//
//   Key Microarchitectural Rules:
//     1. Hardwired Zero (`x0` / `p0`):
//        - Register index `0` is hardwired to `32'h0000_0000`. Reads of address
//          `0` always return `32'h0000_0000`, and writes to address `0` are
//          ignored.
//     2. Write-Through Read Bypass (Same-Cycle WB -> Read):
//        - If a read port requests register `k` (`k != 0`) in the same clock
//          cycle that the write port commits a write to register `k`
//          (`rd_wen_i && rd_addr_i == k`), the read port combinationally
//          returns `rd_wdata_i` so instructions reading a register in the exact
//          cycle it retires always observe the newly committed value.
//
// Connections:
//   - Instantiated by: `core.sv` (`u_prf`).
//   - Read Ports (connected to `dispatch.sv` / `bypass.sv`):
//       * `rs1_addr_i` -> `rs1_data_o`
//       * `rs2_addr_i` -> `rs2_data_o`
//   - Write Port (connected to `commit.sv`):
//       * `rd_wen_i`, `rd_addr_i`, `rd_wdata_i`
//
// What Needs to Be Implemented:
//   1. Declare register array `logic [31:0] regs_q [1:N_PHYS_REGS-1]` (reset to
//      `'0` on `!rst_n_i` for clean deterministic simulation/co-sim startup).
//   2. Implement synchronous write on `posedge clk_i` when `rd_wen_i &&
//      (rd_addr_i != '0)`.
//   3. Implement combinational read ports `rs1_data_o` and `rs2_data_o` with
//      `x0 == 0` hardwiring and internal write-through forwarding.
// =============================================================================

module prf
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter int unsigned NUM_REGS = core_pkg::N_PHYS_REGS,
    parameter int unsigned ADDR_W   = $clog2(NUM_REGS)
) (
    input  logic              clk_i,
    input  logic              rst_n_i,

    // Read Port 1 (rs1)
    input  logic [ADDR_W-1:0] rs1_addr_i,
    output logic [31:0]       rs1_data_o,

    // Read Port 2 (rs2)
    input  logic [ADDR_W-1:0] rs2_addr_i,
    output logic [31:0]       rs2_data_o,

    // Synchronous Writeback Port (rd from Commit stage)
    input  logic              rd_wen_i,
    input  logic [ADDR_W-1:0] rd_addr_i,
    input  logic [31:0]       rd_wdata_i
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement `regs_q[1:NUM_REGS-1]` array, synchronous write port, and
    //   combinational read ports with `x0` hardwired to 0 and write-through
    //   bypass.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign rs1_data_o = 32'h0;
    assign rs2_data_o = 32'h0;

endmodule : prf

