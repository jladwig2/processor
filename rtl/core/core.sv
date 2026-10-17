`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/core.sv
// Module:      core
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Single-Hart RISC-V Processor Core Top-Level Wrapper (`rv32im_zicsr_zifencei_zicntr`
//   in M1; expanding to `rv32ima_..._zve64x` with OoO execution in M4–M7).
//
//   Pipeline Organization (5 Logical Stages Connected via Standardized
//   Physical Pipeline Handshakes):
//     1. Stage F (`frontend.sv`):
//        - `pc_gen.sv` + `bpu.sv` + uncached `cbus` instruction fetch +
//          `pma.sv` execute check + `fetch_queue.sv`.
//        - Produces `fetch_valid` / `fetch_ready` / `fetch_pkt` (`fetch_pkt_t`).
//     2. Stage D (`decode.sv`):
//        - `decoder_rv32.sv` translating `fetch_pkt_t` into the final `uop_t`
//          and latching into the Stage D -> Stage I pipeline register.
//        - Produces `dec_valid` / `dec_ready` / `dec_uop` (`uop_t`).
//     3. Stage I (`dispatch.sv` + `prf.sv` + `bypass.sv`):
//        - Reads `prf.sv`, resolves forwarding from Stage X and Stage C via
//          `bypass.sv`, interlocks on multi-cycle/load RAW hazards and
//          serializing instructions, and latches `{issue_uop, issue_rs1_val,
//          issue_rs2_val}` into the Stage I -> Stage X pipeline register.
//     4. Stage X (Execute Multiplexer & Functional Units):
//        - Routes the valid instruction in Stage X (`issue_valid` / `issue_uop`)
//          to its designated functional unit (`issue_uop.fu_type`):
//            * `FU_ALU`:  `alu.sv` (1-cycle combinational)
//            * `FU_BRU`:  `bru.sv` (1-cycle combinational + mispredict redirect)
//            * `FU_MUL`:  `mul.sv` (3-cycle DSP48E1 pipeline)
//            * `FU_DIV`:  `div.sv` (32-cycle radix-2 iterative divider)
//            * `FU_LSU`:  `lsu.sv` (`agu.sv` + `pma.sv` + `misalign.sv`)
//            * `FU_CSR`:  `csr_unit.sv` (CSR read/validate + RMW prepare)
//            * `FU_NONE`: System/Fence/Fault pass-through (1 cycle)
//        - Collects the active unit's completion (`ex_valid`, `ex_ready`,
//          `ex_pkt` of type `ex_wb_t`) and drives the Stage X forwarding tap
//          (`ex_fwd_valid`, `ex_fwd_rd`, `ex_fwd_data`) back to `dispatch.sv`.
//     5. Stage C (`commit.sv` + `trap_ctrl.sv` + `perf_counters.sv`):
//        - Latches `ex_wb_t` into the Stage X -> Stage C pipeline register.
//        - `trap_ctrl.sv` checks for pending interrupts, synchronous exceptions,
//          `mret`, or `fence.i`, generating `trap_redirect_valid` / `flush`.
//        - `commit.sv` writes back `prf.sv` and `csr_unit.sv`, increments
//          `perf_counters.sv`, and exports `commit_trace_o` (`commit_trace_t`).
//     6. Core Bus Interface (`core_cbus_arb.sv`):
//        - Arbitrates `frontend.sv` (`imem_*`) and `lsu.sv` (`dmem_*`) onto the
//          core's unified external `cbus` master port (`cbus_req_o` / `cbus_rsp_i`).
//
// Connections:
//   - Instantiated by: `soc.sv` (`gen_cores[i].u_core`) and `tb_core.sv`.
//   - External Ports:
//       * `clk_i`, `rst_n_i`, `hart_id_i`
//       * `cbus_req_valid_o`, `cbus_req_ready_i`, `cbus_req_o` -> `soc_xbar.sv`
//       * `cbus_rsp_valid_i`, `cbus_rsp_ready_o`, `cbus_rsp_i` <- `soc_xbar.sv`
//       * `meip_i` (from PLIC), `mtip_i` (from CLINT), `msip_i` (from CLINT)
//       * `debug_req_i` (from Debug Module in M2/M4)
//       * `commit_trace_o` (to Verilator/Spike co-simulation harness)
//
// What Needs to Be Implemented:
//   1. Instantiate all child modules (`frontend`, `decode`, `dispatch`, `prf`,
//      `alu`, `bru`, `mul`, `div`, `lsu`, `csr_unit`, `commit`, `trap_ctrl`,
//      `perf_counters`, and `core_cbus_arb`).
//   2. Implement the Stage X functional unit routing, completion muxing into
//      `ex_pkt` (`ex_wb_t`), and Stage X forwarding tap (`ex_fwd_*`).
// =============================================================================

module core
    import soc_pkg::*;
    import cbus_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter logic [31:0] RESET_ADDR     = soc_pkg::RESET_PC,
    parameter int unsigned MAIN_MEM_BYTES = 96 * 1024,
    parameter bit          HAS_MULDIV     = 1'b1,
    parameter bit          HAS_VECTOR     = 1'b0,
    parameter bit          HAS_DEBUG      = 1'b1
) (
    input  logic          clk_i,
    input  logic          rst_n_i,

    // Static Hart Identifier (0 .. N_CORES-1)
    input  logic [31:0]   hart_id_i,

    // Unified Core cbus Master Interface (to soc_xbar.sv)
    output logic          cbus_req_valid_o,
    input  logic          cbus_req_ready_i,
    output cbus_req_t     cbus_req_o,

    input  logic          cbus_rsp_valid_i,
    output logic          cbus_rsp_ready_o,
    input  cbus_rsp_t     cbus_rsp_i,

    // Architectural Machine-Mode Interrupt Inputs (active-high level)
    input  logic          meip_i, // Machine External Interrupt (from PLIC)
    input  logic          mtip_i, // Machine Timer Interrupt    (from CLINT)
    input  logic          msip_i, // Machine Software Interrupt (from CLINT)

    // External JTAG Debug Halt Request (from debug_module.sv in M2/M4)
    input  logic          debug_req_i,

    // Architectural Retirement Trace Output (for Spike lockstep co-sim)
    output commit_trace_t commit_trace_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Instantiate `frontend`, `decode`, `dispatch`, `prf`, `alu`, `bru`,
    //      `mul`, `div`, `lsu`, `csr_unit`, `commit`, `trap_ctrl`,
    //      `perf_counters`, and `core_cbus_arb`.
    //   2. Connect Stage X FU activation, completion multiplexer (`ex_pkt`),
    //      and pipeline flush signals (`bru_redirect_valid || trap_flush`).
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign cbus_req_valid_o = 1'b0;
    assign cbus_req_o       = '0;
    assign cbus_rsp_ready_o = 1'b1;
    assign commit_trace_o   = '0;

endmodule : core
