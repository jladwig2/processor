`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/execute/csr_unit.sv
// Module:      csr_unit
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Machine-Mode Control and Status Register (CSR) File and Zicsr Atomic
//   Read-Modify-Write Execution Unit (`csrrw`, `csrrs`, `csrrc`, `csrrwi`,
//   `csrrsi`, `csrrci`).
//
//   Why Full M-Mode CSR & Illegal-CSR Support Is Essential in M1:
//     The official `riscv-tests` startup macro (`RVTEST_CODE_BEGIN` in
//     `sw/tests/riscv-tests/env/p/riscv_test.h`) probes optional extensions
//     and privilege modes by setting `mtvec` to a recovery handler and
//     attempting to access `mnstatus`, `satp`, `pmpaddr0`, `pmpcfg0`, and
//     `medeleg`, expecting an **Illegal Instruction exception (`mcause = 2`)**
//     on every unimplemented CSR! It then writes `mepc` and executes `mret` to
//     enter the test body, and finishes via `ecall` (`mcause = 11`).
//
//   Implemented CSRs in M1:
//     - `0xF11` (`mvendorid`, MRO): `32'h0000_0000`
//     - `0xF12` (`marchid`,   MRO): `32'h0000_0000`
//     - `0xF13` (`mimpid`,    MRO): `32'h0000_0002` (v0.2)
//     - `0xF14` (`mhartid`,   MRO): `hart_id_i`
//     - `0x300` (`mstatus`,   MRW): `MIE` (bit 3), `MPIE` (bit 7), `MPP`
//                                   (bits [12:11], WARL hardwired to `2'b11`
//                                   since only M-mode is implemented in M1)
//     - `0x301` (`misa`,      MRW): `32'h4000_0100 | (HAS_MULDIV ? (1<<12) : 0)`
//                                   (MXL=1 for RV32, I + optional M; writes
//                                   ignored per WARL)
//     - `0x304` (`mie`,       MRW): `MEIE` (bit 11), `MTIE` (bit 7), `MSIE` (bit 3)
//     - `0x305` (`mtvec`,     MRW): Trap vector base `[31:2]` and mode `[1:0]`
//     - `0x306` (`mcounteren`,MRW): Counter enable register (WARL)
//     - `0x320` (`mcountinhibit`, MRW): Counter inhibit bits `[2]` (`IR`), `[0]` (`CY`)
//     - `0x340` (`mscratch`,  MRW): 32-bit M-mode scratch register
//     - `0x341` (`mepc`,      MRW): 32-bit exception PC (`mepc[1:0] == 2'b00`)
//     - `0x342` (`mcause`,    MRW): Interrupt flag `[31]` and cause code `[3:0]`
//     - `0x343` (`mtval`,     MRW): 32-bit trap value (faulting address or insn)
//     - `0x344` (`mip`,       MRO): Live interrupt pending `{meip_i, mtip_i, msip_i}`
//     - `0xB00`/`0xB80` (`mcycle`/`mcycleh`, MRW): From `perf_counters.sv`
//     - `0xB02`/`0xB82` (`minstret`/`minstreth`, MRW): From `perf_counters.sv`
//     - `0xC00`/`0xC80` (`cycle`/`cycleh`, URO): Read-only shadows of `mcycle[h]`
//     - `0xC01`/`0xC81` (`time`/`timeh`,   URO): Read-only shadows of `mcycle[h]`
//                                                (or CLINT `mtime` in M2)
//     - `0xC02`/`0xC82` (`instret`/`instreth`, URO): Read-only shadows of `minstret[h]`
//
//   Illegal CSR Access Rules (RISC-V Privileged Spec §2.1):
//     1. Accessing any CSR address not in the list above sets `illegal_csr_o = 1'b1`.
//     2. Attempting to write a Read-Only CSR (`csr_addr[11:10] == 2'b11`) when
//        the instruction performs a write (`CSR_RW` always writes; `CSR_RS` and
//        `CSR_RC` write if and only if `uop_i.rs1_addr != 5'd0`) sets
//        `illegal_csr_o = 1'b1`.
//
// Connections:
//   - Instantiated by: `core.sv` (`u_csr_unit`).
//   - Stage X Query Interface:
//       * `uop_i`, `rs1_val_i` -> `rdata_o`, `wdata_o`, `wen_o`, `illegal_csr_o`
//   - Stage C Commit Write Interface (from `commit.sv`):
//       * `commit_csr_wen_i`, `commit_csr_addr_i`, `commit_csr_wdata_i`
//   - Trap / MRET State Update Interface (to/from `trap_ctrl.sv`):
//       * `trap_enter_i`, `trap_is_irq_i`, `trap_epc_i`, `trap_cause_i`, `trap_tval_i`
//       * `mret_enter_i`
//       * `csr_mtvec_o`, `csr_mepc_o`, `csr_mstatus_mie_o`, `csr_mie_o`, `csr_mip_o`
//   - Counter Interface (to/from `perf_counters.sv`):
//       * `mcycle_i`, `minstret_i`, `cnt_wen_o`, `cnt_is_minstret_o`,
//         `cnt_is_high_o`, `cnt_wdata_o`
//
// What Needs to Be Implemented:
//   1. Implement the combinational CSR read & existence decoder (`rdata_o`,
//      `illegal_csr_o`) and atomic RMW calculation (`wdata_o`, `wen_o`).
//   2. Implement sequential CSR registers (`mstatus_q`, `mtvec_q`, `mscratch_q`,
//      `mepc_q`, `mcause_q`, `mtval_q`, `mie_q`) updated on `commit_csr_wen_i`,
//      `trap_enter_i`, or `mret_enter_i`.
// =============================================================================

module csr_unit
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter bit HAS_MULDIV = 1'b1
) (
    input  logic                  clk_i,
    input  logic                  rst_n_i,

    // Hardware Hart ID and External Interrupt Lines
    input  logic [31:0]           hart_id_i,
    input  logic                  meip_i,
    input  logic                  mtip_i,
    input  logic                  msip_i,

    // Stage X Combinational Read & RMW Evaluation
    input  uop_t                  uop_i,
    input  logic [31:0]           rs1_val_i,
    output logic [31:0]           rdata_o,
    output logic [31:0]           wdata_o,
    output logic                  wen_o,
    output logic                  illegal_csr_o,

    // Stage C Architectural CSR Commit Port (from commit.sv)
    input  logic                  commit_csr_wen_i,
    input  logic [CSR_ADDR_W-1:0] commit_csr_addr_i,
    input  logic [31:0]           commit_csr_wdata_i,

    // Trap & MRET State Update Port (from/to trap_ctrl.sv)
    input  logic                  trap_enter_i,
    input  logic                  trap_is_irq_i,
    input  logic [31:0]           trap_epc_i,
    input  logic [3:0]            trap_cause_i,
    input  logic [31:0]           trap_tval_i,
    input  logic                  mret_enter_i,

    output logic [31:0]           csr_mtvec_o,
    output logic [31:0]           csr_mepc_o,
    output logic                  csr_mstatus_mie_o,
    output logic [31:0]           csr_mie_o,
    output logic [31:0]           csr_mip_o,

    // Hardware Performance Counter Interface (to/from perf_counters.sv)
    input  logic [63:0]           mcycle_i,
    input  logic [63:0]           minstret_i,
    output logic                  cnt_wen_o,
    output logic                  cnt_is_minstret_o,
    output logic                  cnt_is_high_o,
    output logic [31:0]           cnt_wdata_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Implement CSR existence/permission check (`illegal_csr_o`) and
    //      combinational read mux (`rdata_o`) + RMW logic (`wdata_o`, `wen_o`).
    //   2. Implement M-mode CSR registers (`mstatus_q`, `mtvec_q`, `mepc_q`,
    //      `mcause_q`, `mtval_q`, `mscratch_q`, `mie_q`) with `trap_enter_i`
    //      and `mret_enter_i` state transitions.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs
    assign rdata_o           = 32'h0;
    assign wdata_o           = 32'h0;
    assign wen_o             = 1'b0;
    assign illegal_csr_o     = 1'b0;
    assign csr_mtvec_o       = 32'h0;
    assign csr_mepc_o        = 32'h0;
    assign csr_mstatus_mie_o = 1'b0;
    assign csr_mie_o         = 32'h0;
    assign csr_mip_o         = 32'h0;
    assign cnt_wen_o         = 1'b0;
    assign cnt_is_minstret_o = 1'b0;
    assign cnt_is_high_o     = 1'b0;
    assign cnt_wdata_o       = 32'h0;

endmodule : csr_unit

