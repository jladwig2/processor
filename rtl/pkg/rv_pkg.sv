`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/pkg/rv_pkg.sv
// Package:     rv_pkg
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Architectural RISC-V ISA definitions package (Unprivileged & Machine-Mode
//   Privileged Specification). This package is the single source of truth for
//   architectural bit encodings required to decode and execute:
//     - RV32I Base Integer Instruction Set (40 instructions)
//     - RV32M Integer Multiply/Divide Extension (8 instructions)
//     - Zicsr Control and Status Register Extension (6 instructions)
//     - Zifencei Instruction-Fetch Fence Extension (`fence.i`)
//     - Zicntr Base Counters (`cycle`, `time`, `instret` + `h` upper halves)
//     - Machine-Mode Privileged Instructions (`ecall`, `ebreak`, `mret`, `wfi`)
//
//   Why This Package Exists:
//     Keeping architectural ISA constants (`OPCODE_*`, `FUNCT3_*`, `CSR_*`,
//     `EXC_*`) strictly separated from microarchitectural pipeline structures
//     (`core_pkg.sv`) ensures that instruction decoders, CSR units, trap
//     controllers, and co-simulation monitors all share identical, readable
//     symbolic constants without circular package dependencies.
//
// Connections & Consumers:
//   - Imported by:
//       * `core_pkg.sv` (`rtl/pkg/core_pkg.sv`)
//       * `decoder_rv32.sv` (`rtl/core/decode/decoder_rv32.sv`)
//       * `csr_unit.sv` (`rtl/core/execute/csr_unit.sv`)
//       * `trap_ctrl.sv` (`rtl/core/commit/trap_ctrl.sv`)
//       * `perf_counters.sv` (`rtl/core/commit/perf_counters.sv`)
// =============================================================================

package rv_pkg;

    // =========================================================================
    // 1. Architectural Widths & Constants
    // =========================================================================
    localparam int unsigned XLEN        = 32;
    localparam int unsigned ILEN        = 32;
    localparam int unsigned N_ARCH_REGS = 32;
    localparam int unsigned REG_ADDR_W  = $clog2(N_ARCH_REGS); // 5 bits
    localparam int unsigned CSR_ADDR_W  = 12;

    // Canonical NOP instruction: `addi x0, x0, 0`
    localparam logic [31:0] INSN_NOP    = 32'h0000_0013;

    // Privilege levels (M-mode only in M1..M8; U-mode reserved)
    typedef enum logic [1:0] {
        PRIV_U = 2'b00,
        PRIV_S = 2'b01,
        PRIV_M = 2'b11
    } priv_lvl_e;

    // =========================================================================
    // 2. Major Base Opcodes (inst[6:0])
    // =========================================================================
    typedef enum logic [6:0] {
        OPCODE_LOAD     = 7'b0000011, // lb, lh, lw, lbu, lhu
        OPCODE_MISC_MEM = 7'b0001111, // fence, fence.i
        OPCODE_OP_IMM   = 7'b0010011, // addi, slti, sltiu, xori, ori, andi, slli, srli, srai
        OPCODE_AUIPC    = 7'b0010111, // auipc
        OPCODE_STORE    = 7'b0100011, // sb, sh, sw
        OPCODE_AMO      = 7'b0101111, // lr.w, sc.w, amoswap.w, ... (M6)
        OPCODE_OP       = 7'b0110011, // R-type ALU + RV32M (funct7 == 7'b0000001)
        OPCODE_LUI      = 7'b0110111, // lui
        OPCODE_OP_V     = 7'b1010111, // RVV vector arithmetic/config (M7)
        OPCODE_BRANCH   = 7'b1100011, // beq, bne, blt, bge, bltu, bgeu
        OPCODE_JALR     = 7'b1100111, // jalr
        OPCODE_JAL      = 7'b1101111, // jal
        OPCODE_SYSTEM   = 7'b1110011  // ecall, ebreak, mret, wfi, csrrw/s/c[i]
    } rv_opcode_e;

    // =========================================================================
    // 3. Funct3 / Funct7 Sub-fields
    // =========================================================================
    // ALU / OP-IMM / OP funct3 (inst[14:12])
    localparam logic [2:0] F3_ADD_SUB = 3'b000;
    localparam logic [2:0] F3_SLL     = 3'b001;
    localparam logic [2:0] F3_SLT     = 3'b010;
    localparam logic [2:0] F3_SLTU    = 3'b011;
    localparam logic [2:0] F3_XOR     = 3'b100;
    localparam logic [2:0] F3_SRL_SRA = 3'b101;
    localparam logic [2:0] F3_OR      = 3'b110;
    localparam logic [2:0] F3_AND     = 3'b111;

    // RV32M funct3 (inst[14:12] when opcode == OPCODE_OP and funct7 == F7_MULDIV)
    localparam logic [6:0] F7_BASE    = 7'b0000000;
    localparam logic [6:0] F7_SUB_SRA = 7'b0100000;
    localparam logic [6:0] F7_MULDIV  = 7'b0000001;

    localparam logic [2:0] F3_MUL     = 3'b000;
    localparam logic [2:0] F3_MULH    = 3'b001;
    localparam logic [2:0] F3_MULHSU  = 3'b010;
    localparam logic [2:0] F3_MULHU   = 3'b011;
    localparam logic [2:0] F3_DIV     = 3'b100;
    localparam logic [2:0] F3_DIVU    = 3'b101;
    localparam logic [2:0] F3_REM     = 3'b110;
    localparam logic [2:0] F3_REMU    = 3'b111;

    // Branch funct3 (inst[14:12])
    localparam logic [2:0] F3_BEQ     = 3'b000;
    localparam logic [2:0] F3_BNE     = 3'b001;
    localparam logic [2:0] F3_BLT     = 3'b100;
    localparam logic [2:0] F3_BGE     = 3'b101;
    localparam logic [2:0] F3_BLTU    = 3'b110;
    localparam logic [2:0] F3_BGEU    = 3'b111;

    // Load / Store funct3 (inst[14:12])
    localparam logic [2:0] F3_LB_SB   = 3'b000;
    localparam logic [2:0] F3_LH_SH   = 3'b001;
    localparam logic [2:0] F3_LW_SW   = 3'b010;
    localparam logic [2:0] F3_LBU     = 3'b100;
    localparam logic [2:0] F3_LHU     = 3'b101;

    // MISC-MEM funct3 (inst[14:12])
    localparam logic [2:0] F3_FENCE   = 3'b000;
    localparam logic [2:0] F3_FENCE_I = 3'b001;

    // SYSTEM / Zicsr funct3 (inst[14:12])
    localparam logic [2:0] F3_PRIV    = 3'b000; // ecall, ebreak, mret, wfi
    localparam logic [2:0] F3_CSRRW   = 3'b001;
    localparam logic [2:0] F3_CSRRS   = 3'b010;
    localparam logic [2:0] F3_CSRRC   = 3'b011;
    localparam logic [2:0] F3_CSRRWI  = 3'b101;
    localparam logic [2:0] F3_CSRRSI  = 3'b110;
    localparam logic [2:0] F3_CSRRCI  = 3'b111;

    // SYSTEM funct12 (inst[31:20] when funct3 == F3_PRIV)
    localparam logic [11:0] F12_ECALL  = 12'h000;
    localparam logic [11:0] F12_EBREAK = 12'h001;
    localparam logic [11:0] F12_WFI    = 12'h105;
    localparam logic [11:0] F12_MRET   = 12'h302;
    localparam logic [11:0] F12_DRET   = 12'h7B2; // Debug return (M4)

    // =========================================================================
    // 4. CSR Addresses (inst[31:20])
    // =========================================================================
    typedef enum logic [11:0] {
        // Unprivileged Read-Only Counters (Zicntr)
        CSR_CYCLE        = 12'hC00,
        CSR_TIME         = 12'hC01,
        CSR_INSTRET      = 12'hC02,
        CSR_CYCLEH       = 12'hC80,
        CSR_TIMEH        = 12'hC81,
        CSR_INSTRETH     = 12'hC82,

        // Machine Information Registers (MRO)
        CSR_MVENDORID    = 12'hF11,
        CSR_MARCHID      = 12'hF12,
        CSR_MIMPID       = 12'hF13,
        CSR_MHARTID      = 12'hF14,

        // Machine Trap Setup (MRW)
        CSR_MSTATUS      = 12'h300,
        CSR_MISA         = 12'h301,
        CSR_MIE          = 12'h304,
        CSR_MTVEC        = 12'h305,
        CSR_MCOUNTEREN   = 12'h306,

        // Machine Trap Handling (MRW)
        CSR_MSCRATCH     = 12'h340,
        CSR_MEPC         = 12'h341,
        CSR_MCAUSE       = 12'h342,
        CSR_MTVAL        = 12'h343,
        CSR_MIP          = 12'h344,

        // Machine Counter/Timers (MRW)
        CSR_MCYCLE       = 12'hB00,
        CSR_MINSTRET     = 12'hB02,
        CSR_MCYCLEH      = 12'hB80,
        CSR_MINSTRETH    = 12'hB82,
        CSR_MCOUNTINHIBIT = 12'h320
    } csr_addr_e;

    // mstatus bit positions
    localparam int unsigned MSTATUS_MIE_BIT  = 3;
    localparam int unsigned MSTATUS_MPIE_BIT = 7;
    localparam int unsigned MSTATUS_MPP_LO   = 11;
    localparam int unsigned MSTATUS_MPP_HI   = 12;

    // mie / mip bit positions
    localparam int unsigned MIE_MSIE_BIT     = 3;  // Machine Software Interrupt
    localparam int unsigned MIE_MTIE_BIT     = 7;  // Machine Timer Interrupt
    localparam int unsigned MIE_MEIE_BIT     = 11; // Machine External Interrupt

    // =========================================================================
    // 5. Synchronous Exception & Asynchronous Interrupt Cause Codes (`mcause`)
    // =========================================================================
    // In `mcause`, bit [31] is 1 for asynchronous interrupts and 0 for
    // synchronous exceptions. Bits [3:0] encode the cause index below.
    typedef enum logic [3:0] {
        EXC_INSTR_ADDR_MISALIGNED = 4'd0,
        EXC_INSTR_ACCESS_FAULT    = 4'd1,
        EXC_ILLEGAL_INSTR         = 4'd2,
        EXC_BREAKPOINT            = 4'd3,
        EXC_LOAD_ADDR_MISALIGNED  = 4'd4,
        EXC_LOAD_ACCESS_FAULT     = 4'd5,
        EXC_STORE_ADDR_MISALIGNED = 4'd6,
        EXC_STORE_ACCESS_FAULT    = 4'd7,
        EXC_ECALL_U               = 4'd8,
        EXC_ECALL_S               = 4'd9,
        EXC_ECALL_M               = 4'd11
    } exc_cause_e;

    localparam logic [3:0] IRQ_CAUSE_M_SOFT  = 4'd3;
    localparam logic [3:0] IRQ_CAUSE_M_TIMER = 4'd7;
    localparam logic [3:0] IRQ_CAUSE_M_EXT   = 4'd11;

endpackage : rv_pkg

