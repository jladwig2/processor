`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/core/decode/decoder_rv32.sv
// Module:      decoder_rv32
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Purely combinational single-instruction RISC-V 32-bit decoder. Translates
//   a fetched instruction packet (`fetch_pkt_t`) into the unified micro-op
//   structure (`uop_t` defined in `core_pkg.sv`).
//
//   Why This Module Exists & Reusability Across Milestones:
//     - In M1 (1-wide in-order), `decode.sv` instantiates one `decoder_rv32`.
//     - In M4 (2-wide superscalar OoO), `decode.sv` instantiates two parallel
//       `decoder_rv32` instances (`u_dec0`, `u_dec1`) with zero modifications
//       to this module.
//     - Feature parameter `HAS_MULDIV` allows synthesizing the core with or
//       without the `M` extension; if `HAS_MULDIV == 0`, `M` encodings raise
//       `EXC_ILLEGAL_INSTR` (`mcause = 2`).
//
//   Supported Instruction Classes (57 Instructions in M1):
//     1. `OPCODE_LUI` (`7'b0110111`):
//        - `fu_type = FU_ALU`, `alu_op = ALU_ADD`, `op1_sel = OP1_ZERO`,
//          `op2_sel = OP2_IMM`, `imm = imm_u`, `rd_wen = (rd != 0)`.
//     2. `OPCODE_AUIPC` (`7'b0010111`):
//        - `fu_type = FU_ALU`, `alu_op = ALU_ADD`, `op1_sel = OP1_PC`,
//          `op2_sel = OP2_IMM`, `imm = imm_u`, `rd_wen = (rd != 0)`.
//     3. `OPCODE_JAL` (`7'b1101111`):
//        - `fu_type = FU_BRU`, `bru_op = BRU_JAL`, `imm = imm_j`,
//          `rd_wen = (rd != 0)`.
//     4. `OPCODE_JALR` (`7'b1100111`, requires `funct3 == 3'b000`):
//        - `fu_type = FU_BRU`, `bru_op = BRU_JALR`, `rs1_ren = 1`,
//          `imm = imm_i`, `rd_wen = (rd != 0)`.
//     5. `OPCODE_BRANCH` (`7'b1100011`, `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`):
//        - `fu_type = FU_BRU`, `rs1_ren = 1`, `rs2_ren = 1`, `imm = imm_b`,
//          `rd_wen = 0`. Reserved `funct3` (`3'b010`, `3'b011`) -> illegal!
//     6. `OPCODE_LOAD` (`7'b0000011`, `lb`, `lh`, `lw`, `lbu`, `lhu`):
//        - `fu_type = FU_LSU`, `is_load = 1`, `rs1_ren = 1`, `imm = imm_i`,
//          `rd_wen = (rd != 0)`, `lsu_size`, `lsu_unsigned`.
//     7. `OPCODE_STORE` (`7'b0100011`, `sb`, `sh`, `sw`):
//        - `fu_type = FU_LSU`, `is_store = 1`, `rs1_ren = 1`, `rs2_ren = 1`,
//          `imm = imm_s`, `rd_wen = 0`, `lsu_size`.
//     8. `OPCODE_OP_IMM` (`7'b0010011`, `addi`..`andi`, `slli`, `srli`, `srai`):
//        - `fu_type = FU_ALU`, `op1_sel = OP1_RS1`, `op2_sel = OP2_IMM`,
//          `rs1_ren = 1`, `imm = imm_i`, `rd_wen = (rd != 0)`.
//        - Shift immediates (`slli`, `srli`, `srai`) must validate `funct7`:
//          `slli` requires `funct7 == 7'b0000000`; `srli`/`srai` require
//          `funct7 == 7'b0000000` or `7'b0100000`; otherwise raise
//          `EXC_ILLEGAL_INSTR`!
//     9. `OPCODE_OP` (`7'b0110011`):
//        - If `funct7 == F7_BASE (7'b0000000)` or `F7_SUB_SRA (7'b0100000)`
//          (only valid for `sub` and `sra`): `fu_type = FU_ALU`, `op1_sel =
//          OP1_RS1`, `op2_sel = OP2_RS2`, `rs1_ren = 1`, `rs2_ren = 1`,
//          `rd_wen = (rd != 0)`.
//        - If `funct7 == F7_MULDIV (7'b0000001)` and `HAS_MULDIV == 1`:
//            * `funct3[2] == 1'b0` (`mul`, `mulh`, `mulhsu`, `mulhu`):
//              `fu_type = FU_MUL`, `mul_op = mul_op_e'(funct3[1:0])`.
//            * `funct3[2] == 1'b1` (`div`, `divu`, `rem`, `remu`):
//              `fu_type = FU_DIV`, `div_op = div_op_e'(funct3[1:0])`.
//    10. `OPCODE_MISC_MEM` (`7'b0001111`):
//        - `F3_FENCE (3'b000)`:   `fu_type = FU_NONE`, `is_fence = 1`.
//        - `F3_FENCE_I (3'b001)`: `fu_type = FU_NONE`, `is_fence_i = 1`,
//          `is_serializing = 1`.
//    11. `OPCODE_SYSTEM` (`7'b1110011`):
//        - `funct3 == F3_PRIV (3'b000)` (requires `rs1 == 0` and `rd == 0`):
//            * `funct12 == F12_ECALL`:  `exc_valid = 1`, `exc_cause = EXC_ECALL_M`,
//              `is_ecall = 1`, `is_serializing = 1`.
//            * `funct12 == F12_EBREAK`: `exc_valid = 1`, `exc_cause = EXC_BREAKPOINT`,
//              `exc_tval = pc`, `is_ebreak = 1`, `is_serializing = 1`.
//            * `funct12 == F12_MRET`:   `is_mret = 1`, `is_serializing = 1`.
//            * `funct12 == F12_WFI`:    `is_wfi = 1`, `is_serializing = 1`.
//        - `funct3 != 3'b000` and `funct3 != 3'b100` (`csrrw/s/c[i]`):
//            * `fu_type = FU_CSR`, `is_serializing = 1`, `imm = {20'b0, inst[31:20]}`,
//              `csr_use_imm = funct3[2]`, `rs1_ren = !funct3[2]`,
//              `rd_wen = (rd != 0)`.
//    12. Exception Propagation Priority:
//        - If `pkt_i.exc_valid` is already set by `frontend.sv` (instruction
//          address misaligned or instruction access fault), preserve
//          `pkt_i.exc_cause` and set `exc_tval = pkt_i.pc`.
//        - Else if instruction encoding is unrecognized/reserved, set
//          `uop_o.exc_valid = 1'b1`, `uop_o.exc_cause = EXC_ILLEGAL_INSTR`,
//          and `uop_o.exc_tval = pkt_i.insn`.
//
// Connections:
//   - Instantiated by: `decode.sv` (`u_decoder_rv32`).
//   - Inputs:  `pkt_i` (`fetch_pkt_t` from `decode.sv`)
//   - Outputs: `uop_o` (`uop_t` to `decode.sv` pipeline register)
// =============================================================================

module decoder_rv32
    import rv_pkg::*;
    import core_pkg::*;
#(
    parameter bit HAS_MULDIV = 1'b1
) (
    input  fetch_pkt_t pkt_i,
    output uop_t       uop_o
);

    // -------------------------------------------------------------------------
    // 1. Instruction Bitfield Extraction
    // -------------------------------------------------------------------------
    wire [6:0]  opcode  = pkt_i.insn[6:0];
    wire [4:0]  rd      = pkt_i.insn[11:7];
    wire [2:0]  funct3  = pkt_i.insn[14:12];
    wire [4:0]  rs1     = pkt_i.insn[19:15];
    wire [4:0]  rs2     = pkt_i.insn[24:20];
    wire [6:0]  funct7  = pkt_i.insn[31:25];
    wire [11:0] funct12 = pkt_i.insn[31:20];

    // -------------------------------------------------------------------------
    // 2. Immediate Formats (Sign- and Zero-Extended)
    // -------------------------------------------------------------------------
    wire [31:0] imm_i    = {{20{pkt_i.insn[31]}}, pkt_i.insn[31:20]};
    wire [31:0] imm_s    = {{20{pkt_i.insn[31]}}, pkt_i.insn[31:25], pkt_i.insn[11:7]};
    wire [31:0] imm_b    = {{19{pkt_i.insn[31]}}, pkt_i.insn[31], pkt_i.insn[7], pkt_i.insn[30:25], pkt_i.insn[11:8], 1'b0};
    wire [31:0] imm_u    = {pkt_i.insn[31:12], 12'b0};
    wire [31:0] imm_j    = {{11{pkt_i.insn[31]}}, pkt_i.insn[31], pkt_i.insn[19:12], pkt_i.insn[20], pkt_i.insn[30:21], 1'b0};
    wire [31:0] csr_addr = {20'b0, funct12};

    // -------------------------------------------------------------------------
    // 3. Combinational Micro-Op Decoding
    // -------------------------------------------------------------------------
    always_comb begin
        // Default safe values for all uop_t fields
        uop_o.pc             = pkt_i.pc;
        uop_o.insn           = pkt_i.insn;
        uop_o.pred_taken     = pkt_i.pred_taken;
        uop_o.pred_target    = pkt_i.pred_target;
        uop_o.rs1_addr       = rs1;
        uop_o.rs2_addr       = rs2;
        uop_o.rd_addr        = rd;
        uop_o.rs1_ren        = 1'b0;
        uop_o.rs2_ren        = 1'b0;
        uop_o.rd_wen         = 1'b0;
        uop_o.prs1           = {{(PRF_ADDR_W - REG_ADDR_W){1'b0}}, rs1};
        uop_o.prs2           = {{(PRF_ADDR_W - REG_ADDR_W){1'b0}}, rs2};
        uop_o.prd            = {{(PRF_ADDR_W - REG_ADDR_W){1'b0}}, rd};
        uop_o.rob_idx        = '0;
        uop_o.imm            = '0;
        uop_o.op1_sel        = OP1_RS1;
        uop_o.op2_sel        = OP2_RS2;
        uop_o.fu_type        = FU_NONE;
        uop_o.alu_op         = ALU_ADD;
        uop_o.bru_op         = BRU_BEQ;
        uop_o.mul_op         = MUL_LOWER;
        uop_o.div_op         = DIV_S;
        uop_o.is_load        = 1'b0;
        uop_o.is_store       = 1'b0;
        uop_o.lsu_size       = LSU_WORD;
        uop_o.lsu_unsigned   = 1'b0;
        uop_o.csr_op         = CSR_RW;
        uop_o.csr_use_imm    = 1'b0;
        uop_o.is_fence       = 1'b0;
        uop_o.is_fence_i     = 1'b0;
        uop_o.is_ecall       = 1'b0;
        uop_o.is_ebreak      = 1'b0;
        uop_o.is_mret        = 1'b0;
        uop_o.is_wfi         = 1'b0;
        uop_o.is_serializing = 1'b0;
        uop_o.exc_valid      = 1'b0;
        uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
        uop_o.exc_tval       = '0;

        // Fetch exception takes precedence over decoding
        if (pkt_i.exc_valid) begin
            uop_o.exc_valid      = 1'b1;
            uop_o.exc_cause      = pkt_i.exc_cause;
            uop_o.exc_tval       = pkt_i.pc;
            uop_o.is_serializing = 1'b1;
        end else begin
            case (opcode)
                // -------------------------------------------------------------
                // RV32I Upper Immediate
                // -------------------------------------------------------------
                OPCODE_LUI: begin
                    uop_o.fu_type = FU_ALU;
                    uop_o.alu_op  = ALU_ADD;
                    uop_o.op1_sel = OP1_ZERO;
                    uop_o.op2_sel = OP2_IMM;
                    uop_o.imm     = imm_u;
                    uop_o.rd_wen  = (rd != 5'd0);
                end

                OPCODE_AUIPC: begin
                    uop_o.fu_type = FU_ALU;
                    uop_o.alu_op  = ALU_ADD;
                    uop_o.op1_sel = OP1_PC;
                    uop_o.op2_sel = OP2_IMM;
                    uop_o.imm     = imm_u;
                    uop_o.rd_wen  = (rd != 5'd0);
                end

                // -------------------------------------------------------------
                // RV32I Jumps
                // -------------------------------------------------------------
                OPCODE_JAL: begin
                    uop_o.fu_type = FU_BRU;
                    uop_o.bru_op  = BRU_JAL;
                    uop_o.imm     = imm_j;
                    uop_o.rd_wen  = (rd != 5'd0);
                end

                OPCODE_JALR: begin
                    if (funct3 == 3'b000) begin
                        uop_o.fu_type = FU_BRU;
                        uop_o.bru_op  = BRU_JALR;
                        uop_o.rs1_ren = 1'b1;
                        uop_o.imm     = imm_i;
                        uop_o.rd_wen  = (rd != 5'd0);
                    end else begin
                        uop_o.exc_valid      = 1'b1;
                        uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                        uop_o.exc_tval       = pkt_i.insn;
                        uop_o.is_serializing = 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // RV32I Branches
                // -------------------------------------------------------------
                OPCODE_BRANCH: begin
                    uop_o.fu_type = FU_BRU;
                    uop_o.rs1_ren = 1'b1;
                    uop_o.rs2_ren = 1'b1;
                    uop_o.imm     = imm_b;
                    uop_o.rd_wen  = 1'b0;
                    case (funct3)
                        F3_BEQ:  uop_o.bru_op = BRU_BEQ;
                        F3_BNE:  uop_o.bru_op = BRU_BNE;
                        F3_BLT:  uop_o.bru_op = BRU_BLT;
                        F3_BGE:  uop_o.bru_op = BRU_BGE;
                        F3_BLTU: uop_o.bru_op = BRU_BLTU;
                        F3_BGEU: uop_o.bru_op = BRU_BGEU;
                        default: begin
                            uop_o.exc_valid      = 1'b1;
                            uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                            uop_o.exc_tval       = pkt_i.insn;
                            uop_o.is_serializing = 1'b1;
                        end
                    endcase
                end

                // -------------------------------------------------------------
                // RV32I Loads
                // -------------------------------------------------------------
                OPCODE_LOAD: begin
                    uop_o.fu_type = FU_LSU;
                    uop_o.is_load = 1'b1;
                    uop_o.rs1_ren = 1'b1;
                    uop_o.imm     = imm_i;
                    uop_o.rd_wen  = (rd != 5'd0);
                    case (funct3)
                        F3_LB_SB: begin uop_o.lsu_size = LSU_BYTE; uop_o.lsu_unsigned = 1'b0; end
                        F3_LH_SH: begin uop_o.lsu_size = LSU_HALF; uop_o.lsu_unsigned = 1'b0; end
                        F3_LW_SW: begin uop_o.lsu_size = LSU_WORD; uop_o.lsu_unsigned = 1'b0; end
                        F3_LBU:   begin uop_o.lsu_size = LSU_BYTE; uop_o.lsu_unsigned = 1'b1; end
                        F3_LHU:   begin uop_o.lsu_size = LSU_HALF; uop_o.lsu_unsigned = 1'b1; end
                        default: begin
                            uop_o.exc_valid      = 1'b1;
                            uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                            uop_o.exc_tval       = pkt_i.insn;
                            uop_o.is_serializing = 1'b1;
                        end
                    endcase
                end

                // -------------------------------------------------------------
                // RV32I Stores
                // -------------------------------------------------------------
                OPCODE_STORE: begin
                    uop_o.fu_type  = FU_LSU;
                    uop_o.is_store = 1'b1;
                    uop_o.rs1_ren  = 1'b1;
                    uop_o.rs2_ren  = 1'b1;
                    uop_o.imm      = imm_s;
                    uop_o.rd_wen   = 1'b0;
                    case (funct3)
                        F3_LB_SB: uop_o.lsu_size = LSU_BYTE;
                        F3_LH_SH: uop_o.lsu_size = LSU_HALF;
                        F3_LW_SW: uop_o.lsu_size = LSU_WORD;
                        default: begin
                            uop_o.exc_valid      = 1'b1;
                            uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                            uop_o.exc_tval       = pkt_i.insn;
                            uop_o.is_serializing = 1'b1;
                        end
                    endcase
                end

                // -------------------------------------------------------------
                // RV32I Arithmetic & Logical Immediates
                // -------------------------------------------------------------
                OPCODE_OP_IMM: begin
                    uop_o.fu_type = FU_ALU;
                    uop_o.op1_sel = OP1_RS1;
                    uop_o.op2_sel = OP2_IMM;
                    uop_o.rs1_ren = 1'b1;
                    uop_o.imm     = imm_i;
                    uop_o.rd_wen  = (rd != 5'd0);
                    case (funct3)
                        F3_ADD_SUB: uop_o.alu_op = ALU_ADD;
                        F3_SLL: begin
                            if (funct7 == F7_BASE) begin
                                uop_o.alu_op = ALU_SLL;
                            end else begin
                                uop_o.exc_valid      = 1'b1;
                                uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                                uop_o.exc_tval       = pkt_i.insn;
                                uop_o.is_serializing = 1'b1;
                            end
                        end
                        F3_SLT:     uop_o.alu_op = ALU_SLT;
                        F3_SLTU:    uop_o.alu_op = ALU_SLTU;
                        F3_XOR:     uop_o.alu_op = ALU_XOR;
                        F3_SRL_SRA: begin
                            if (funct7 == F7_BASE) begin
                                uop_o.alu_op = ALU_SRL;
                            end else if (funct7 == F7_SUB_SRA) begin
                                uop_o.alu_op = ALU_SRA;
                            end else begin
                                uop_o.exc_valid      = 1'b1;
                                uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                                uop_o.exc_tval       = pkt_i.insn;
                                uop_o.is_serializing = 1'b1;
                            end
                        end
                        F3_OR:      uop_o.alu_op = ALU_OR;
                        F3_AND:     uop_o.alu_op = ALU_AND;
                    endcase
                end

                // -------------------------------------------------------------
                // RV32I / RV32M Register-Register Operations
                // -------------------------------------------------------------
                OPCODE_OP: begin
                    uop_o.rs1_ren = 1'b1;
                    uop_o.rs2_ren = 1'b1;
                    uop_o.rd_wen  = (rd != 5'd0);
                    case (funct7)
                        F7_BASE: begin
                            uop_o.fu_type = FU_ALU;
                            uop_o.op1_sel = OP1_RS1;
                            uop_o.op2_sel = OP2_RS2;
                            case (funct3)
                                F3_ADD_SUB: uop_o.alu_op = ALU_ADD;
                                F3_SLL:     uop_o.alu_op = ALU_SLL;
                                F3_SLT:     uop_o.alu_op = ALU_SLT;
                                F3_SLTU:    uop_o.alu_op = ALU_SLTU;
                                F3_XOR:     uop_o.alu_op = ALU_XOR;
                                F3_SRL_SRA: uop_o.alu_op = ALU_SRL;
                                F3_OR:      uop_o.alu_op = ALU_OR;
                                F3_AND:     uop_o.alu_op = ALU_AND;
                            endcase
                        end
                        F7_SUB_SRA: begin
                            uop_o.fu_type = FU_ALU;
                            uop_o.op1_sel = OP1_RS1;
                            uop_o.op2_sel = OP2_RS2;
                            case (funct3)
                                F3_ADD_SUB: uop_o.alu_op = ALU_SUB;
                                F3_SRL_SRA: uop_o.alu_op = ALU_SRA;
                                default: begin
                                    uop_o.exc_valid      = 1'b1;
                                    uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                                    uop_o.exc_tval       = pkt_i.insn;
                                    uop_o.is_serializing = 1'b1;
                                end
                            endcase
                        end
                        F7_MULDIV: begin
                            if (HAS_MULDIV) begin
                                case (funct3)
                                    F3_MUL:    begin uop_o.fu_type = FU_MUL; uop_o.mul_op = MUL_LOWER;  end
                                    F3_MULH:   begin uop_o.fu_type = FU_MUL; uop_o.mul_op = MUL_HIGH;   end
                                    F3_MULHSU: begin uop_o.fu_type = FU_MUL; uop_o.mul_op = MUL_HIGHSU; end
                                    F3_MULHU:  begin uop_o.fu_type = FU_MUL; uop_o.mul_op = MUL_HIGHU;  end
                                    F3_DIV:    begin uop_o.fu_type = FU_DIV; uop_o.div_op = DIV_S;      end
                                    F3_DIVU:   begin uop_o.fu_type = FU_DIV; uop_o.div_op = DIV_U;      end
                                    F3_REM:    begin uop_o.fu_type = FU_DIV; uop_o.div_op = REM_S;      end
                                    F3_REMU:   begin uop_o.fu_type = FU_DIV; uop_o.div_op = REM_U;      end
                                endcase
                            end else begin
                                uop_o.exc_valid      = 1'b1;
                                uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                                uop_o.exc_tval       = pkt_i.insn;
                                uop_o.is_serializing = 1'b1;
                            end
                        end
                        default: begin
                            uop_o.exc_valid      = 1'b1;
                            uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                            uop_o.exc_tval       = pkt_i.insn;
                            uop_o.is_serializing = 1'b1;
                        end
                    endcase
                end

                // -------------------------------------------------------------
                // Memory Fences (fence, fence.i)
                // -------------------------------------------------------------
                OPCODE_MISC_MEM: begin
                    case (funct3)
                        F3_FENCE: begin
                            uop_o.fu_type  = FU_NONE;
                            uop_o.is_fence = 1'b1;
                        end
                        F3_FENCE_I: begin
                            uop_o.fu_type        = FU_NONE;
                            uop_o.is_fence_i     = 1'b1;
                            uop_o.is_serializing = 1'b1;
                        end
                        default: begin
                            uop_o.exc_valid      = 1'b1;
                            uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                            uop_o.exc_tval       = pkt_i.insn;
                            uop_o.is_serializing = 1'b1;
                        end
                    endcase
                end

                // -------------------------------------------------------------
                // SYSTEM / Zicsr / Privileged Traps
                // -------------------------------------------------------------
                OPCODE_SYSTEM: begin
                    case (funct3)
                        F3_PRIV: begin
                            if (rs1 == 5'd0 && rd == 5'd0) begin
                                case (funct12)
                                    F12_ECALL: begin
                                        uop_o.is_ecall       = 1'b1;
                                        uop_o.is_serializing = 1'b1;
                                        uop_o.exc_valid      = 1'b1;
                                        uop_o.exc_cause      = EXC_ECALL_M;
                                        uop_o.exc_tval       = 32'h0;
                                    end
                                    F12_EBREAK: begin
                                        uop_o.is_ebreak      = 1'b1;
                                        uop_o.is_serializing = 1'b1;
                                        uop_o.exc_valid      = 1'b1;
                                        uop_o.exc_cause      = EXC_BREAKPOINT;
                                        uop_o.exc_tval       = pkt_i.pc;
                                    end
                                    F12_MRET: begin
                                        uop_o.is_mret        = 1'b1;
                                        uop_o.is_serializing = 1'b1;
                                    end
                                    F12_WFI: begin
                                        uop_o.is_wfi         = 1'b1;
                                        uop_o.is_serializing = 1'b1;
                                    end
                                    default: begin
                                        uop_o.exc_valid      = 1'b1;
                                        uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                                        uop_o.exc_tval       = pkt_i.insn;
                                        uop_o.is_serializing = 1'b1;
                                    end
                                endcase
                            end else begin
                                uop_o.exc_valid      = 1'b1;
                                uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                                uop_o.exc_tval       = pkt_i.insn;
                                uop_o.is_serializing = 1'b1;
                            end
                        end
                        F3_CSRRW: begin
                            uop_o.fu_type        = FU_CSR;
                            uop_o.is_serializing = 1'b1;
                            uop_o.csr_op         = CSR_RW;
                            uop_o.rs1_ren        = 1'b1;
                            uop_o.csr_use_imm    = 1'b0;
                            uop_o.imm            = csr_addr;
                            uop_o.rd_wen         = (rd != 5'd0);
                        end
                        F3_CSRRS: begin
                            uop_o.fu_type        = FU_CSR;
                            uop_o.is_serializing = 1'b1;
                            uop_o.csr_op         = CSR_RS;
                            uop_o.rs1_ren        = 1'b1;
                            uop_o.csr_use_imm    = 1'b0;
                            uop_o.imm            = csr_addr;
                            uop_o.rd_wen         = (rd != 5'd0);
                        end
                        F3_CSRRC: begin
                            uop_o.fu_type        = FU_CSR;
                            uop_o.is_serializing = 1'b1;
                            uop_o.csr_op         = CSR_RC;
                            uop_o.rs1_ren        = 1'b1;
                            uop_o.csr_use_imm    = 1'b0;
                            uop_o.imm            = csr_addr;
                            uop_o.rd_wen         = (rd != 5'd0);
                        end
                        F3_CSRRWI: begin
                            uop_o.fu_type        = FU_CSR;
                            uop_o.is_serializing = 1'b1;
                            uop_o.csr_op         = CSR_RW;
                            uop_o.rs1_ren        = 1'b0;
                            uop_o.csr_use_imm    = 1'b1;
                            uop_o.imm            = csr_addr;
                            uop_o.rd_wen         = (rd != 5'd0);
                        end
                        F3_CSRRSI: begin
                            uop_o.fu_type        = FU_CSR;
                            uop_o.is_serializing = 1'b1;
                            uop_o.csr_op         = CSR_RS;
                            uop_o.rs1_ren        = 1'b0;
                            uop_o.csr_use_imm    = 1'b1;
                            uop_o.imm            = csr_addr;
                            uop_o.rd_wen         = (rd != 5'd0);
                        end
                        F3_CSRRCI: begin
                            uop_o.fu_type        = FU_CSR;
                            uop_o.is_serializing = 1'b1;
                            uop_o.csr_op         = CSR_RC;
                            uop_o.rs1_ren        = 1'b0;
                            uop_o.csr_use_imm    = 1'b1;
                            uop_o.imm            = csr_addr;
                            uop_o.rd_wen         = (rd != 5'd0);
                        end
                        default: begin
                            uop_o.exc_valid      = 1'b1;
                            uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                            uop_o.exc_tval       = pkt_i.insn;
                            uop_o.is_serializing = 1'b1;
                        end
                    endcase
                end

                // -------------------------------------------------------------
                // Unrecognized / Reserved Opcode
                // -------------------------------------------------------------
                default: begin
                    uop_o.exc_valid      = 1'b1;
                    uop_o.exc_cause      = EXC_ILLEGAL_INSTR;
                    uop_o.exc_tval       = pkt_i.insn;
                    uop_o.is_serializing = 1'b1;
                end
            endcase
        end
    end

endmodule : decoder_rv32
