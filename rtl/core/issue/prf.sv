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
//     3. Optional Debug & Verification Inspection Port (`HAS_DEBUG`):
//        - Gated behind `generate if (HAS_DEBUG)` so zero extra LUTs or muxes
//          are synthesized when `HAS_DEBUG == 1'b0`.
//        - When `HAS_DEBUG == 1'b1`, provides an independent read/write port
//          (`dbg_addr_i`, `dbg_rdata_o`, `dbg_wen_i`, `dbg_wdata_i`) driven by
//          `debug_ctrl.sv` (and used by the simulation test harness in
//          `tb_core.sv` / `sim/unit/tb_isa_*.sv` to verify GPR state after any
//          instruction retires or traps).
//
// Connections:
//   - Instantiated by: `core.sv` (`u_prf`).
//   - Pipeline Read Ports (connected to `dispatch.sv` / `bypass.sv`):
//       * `rs1_addr_i` -> `rs1_data_o`
//       * `rs2_addr_i` -> `rs2_data_o`
//   - Pipeline Write Port (connected to `commit.sv`):
//       * `rd_wen_i`, `rd_addr_i`, `rd_wdata_i`
//   - Optional Debug Inspection Port (connected to `debug_ctrl.sv`, gated by `HAS_DEBUG`):
//       * `dbg_addr_i`, `dbg_rdata_o`, `dbg_wen_i`, `dbg_wdata_i`
// =============================================================================

module prf
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter int unsigned NUM_REGS  = core_pkg::N_PHYS_REGS,
    parameter int unsigned ADDR_W    = $clog2(NUM_REGS),
    parameter bit          HAS_DEBUG = 1'b1
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
    input  logic [31:0]       rd_wdata_i,

    // Optional Debug / Verification Harness Inspection Port (gated by HAS_DEBUG)
    input  logic [ADDR_W-1:0] dbg_addr_i,
    output logic [31:0]       dbg_rdata_o,
    input  logic              dbg_wen_i,
    input  logic [31:0]       dbg_wdata_i
);

    // -------------------------------------------------------------------------
    // 1. Register Storage Array (x1 .. x[NUM_REGS-1])
    // -------------------------------------------------------------------------
    // Note: Register 0 is omitted from storage and hardwired to zero.
    logic [31:0] regs_q [1:NUM_REGS-1];

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            for (int unsigned i = 1; i < NUM_REGS; i++) begin
                regs_q[i] <= 32'h0000_0000;
            end
        end else begin
            // Architectural commit writeback
            if (rd_wen_i && (rd_addr_i != '0)) begin
                regs_q[rd_addr_i] <= rd_wdata_i;
            end else if (HAS_DEBUG && dbg_wen_i && (dbg_addr_i != '0)) begin
                regs_q[dbg_addr_i] <= dbg_wdata_i;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. Combinational Read Ports with Write-Through Forwarding
    // -------------------------------------------------------------------------
    // Read Port 1 (rs1)
    always_comb begin
        if (rs1_addr_i == '0) begin
            rs1_data_o = 32'h0000_0000;
        end else if (rd_wen_i && (rd_addr_i == rs1_addr_i)) begin
            rs1_data_o = rd_wdata_i;
        end else begin
            rs1_data_o = regs_q[rs1_addr_i];
        end
    end

    // Read Port 2 (rs2)
    always_comb begin
        if (rs2_addr_i == '0) begin
            rs2_data_o = 32'h0000_0000;
        end else if (rd_wen_i && (rd_addr_i == rs2_addr_i)) begin
            rs2_data_o = rd_wdata_i;
        end else begin
            rs2_data_o = regs_q[rs2_addr_i];
        end
    end

    // -------------------------------------------------------------------------
    // 3. Optional Debug / Harness Inspection Port (HAS_DEBUG)
    // -------------------------------------------------------------------------
    generate
        if (HAS_DEBUG) begin : gen_debug_port
            always_comb begin
                if (dbg_addr_i == '0) begin
                    dbg_rdata_o = 32'h0000_0000;
                end else if (rd_wen_i && (rd_addr_i == dbg_addr_i)) begin
                    dbg_rdata_o = rd_wdata_i;
                end else begin
                    dbg_rdata_o = regs_q[dbg_addr_i];
                end
            end
        end else begin : gen_no_debug_port
            assign dbg_rdata_o = 32'h0000_0000;
        end
    endgenerate

endmodule : prf
