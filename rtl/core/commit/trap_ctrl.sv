`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/commit/trap_ctrl.sv
// Module:      trap_ctrl
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Precise Exception, Interrupt, `mret`, and `fence.i` Pipeline Redirect
//   Controller located in Logical Stage C (`commit.sv`).
//
//   Why All Traps & Serializing Redirects Happen at Commit:
//     Handling exceptions, external/timer/software interrupts, `mret`, and
//     `fence.i` strictly at the Commit boundary guarantees **precise
//     exceptions**:
//       - Every older instruction prior to the faulting instruction has
//         already committed its architectural state.
//       - The faulting instruction itself and all younger speculative
//         instructions in Stages F, D, I, and X are squashed (`flush_o = 1'b1`)
//         without modifying `prf.sv` or CSRs.
//       - Wrong-path exceptions detected in speculative shadow of a mispredicted
//         branch are automatically flushed when `bru.sv` redirects the pipeline
//         before they ever reach `trap_ctrl.sv`.
//
//   Commit-Boundary Event Priority Hierarchy:
//     1. Asynchronous Machine Interrupts (`wb_valid_i && csr_mstatus_mie_i`):
//        - Evaluated on `pending_irqs = csr_mie_i & csr_mip_i`:
//            a. Machine External Interrupt (`pending_irqs[11]`, `cause = 4'd11`)
//            b. Machine Software Interrupt (`pending_irqs[3]`,  `cause = 4'd3`)
//            c. Machine Timer Interrupt    (`pending_irqs[7]`,  `cause = 4'd7`)
//        - Interrupt is taken *before* `wb_pkt_i` executes/commits:
//          `trap_enter_o = 1'b1`, `trap_is_irq_o = 1'b1`,
//          `trap_epc_o = wb_pkt_i.uop.pc`, `trap_tval_o = 32'h0`.
//     2. Synchronous Exception (`wb_valid_i && wb_pkt_i.uop.exc_valid`):
//        - `trap_enter_o = 1'b1`, `trap_is_irq_o = 1'b0`,
//          `trap_epc_o = wb_pkt_i.uop.pc`,
//          `trap_cause_o = wb_pkt_i.uop.exc_cause`,
//          `trap_tval_o = wb_pkt_i.uop.exc_tval`.
//     3. Machine Trap Return (`wb_valid_i && !exc_valid && wb_pkt_i.uop.is_mret`):
//        - `mret_enter_o = 1'b1`, `redirect_valid_o = 1'b1`,
//          `redirect_pc_o = csr_mepc_i`, `flush_o = 1'b1`.
//     4. Instruction-Fetch Fence (`wb_valid_i && !exc_valid && wb_pkt_i.uop.is_fence_i`):
//        - Flushes all younger instructions (which may have been fetched before
//          an older store modified instruction memory) and refetches from
//          `redirect_pc_o = wb_pkt_i.uop.pc + 32'd4`.
//
//   Trap Vector Calculation (`csr_mtvec_i`):
//     - `base = {csr_mtvec_i[31:2], 2'b00}`
//     - Direct mode (`csr_mtvec_i[1:0] == 2'b00`) or synchronous exception:
//         `redirect_pc_o = base`
//     - Vectored mode (`csr_mtvec_i[1:0] == 2'b01`) AND asynchronous interrupt:
//         `redirect_pc_o = base + {26'b0, trap_cause_o, 2'b00}`
//
// Connections:
//   - Instantiated by: `core.sv` (`u_trap_ctrl`).
//   - Inputs:
//       * `wb_valid_i`, `wb_pkt_i` <- `commit.sv`
//       * `csr_mtvec_i`, `csr_mepc_i`, `csr_mstatus_mie_i`, `csr_mie_i`,
//         `csr_mip_i` <- `csr_unit.sv`
//   - Outputs:
//       * `trap_enter_o`, `trap_is_irq_o`, `trap_epc_o`, `trap_cause_o`,
//         `trap_tval_o`, `mret_enter_o` -> `csr_unit.sv` & `commit.sv`
//       * `redirect_valid_o`, `redirect_pc_o` -> `frontend.sv`
//       * `flush_o` -> `frontend.sv`, `decode.sv`, `dispatch.sv`, `mul.sv`,
//         `div.sv`, `lsu.sv`
//
// What Needs to Be Implemented:
//   1. Implement the combinational interrupt/exception/`mret`/`fence.i`
//      priority resolver driving `trap_enter_o`, `mret_enter_o`,
//      `redirect_valid_o`, `redirect_pc_o`, and `flush_o`.
// =============================================================================

module trap_ctrl
    import rv_pkg::*;
    import core_pkg::*;
(
    // Commit-stage instruction packet
    input  logic       wb_valid_i,
    input  ex_wb_t     wb_pkt_i,

    // CSR Trap & Interrupt State (from csr_unit.sv)
    input  logic [31:0] csr_mtvec_i,
    input  logic [31:0] csr_mepc_i,
    input  logic        csr_mstatus_mie_i,
    input  logic [31:0] csr_mie_i,
    input  logic [31:0] csr_mip_i,

    // Trap & MRET Triggers (to csr_unit.sv and commit.sv)
    output logic        trap_enter_o,
    output logic        trap_is_irq_o,
    output logic [31:0] trap_epc_o,
    output logic [3:0]  trap_cause_o,
    output logic [31:0] trap_tval_o,
    output logic        mret_enter_o,

    // Global Pipeline Flush & PC Redirect (to frontend.sv and all younger stages)
    output logic        redirect_valid_o,
    output logic [31:0] redirect_pc_o,
    output logic        flush_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement interrupt priority encoder, synchronous exception handler,
    //   `mret` and `fence.i` redirect logic, and `mtvec` direct/vectored target
    //   calculation.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign trap_enter_o     = 1'b0;
    assign trap_is_irq_o    = 1'b0;
    assign trap_epc_o       = 32'h0;
    assign trap_cause_o     = 4'd0;
    assign trap_tval_o      = 32'h0;
    assign mret_enter_o     = 1'b0;
    assign redirect_valid_o = 1'b0;
    assign redirect_pc_o    = 32'h0;
    assign flush_o          = 1'b0;

endmodule : trap_ctrl

