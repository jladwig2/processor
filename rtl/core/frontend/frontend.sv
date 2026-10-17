`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/frontend/frontend.sv
// Module:      frontend
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Top-level Instruction Fetch Unit (Logical Stage F). Responsible for
//   generating instruction fetch addresses, checking fetch alignment and
//   Physical Memory Attributes (PMA), issuing instruction read requests over
//   the core's `imem` `cbus` master port, discarding stale in-flight fetches
//   after pipeline flushes, and queuing fetched `fetch_pkt_t` bundles for the
//   Decode stage (`decode.sv`).
//
//   Architecture & Operation (M1 Configuration):
//     1. PC Generation & Prediction:
//        - Instantiates `pc_gen.sv` (`u_pc_gen`) and `bpu.sv` (`u_bpu`).
//     2. Pre-Fetch Exception Check (Alignment & PMA):
//        - Instantiates `pma.sv` (`u_ifetch_pma`) on `fetch_pc`.
//        - If `fetch_pc[1:0] != 2'b00`, flags `EXC_INSTR_ADDR_MISALIGNED` (0).
//        - Else if `!pma_attr.is_mapped || !pma_attr.is_executable`, flags
//          `EXC_INSTR_ACCESS_FAULT` (1).
//        - When a fetch exception is detected, `frontend` does NOT issue a
//          bus transaction; instead, it pushes a synthetic `fetch_pkt_t` with
//          `exc_valid = 1'b1` directly into `fetch_queue` so the fault is
//          taken precisely when that instruction reaches Commit!
//     3. Uncached `cbus` Fetch FSM & Flush-Discard Tracking:
//        - Issues `CBUS_GET` (`src_id = 4'd0`, `addr = fetch_pc`) on
//          `imem_req_o` whenever `fetch_queue` has space and no request is
//          currently waiting for a response.
//        - **Critical Stale-Fetch Discard Rule:** If `bru_redirect_valid_i` or
//          `trap_redirect_valid_i` asserts while a `cbus` request is already in
//          flight (`req_pending_q == 1'b1` and `!imem_rsp_valid_i`), the bus
//          transaction cannot be aborted mid-flight on `cbus`. Instead,
//          `frontend` sets `kill_pending_rsp_q <= 1'b1`. When `imem_rsp_valid_i`
//          later arrives, its data is silently dropped (`kill_pending_rsp_q <=
//          1'b0`) before issuing the new fetch at the redirected PC.
//        - If `imem_rsp_i.err == 1'b1` on a non-killed response, sets
//          `pkt.exc_valid = 1'b1` and `pkt.exc_cause = EXC_INSTR_ACCESS_FAULT`.
//     4. Instruction Queue (`fetch_queue.sv`):
//        - Buffers completed `fetch_pkt_t` packets and presents the standardized
//          physical pipeline handshake (`fetch_valid_o` / `fetch_ready_i` /
//          `fetch_pkt_o`) to `decode.sv`.
//
// Connections:
//   - Instantiated by: `core.sv` (`u_frontend`).
//   - Redirect Inputs:
//       * `trap_redirect_valid_i` / `trap_redirect_pc_i` <- `trap_ctrl.sv`
//       * `bru_redirect_valid_i`  / `bru_redirect_pc_i`  <- `bru.sv`
//   - Instruction Memory Bus (`cbus` Master Port 0):
//       * `imem_req_valid_o`, `imem_req_ready_i`, `imem_req_o` -> `core_cbus_arb.sv`
//       * `imem_rsp_valid_i`, `imem_rsp_ready_o`, `imem_rsp_i` <- `core_cbus_arb.sv`
//   - Downstream Pipeline Interface (Stage F -> Stage D):
//       * `fetch_valid_o`, `fetch_ready_i`, `fetch_pkt_o` -> `decode.sv`
//   - Child Modules:
//       * `pc_gen.sv` (`u_pc_gen`)
//       * `bpu.sv` (`u_bpu`)
//       * `pma.sv` (`u_ifetch_pma`)
//       * `fetch_queue.sv` (`u_fetch_queue`)
//
// What Needs to Be Implemented:
//   1. Instantiate `pc_gen`, `bpu`, `pma`, and `fetch_queue`.
//   2. Implement the fetch request/response FSM with `kill_pending_rsp_q`
//      tracking so redirects during an in-flight `cbus` read cleanly discard
//      the stale response.
// =============================================================================

module frontend
    import soc_pkg::*;
    import cbus_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter logic [31:0] RESET_ADDR     = soc_pkg::RESET_PC,
    parameter int unsigned MAIN_MEM_BYTES = 96 * 1024
) (
    input  logic       clk_i,
    input  logic       rst_n_i,

    // Commit-stage redirect (Trap / MRET / FENCE.I from trap_ctrl)
    input  logic       trap_redirect_valid_i,
    input  logic [31:0] trap_redirect_pc_i,

    // Execute-stage redirect (Branch / Jump mispredict from bru)
    input  logic       bru_redirect_valid_i,
    input  logic [31:0] bru_redirect_pc_i,

    // Execute-stage BPU training interface (from bru, used in M5+)
    input  logic       bpu_upd_valid_i,
    input  logic [31:0] bpu_upd_pc_i,
    input  logic       bpu_upd_taken_i,
    input  logic [31:0] bpu_upd_target_i,
    input  logic       bpu_upd_is_call_i,
    input  logic       bpu_upd_is_ret_i,

    // Instruction Memory cbus Master Interface (to core_cbus_arb, src_id = 0)
    output logic       imem_req_valid_o,
    input  logic       imem_req_ready_i,
    output cbus_req_t  imem_req_o,

    input  logic       imem_rsp_valid_i,
    output logic       imem_rsp_ready_o,
    input  cbus_rsp_t  imem_rsp_i,

    // Downstream Physical Pipeline Interface (Stage F -> Stage D: decode.sv)
    output logic       fetch_valid_o,
    input  logic       fetch_ready_i,
    output fetch_pkt_t fetch_pkt_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Instantiate `pc_gen` (`u_pc_gen`), `bpu` (`u_bpu`), `pma`
    //      (`u_ifetch_pma`), and `fetch_queue` (`u_fetch_queue`).
    //   2. Implement the in-flight `cbus` fetch FSM (`ST_IDLE`, `ST_WAIT_RSP`,
    //      `ST_FAULT_PUSH`) and `kill_pending_rsp_q` flush-discard logic.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign imem_req_valid_o = 1'b0;
    assign imem_req_o       = '0;
    assign imem_rsp_ready_o = 1'b1;
    assign fetch_valid_o    = 1'b0;
    assign fetch_pkt_o      = '0;

endmodule : frontend
