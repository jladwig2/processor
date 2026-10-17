`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/mem/core_cbus_arb.sv
// Module:      core_cbus_arb
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Per-Core `cbus` Request Arbiter and Response Demultiplexer. Multiplexes the
//   core's Instruction Fetch `cbus` port (`imem_*` from `frontend.sv` /
//   `l1_icache.sv`) and Data Memory `cbus` port (`dmem_*` from `lsu.sv` /
//   `l1_dcache.sv`) onto the core's single external `cbus` master interface
//   (`core_req_o` / `core_rsp_i`).
//
//   Why Data Memory Has Priority Over Instruction Fetch:
//     - In a pipelined processor, an instruction in Stage X (`lsu.sv`) is older
//       than any instruction being fetched in Stage F (`frontend.sv`) and may
//       be stalling the entire pipeline while awaiting `dmem_rsp_i`.
//     - If `frontend.sv` were allowed to monopolize the bus while Decode/Issue
//       are stalled behind `lsu.sv`, the pipeline could livelock. Therefore,
//       `dmem_req_valid_i` (tagged with `src_id = 4'd1`) is given priority over
//       `imem_req_valid_i` (tagged with `src_id = 4'd0`), or transactions are
//       serialized one-at-a-time with `dmem` priority.
//     - On the response channel (`core_rsp_i`), `core_rsp_i.src_id[0]` routes
//       responses with `src_id[0] == 1'b0` to `imem_rsp_o` and responses with
//       `src_id[0] == 1'b1` to `dmem_rsp_o`.
//
// Connections:
//   - Instantiated by: `core.sv` (`u_core_cbus_arb`).
//   - Upstream Slave Port 0 (Instruction Fetch from `frontend.sv`):
//       * `imem_req_valid_i`, `imem_req_ready_o`, `imem_req_i`
//       * `imem_rsp_valid_o`, `imem_rsp_ready_i`, `imem_rsp_o`
//   - Upstream Slave Port 1 (Data LSU from `lsu.sv`):
//       * `dmem_req_valid_i`, `dmem_req_ready_o`, `dmem_req_i`
//       * `dmem_rsp_valid_o`, `dmem_rsp_ready_i`, `dmem_rsp_o`
//   - Downstream Master Port (to `soc_xbar.sv` via `core.sv` ports):
//       * `core_req_valid_o`, `core_req_ready_i`, `core_req_o`
//       * `core_rsp_valid_i`, `core_rsp_ready_o`, `core_rsp_i`
//
// What Needs to Be Implemented:
//   1. Implement request arbitration (`dmem` priority over `imem`), overriding
//      `core_req_o.src_id` with `{hart_id_i[2:0], 1'b0}` for `imem` and
//      `{hart_id_i[2:0], 1'b1}` for `dmem`.
//   2. Implement response demultiplexing based on `core_rsp_i.src_id[0]`.
// =============================================================================

module core_cbus_arb
    import cbus_pkg::*;
(
    input  logic      clk_i,
    input  logic      rst_n_i,

    // Hart ID (used to tag upper bits of src_id[3:1])
    input  logic [31:0] hart_id_i,

    // Port 0: Instruction Fetch (from frontend.sv)
    input  logic      imem_req_valid_i,
    output logic      imem_req_ready_o,
    input  cbus_req_t imem_req_i,

    output logic      imem_rsp_valid_o,
    input  logic      imem_rsp_ready_i,
    output cbus_rsp_t imem_rsp_o,

    // Port 1: Data Memory / LSU (from lsu.sv)
    input  logic      dmem_req_valid_i,
    output logic      dmem_req_ready_o,
    input  cbus_req_t dmem_req_i,

    output logic      dmem_rsp_valid_o,
    input  logic      dmem_rsp_ready_i,
    output cbus_rsp_t dmem_rsp_o,

    // Unified External Core cbus Master Interface (to soc_xbar.sv)
    output logic      core_req_valid_o,
    input  logic      core_req_ready_i,
    output cbus_req_t core_req_o,

    input  logic      core_rsp_valid_i,
    output logic      core_rsp_ready_o,
    input  cbus_rsp_t core_rsp_i
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement `dmem`-priority request muxing (tagging `src_id[0] = 0` for
    //   `imem` and `src_id[0] = 1` for `dmem`) and `src_id[0]`-based response
    //   routing.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign imem_req_ready_o = 1'b0;
    assign imem_rsp_valid_o = 1'b0;
    assign imem_rsp_o       = '0;
    assign dmem_req_ready_o = 1'b0;
    assign dmem_rsp_valid_o = 1'b0;
    assign dmem_rsp_o       = '0;
    assign core_req_valid_o = 1'b0;
    assign core_req_o       = '0;
    assign core_rsp_ready_o = 1'b1;

endmodule : core_cbus_arb

