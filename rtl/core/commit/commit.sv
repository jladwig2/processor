`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/commit/commit.sv
// Module:      commit
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Logical Stage C (Complete / Commit / Writeback) physical pipeline stage
//   and architectural retirement coordinator.
//
//   Architecture & Operation:
//     1. Stage X -> Stage C Physical Pipeline Register:
//        - Latches the completed Execute bundle (`ex_wb_t` containing `uop`,
//          `rd_wdata`, `csr_wen`, `csr_addr`, `csr_wdata`, `mem_valid`,
//          `mem_addr`, `mem_wdata`, `mem_wstrb`) using our standardized
//          physical pipeline handshake (`ex_valid_i` / `wb_ready_o`).
//        - Because Commit is the terminal stage of the pipeline and never
//          stalls in M1, `wb_ready_o` is unconditionally `1'b1`.
//     2. Exception-Gated Architectural State Commit:
//        - Presents `wb_valid_o` and `wb_pkt_o` to `trap_ctrl.sv`.
//        - If `wb_valid_q` is asserted and `trap_enter_i == 1'b0`:
//            * Commits integer register writeback (`prf_rd_wen_o =
//              wb_pkt_q.uop.rd_wen && (wb_pkt_q.uop.rd_addr != 5'd0)`).
//            * Commits CSR writeback (`commit_csr_wen_o = wb_pkt_q.csr_wen`).
//            * Increments `minstret` (`instret_inc_o = 1'b1`).
//        - If `trap_enter_i == 1'b1` (synchronous exception or interrupt):
//            * Suppresses `prf_rd_wen_o = 1'b0`, `commit_csr_wen_o = 1'b0`,
//              and `instret_inc_o = 1'b0` so the faulting/interrupted
//              instruction leaves architectural registers untouched.
//     3. Forwarding Tap to Stage I (`bypass.sv` / `dispatch.sv`):
//        - Exports `wb_fwd_valid_o`, `wb_fwd_rd_o`, and `wb_fwd_data_o` so
//          instructions in Stage I can forward the result of an instruction
//          currently retiring in Stage C.
//     4. Spike / Co-Simulation Retirement Trace (`commit_trace_o`):
//        - Drives `commit_trace_t` (`valid`, `pc`, `insn`, `rd_wen`, `rd_addr`,
//          `rd_wdata`, `mem_valid`, `mem_is_store`, `mem_addr`, `mem_wdata`,
//          `trap_taken`, `trap_is_irq`, `trap_cause`) on every retired or
//          trapped instruction for cycle-accurate lockstep verification.
//
// Connections:
//   - Instantiated by: `core.sv` (`u_commit`).
//   - Upstream (Stage X -> Stage C in `core.sv`):
//       * `ex_valid_i`, `wb_ready_o`, `ex_pkt_i`
//   - Trap Controller Interface (`trap_ctrl.sv`):
//       * `wb_valid_o`, `wb_pkt_o` -> `trap_ctrl.sv`
//       * `trap_enter_i`, `trap_is_irq_i`, `trap_cause_i`, `flush_i` <- `trap_ctrl.sv`
//   - Architectural State Write Ports:
//       * `prf_rd_wen_o`, `prf_rd_addr_o`, `prf_rd_wdata_o` -> `prf.sv`
//       * `commit_csr_wen_o`, `commit_csr_addr_o`, `commit_csr_wdata_o` -> `csr_unit.sv`
//       * `instret_inc_o` -> `perf_counters.sv`
//   - Forwarding Tap:
//       * `wb_serializing_o`, `wb_fwd_valid_o`, `wb_fwd_rd_o`, `wb_fwd_data_o` -> `dispatch.sv`
//   - Verification Trace Port:
//       * `commit_trace_o` -> `core.sv` top-level port
//
// What Needs to Be Implemented:
//   1. Implement the Stage X -> Stage C physical pipeline register (`wb_valid_q`,
//      `wb_pkt_q`).
//   2. Implement exception-gated `prf_rd_wen_o`, `commit_csr_wen_o`,
//      `instret_inc_o`, forwarding outputs, and `commit_trace_o` assignment.
// =============================================================================

module commit
    import rv_pkg::*;
    import core_pkg::*;
(
    input  logic                   clk_i,
    input  logic                   rst_n_i,

    // Pipeline flush from trap_ctrl (clears X -> C register after trap/mret/fence.i)
    input  logic                   flush_i,

    // Upstream Physical Pipeline Interface (from Stage X in core.sv)
    input  logic                   ex_valid_i,
    output logic                   wb_ready_o,
    input  ex_wb_t                 ex_pkt_i,

    // Trap Controller Interface (to/from trap_ctrl.sv)
    output logic                   wb_valid_o,
    output ex_wb_t                 wb_pkt_o,
    input  logic                   trap_enter_i,
    input  logic                   trap_is_irq_i,
    input  logic [3:0]             trap_cause_i,

    // Physical Register File Writeback Port (to prf.sv)
    output logic                   prf_rd_wen_o,
    output logic [PRF_ADDR_W-1:0]  prf_rd_addr_o,
    output logic [31:0]            prf_rd_wdata_o,

    // Architectural CSR Writeback Port (to csr_unit.sv)
    output logic                   commit_csr_wen_o,
    output logic [CSR_ADDR_W-1:0]  commit_csr_addr_o,
    output logic [31:0]            commit_csr_wdata_o,

    // Performance Counter Increment (to perf_counters.sv)
    output logic                   instret_inc_o,

    // Stage C Forwarding & Status Tap (to dispatch.sv / bypass.sv)
    output logic                   wb_serializing_o,
    output logic                   wb_fwd_valid_o,
    output logic [PRF_ADDR_W-1:0]  wb_fwd_rd_o,
    output logic [31:0]            wb_fwd_data_o,

    // Architectural Retirement Trace (to core.sv -> tb_core / Spike co-sim)
    output commit_trace_t          commit_trace_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Implement Stage X -> Stage C physical pipeline register (`wb_valid_q`,
    //      `wb_pkt_q`).
    //   2. Drive `prf_rd_*`, `commit_csr_*`, `instret_inc_o`, `wb_fwd_*`, and
    //      `commit_trace_o` gated by `!trap_enter_i`.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign wb_ready_o         = 1'b1;
    assign wb_valid_o         = 1'b0;
    assign wb_pkt_o           = '0;
    assign prf_rd_wen_o       = 1'b0;
    assign prf_rd_addr_o      = '0;
    assign prf_rd_wdata_o     = 32'h0;
    assign commit_csr_wen_o   = 1'b0;
    assign commit_csr_addr_o  = '0;
    assign commit_csr_wdata_o = 32'h0;
    assign instret_inc_o      = 1'b0;
    assign wb_serializing_o   = 1'b0;
    assign wb_fwd_valid_o     = 1'b0;
    assign wb_fwd_rd_o        = '0;
    assign wb_fwd_data_o      = 32'h0;
    assign commit_trace_o     = '0;

endmodule : commit

