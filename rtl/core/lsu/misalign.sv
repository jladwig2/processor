`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/lsu/misalign.sv
// Module:      misalign
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Hardware Misaligned & Sub-Word Memory Access Engine for `lsu.sv`.
//   Translates any architectural byte, halfword, or word load/store at an
//   arbitrary byte offset (`addr_i[1:0]`) into one or two 32-bit word-aligned
//   `cbus` transactions, performing all required byte-lane steering, write-
//   strobe generation, read byte assembly, and sign/zero extension.
//
//   Why This Module Exists:
//     - Standard RISC-V software (and the official `rv32ui-p-ma_data` test)
//       executes unaligned halfword (`lh`, `lhu`, `sh`) and word (`lw`, `sw`)
//       loads and stores at byte offsets `1`, `2`, and `3`.
//     - Handling misaligned accesses in hardware (by cracking word-boundary-
//       crossing requests into two aligned 32-bit accesses and shifting/merging
//       the bytes) avoids expensive software trap-and-emulate handlers.
//
//   Operation & State Machine:
//     1. Single-Word Access (`!crosses_word_i`):
//        - Covers all `LSU_BYTE` accesses, `LSU_HALF` at offsets `0, 1, 2`, and
//          `LSU_WORD` at offset `0`.
//        - Issues one `cbus` request to `{addr_i[31:2], 2'b00}`:
//            * Store: shifts `wdata_i` left by `8 * addr_i[1:0]` and shifts
//              base mask (`4'b0001`, `4'b0011`, or `4'b1111`) left by
//              `addr_i[1:0]`. Uses `CBUS_PUT_FULL` if `wstrb == 4'b1111`, else
//              `CBUS_PUT_PARTIAL`.
//            * Load: shifts `dmem_rsp_i.rdata` right by `8 * addr_i[1:0]` and
//              sign- or zero-extends according to `lsu_size_i` and
//              `lsu_unsigned_i`.
//     2. Split Two-Word Access (`crosses_word_i == 1'b1`):
//        - Covers `LSU_HALF` at offset `3`, and `LSU_WORD` at offsets `1, 2, 3`.
//        - Phase 1 (Low Word @ `{addr_i[31:2], 2'b00}`):
//            * Store: writes low bytes of `wdata_i` into upper byte lanes of
//              Word 0 (`wdata = wdata_i << (8 * offset)`, `wstrb = base_mask << offset`).
//            * Load: reads Word 0 and saves `low_part_q = rdata >> (8 * offset)`.
//        - Phase 2 (High Word @ `{addr_i[31:2] + 30'd1, 2'b00}`):
//            * Store: writes remaining upper bytes of `wdata_i` into lower byte
//              lanes of Word 1 (`wdata = wdata_i >> (8 * (4 - offset))`,
//              `wstrb = base_mask >> (4 - offset)`).
//            * Load: reads Word 1, merges `(rdata << (8 * (4 - offset))) | low_part_q`,
//              and applies sign/zero extension for `LSU_HALF` at offset `3`.
//        - Both halves must complete without `dmem_rsp_i.err` before
//          `out_valid_o` asserts; if either transfer returns `err == 1'b1`,
//          asserts `bus_err_o = 1'b1`.
//
// Connections:
//   - Instantiated by: `lsu.sv` (`u_misalign`).
//   - Upstream (from `lsu.sv` control):
//       * `in_valid_i`, `in_ready_o`, `is_store_i`, `lsu_size_i`,
//         `lsu_unsigned_i`, `addr_i`, `wdata_i`, `crosses_word_i`
//   - Downstream Memory Bus (`cbus` Master Port 1, `src_id = 4'd1`):
//       * `dmem_req_valid_o`, `dmem_req_ready_i`, `dmem_req_o`
//       * `dmem_rsp_valid_i`, `dmem_rsp_ready_o`, `dmem_rsp_i`
//   - Completion Interface (to `lsu.sv`):
//       * `out_valid_o`, `out_ready_i`, `rdata_o`, `bus_err_o`
//
// What Needs to Be Implemented:
//   1. Implement the 4-state FSM (`ST_IDLE`, `ST_REQ0_WAIT`, `ST_REQ1_ISSUE`,
//      `ST_REQ1_WAIT`, `ST_DONE`) and byte-lane shift/mask/merge datapath.
// =============================================================================

module misalign
    import cbus_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
(
    input  logic       clk_i,
    input  logic       rst_n_i,
    input  logic       flush_i,

    // Request from LSU
    input  logic       in_valid_i,
    output logic       in_ready_o,
    input  logic       is_store_i,
    input  lsu_size_e  lsu_size_i,
    input  logic       lsu_unsigned_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic       crosses_word_i,

    // Completion to LSU
    output logic       out_valid_o,
    input  logic       out_ready_i,
    output logic [31:0] rdata_o,
    output logic       bus_err_o,

    // Data Memory cbus Master Interface (to core_cbus_arb, src_id = 1)
    output logic       dmem_req_valid_o,
    input  logic       dmem_req_ready_i,
    output cbus_req_t  dmem_req_o,

    input  logic       dmem_rsp_valid_i,
    output logic       dmem_rsp_ready_o,
    input  cbus_rsp_t  dmem_rsp_i
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement single-word and split two-word `cbus` transaction FSM,
    //   byte-lane shift/strobe generation, and load sign/zero extension.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign in_ready_o       = 1'b0;
    assign out_valid_o      = 1'b0;
    assign rdata_o          = 32'h0;
    assign bus_err_o        = 1'b0;
    assign dmem_req_valid_o = 1'b0;
    assign dmem_req_o       = '0;
    assign dmem_rsp_ready_o = 1'b1;

endmodule : misalign

