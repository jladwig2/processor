`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/pkg/core_pkg.sv
// Package:     core_pkg
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Central microarchitectural definitions package for the RISC-V processor
//   core (`rtl/core/**`).
//
//   Why This Package Is Structured for Finality in M1:
//     Milestone 1 builds a single-issue, in-order 5-stage pipeline (`F -> D ->
//     I -> X -> C`), while Milestone 4 upgrades the middle stages (`D -> I -> C`)
//     to a 2-wide out-of-order superscalar engine with register renaming,
//     64-entry ROB, and distributed issue queues.
//
//     By defining the **final** micro-operation structure (`uop_t`), Physical
//     Memory Attributes (`pma_attr_t`), functional unit operation enums, and
//     stage-to-stage pipeline payload bundles here in M1:
//       - `decoder_rv32.sv`, `alu.sv`, `bru.sv`, `mul.sv`, `div.sv`,
//         `csr_unit.sv`, `agu.sv`, `pma.sv`, `misalign.sv`, `trap_ctrl.sv`, and
//         `perf_counters.sv` are written **once** in M1 and reused unmodified
//         in M4.
//       - Every physical pipeline stage boundary across the core adheres to the
//         project's standardized valid/ready/flush handshake contract:
//           * `in_ready_o = !valid_q || out_ready_i;`
//           * `step_en    = in_valid_i && in_ready_o;`
//           * Only `valid_q` is reset/flushed; payload structs (`fetch_pkt_t`,
//             `uop_t`, `ex_wb_t`) use `step_en` as a pure clock enable.
//
// Connections & Consumers:
//   - Imported by: `core.sv` and all child modules under `rtl/core/frontend/`,
//     `rtl/core/decode/`, `rtl/core/issue/`, `rtl/core/execute/`,
//     `rtl/core/lsu/`, `rtl/core/mem/`, and `rtl/core/commit/`, as well as
//     `tb_core.sv` and `tb_soc.sv` for retirement trace monitoring.
// =============================================================================

package core_pkg;

    import rv_pkg::*;

    // =========================================================================
    // 1. Core Sizing Parameters (Default / M1-M4 Scalable)
    // =========================================================================
    localparam int unsigned FETCH_WIDTH   = 1;  // 1 in M1, scales to 2 in M4
    localparam int unsigned ISSUE_PORTS   = 4;  // ALU0+BRU, ALU1, MEM, MULDIV/CSR (M4)
    localparam int unsigned N_PHYS_REGS   = 32; // 32 in M1 (architectural), 96 in M4 (OoO PRF)
    localparam int unsigned PRF_ADDR_W    = $clog2(N_PHYS_REGS);
    localparam int unsigned ROB_DEPTH     = 64; // Used in M4 ROB tags
    localparam int unsigned ROB_IDX_W     = $clog2(ROB_DEPTH);
    localparam int unsigned FETCH_Q_DEPTH = 4;  // Instruction fetch decoupling FIFO depth

    // =========================================================================
    // 2. Functional Unit & Operation Enums
    // =========================================================================
    // Target Execution Pipe selector
    typedef enum logic [2:0] {
        FU_NONE = 3'd0, // NOP / non-executing system op handled at commit
        FU_ALU  = 3'd1, // Single-cycle integer ALU (`alu.sv`)
        FU_BRU  = 3'd2, // Branch & jump resolution unit (`bru.sv`)
        FU_MUL  = 3'd3, // 3-stage pipelined multiplier (`mul.sv`)
        FU_DIV  = 3'd4, // 32-cycle iterative divider (`div.sv`)
        FU_LSU  = 3'd5, // Load-store unit (`lsu.sv`)
        FU_CSR  = 3'd6, // Control/status register unit (`csr_unit.sv`)
        FU_VEC  = 3'd7  // Post-commit vector unit (`vec_unit.sv`, M7)
    } fu_type_e;

    // Operand 1 mux selector (`alu.sv`)
    typedef enum logic [1:0] {
        OP1_RS1  = 2'd0, // Value from rs1 (PRF or bypass)
        OP1_PC   = 2'd1, // Instruction PC (`auipc`)
        OP1_ZERO = 2'd2  // Constant 32'd0 (`lui`)
    } op1_sel_e;

    // Operand 2 mux selector (`alu.sv`)
    typedef enum logic [1:0] {
        OP2_RS2  = 2'd0, // Value from rs2 (PRF or bypass)
        OP2_IMM  = 2'd1, // Sign-extended immediate from decoder
        OP2_FOUR = 2'd2  // Constant 32'd4
    } op2_sel_e;

    // Integer ALU operation (`alu.sv`)
    typedef enum logic [3:0] {
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_SLL  = 4'd2,
        ALU_SLT  = 4'd3,
        ALU_SLTU = 4'd4,
        ALU_XOR  = 4'd5,
        ALU_SRL  = 4'd6,
        ALU_SRA  = 4'd7,
        ALU_OR   = 4'd8,
        ALU_AND  = 4'd9
    } alu_op_e;

    // Branch / Jump operation (`bru.sv`)
    typedef enum logic [3:0] {
        BRU_BEQ  = 4'd0,
        BRU_BNE  = 4'd1,
        BRU_BLT  = 4'd2,
        BRU_BGE  = 4'd3,
        BRU_BLTU = 4'd4,
        BRU_BGEU = 4'd5,
        BRU_JAL  = 4'd6,
        BRU_JALR = 4'd7
    } bru_op_e;

    // Multiply operation (`mul.sv`)
    typedef enum logic [1:0] {
        MUL_LOWER  = 2'd0, // `mul`:    bits [31:0] of product
        MUL_HIGH   = 2'd1, // `mulh`:   bits [63:32] of signed × signed
        MUL_HIGHSU = 2'd2, // `mulhsu`: bits [63:32] of signed × unsigned
        MUL_HIGHU  = 2'd3  // `mulhu`:  bits [63:32] of unsigned × unsigned
    } mul_op_e;

    // Divide / Remainder operation (`div.sv`)
    typedef enum logic [1:0] {
        DIV_S = 2'd0, // `div`:  signed quotient
        DIV_U = 2'd1, // `divu`: unsigned quotient
        REM_S = 2'd2, // `rem`:  signed remainder
        REM_U = 2'd3  // `remu`: unsigned remainder
    } div_op_e;

    // Memory access size (`agu.sv`, `lsu.sv`, `misalign.sv`)
    typedef enum logic [1:0] {
        LSU_BYTE = 2'd0, // 8-bit  (lb, lbu, sb)
        LSU_HALF = 2'd1, // 16-bit (lh, lhu, sh)
        LSU_WORD = 2'd2  // 32-bit (lw, sw)
    } lsu_size_e;

    // CSR operation (`csr_unit.sv`)
    typedef enum logic [1:0] {
        CSR_RW = 2'd0, // Atomic Read/Write (`csrrw`, `csrrwi`)
        CSR_RS = 2'd1, // Atomic Read and Set Bits (`csrrs`, `csrrsi`)
        CSR_RC = 2'd2  // Atomic Read and Clear Bits (`csrrc`, `csrrci`)
    } csr_op_e;

    // =========================================================================
    // 3. Physical Memory Attributes (`pma.sv`)
    // =========================================================================
    typedef struct packed {
        logic is_mapped;     // 1 = Valid address region in `soc_pkg` map; 0 = Fault
        logic is_ram;        // 1 = Main memory (`0x8000_0000+`)
        logic is_rom;        // 1 = Boot ROM (`0x0000_1000`) or Flash XIP (`0x2000_0000`)
        logic is_mmio;       // 1 = CLINT, PLIC, or APB peripheral (`0x0200_0000..0x1FFF_FFFF`)
        logic is_cacheable;  // 1 = Eligible for L1/L2 caching (RAM, Boot ROM, Flash XIP)
        logic is_idempotent; // 1 = Safe for speculative access & hardware misaligned split
        logic is_readable;   // 1 = Load access permitted
        logic is_writable;   // 1 = Store access permitted (0 for Boot ROM & Flash XIP)
        logic is_executable; // 1 = Instruction fetch permitted (0 for MMIO)
    } pma_attr_t;

    // =========================================================================
    // 4. Standardized Stage-to-Stage Physical Pipeline Payloads
    // =========================================================================

    // Stage F -> Stage D payload (`frontend.sv` -> `decode.sv`)
    typedef struct packed {
        logic [31:0] pc;          // Fetch address of this instruction
        logic [31:0] insn;        // 32-bit raw instruction word
        logic        pred_taken;  // BPU predicted branch taken (0 in M1)
        logic [31:0] pred_target; // BPU predicted next PC (`pc + 4` in M1)
        logic        exc_valid;   // 1 = Fetch exception occurred (misaligned PC or PMA fault)
        exc_cause_e  exc_cause;   // `EXC_INSTR_ADDR_MISALIGNED` or `EXC_INSTR_ACCESS_FAULT`
    } fetch_pkt_t;

    // Stage D -> Stage I -> Stage X Unified Micro-Op (`uop_t`)
    // Produced by `decoder_rv32.sv` and carried through Issue and Execute.
    typedef struct packed {
        // Program location & raw instruction (for traps and Spike co-sim)
        logic [31:0]             pc;
        logic [31:0]             insn;

        // Branch prediction metadata carried to `bru.sv`
        logic                    pred_taken;
        logic [31:0]             pred_target;

        // Architectural register specifiers
        logic [REG_ADDR_W-1:0]   rs1_addr;
        logic [REG_ADDR_W-1:0]   rs2_addr;
        logic [REG_ADDR_W-1:0]   rd_addr;
        logic                    rs1_ren;    // 1 = Instruction reads architectural rs1
        logic                    rs2_ren;    // 1 = Instruction reads architectural rs2
        logic                    rd_wen;     // 1 = Instruction writes architectural rd (false if rd == x0)

        // Physical register & ROB tags (In M1: `prs1 == rs1_addr`, etc.; populated by `rename.sv` in M4)
        logic [PRF_ADDR_W-1:0]   prs1;
        logic [PRF_ADDR_W-1:0]   prs2;
        logic [PRF_ADDR_W-1:0]   prd;
        logic [ ROB_IDX_W-1:0]   rob_idx;

        // Decoded immediate & operand selection
        logic [31:0]             imm;
        op1_sel_e                op1_sel;
        op2_sel_e                op2_sel;

        // Functional unit routing & operation sub-codes
        fu_type_e                fu_type;
        alu_op_e                 alu_op;
        bru_op_e                 bru_op;
        mul_op_e                 mul_op;
        div_op_e                 div_op;

        // LSU control fields
        logic                    is_load;
        logic                    is_store;
        lsu_size_e               lsu_size;
        logic                    lsu_unsigned; // 1 = zero-extend (`lbu`, `lhu`), 0 = sign-extend

        // CSR & System / Serialize flags
        csr_op_e                 csr_op;
        logic                    csr_use_imm;  // 1 = use zero-extended `rs1_addr` as 5-bit zimm
        logic                    is_fence;     // `fence`
        logic                    is_fence_i;   // `fence.i` (flushes pipe & redirects to pc + 4 at commit)
        logic                    is_ecall;     // `ecall`
        logic                    is_ebreak;    // `ebreak`
        logic                    is_mret;      // `mret`
        logic                    is_wfi;       // `wfi`
        logic                    is_serializing; // Wait for older instructions to drain before issue

        // Precise exception state accumulated along the pipeline
        logic                    exc_valid;
        exc_cause_e              exc_cause;
        logic [31:0]             exc_tval;
    } uop_t;

    // Stage X -> Stage C Writeback / Completion Bundle (`ex_wb_t`)
    typedef struct packed {
        uop_t                    uop;          // Original micro-op metadata
        logic [31:0]             rd_wdata;     // Computed result for `rd` (ALU/BRU/MUL/DIV/LSU/CSR)
        logic                    csr_wen;      // 1 = Commit should perform CSR write/update
        logic [CSR_ADDR_W-1:0]   csr_addr;     // Target CSR address (`uop.imm[11:0]`)
        logic [31:0]             csr_wdata;    // New CSR value to commit
        logic                    mem_valid;    // 1 = Instruction performed a load or store (for co-sim trace)
        logic [31:0]             mem_addr;     // Effective byte address of load/store
        logic [31:0]             mem_wdata;    // Store data written (for co-sim trace)
        logic [3:0]              mem_wstrb;    // Store byte mask
    } ex_wb_t;

    // Architectural Retirement Trace Bundle (`commit_trace_t`)
    // Driven by `commit.sv` and exported by `core.sv` to the Verilator/Spike
    // lockstep co-simulation harness (`cosim_dpi.cpp` / `tb_core.sv` / `tb_soc.sv`).
    typedef struct packed {
        logic                    valid;        // 1 = An instruction retired or trapped on this cycle
        logic [31:0]             pc;           // Retired instruction PC
        logic [31:0]             insn;         // Retired 32-bit instruction encoding
        logic                    rd_wen;       // 1 = Architectural register write occurred
        logic [REG_ADDR_W-1:0]   rd_addr;      // Architectural destination register (x1..x31)
        logic [31:0]             rd_wdata;     // Value written to `rd_addr`
        logic                    mem_valid;    // 1 = Retired instruction accessed memory
        logic                    mem_is_store; // 1 = Store, 0 = Load
        logic [31:0]             mem_addr;     // Effective memory address
        logic [31:0]             mem_wdata;    // Store data
        logic                    trap_taken;   // 1 = Synchronous exception or interrupt taken
        logic                    trap_is_irq;  // 1 = Asynchronous interrupt, 0 = Exception
        logic [3:0]              trap_cause;   // Cause code written to `mcause`
    } commit_trace_t;

    // =========================================================================
    // 5. Optional Debug & Verification Inspection Bundles (`HAS_DEBUG`)
    // =========================================================================
    // Used by `debug_module.sv` -> `debug_ctrl.sv` (and by the simulation test
    // harness in `tb_core.sv` / `sim/unit/tb_isa_*.sv`) to inspect or modify
    // architectural GPRs (`prf.sv`) and CSRs (`csr_unit.sv`). When
    // `HAS_DEBUG == 1'b0`, all logic and ports handling these bundles are
    // tied off and stripped from synthesis.
    typedef struct packed {
        logic        valid;  // 1 = Debug/harness register access request active
        logic        write;  // 1 = Write register, 0 = Read register
        logic        is_csr; // 1 = Target is CSR (addr[11:0]), 0 = Target is GPR (addr[4:0])
        logic [11:0] addr;   // CSR address (12-bit) or GPR index ({7'b0, reg_idx[4:0]})
        logic [31:0] wdata;  // 32-bit data to write when `write == 1'b1`
    } dbg_reg_req_t;

    typedef struct packed {
        logic        ready;  // 1 = Request completed, `rdata` / `err` valid
        logic [31:0] rdata;  // 32-bit value read from `prf.sv` or `csr_unit.sv`
        logic        err;    // 1 = Unimplemented CSR or illegal debug access
    } dbg_reg_rsp_t;

endpackage : core_pkg

