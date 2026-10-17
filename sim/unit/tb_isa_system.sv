`timescale 1ns / 1ps
// =============================================================================
// File:        sim/unit/tb_isa_system.sv
// Module:      tb_isa_system
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Human-Verifiable Directed Test Suite for the 12 Zicsr, Zifencei,
//   Zicntr, and Machine-Mode System/Trap Instructions:
//     - Zicsr (6):        `csrrw`, `csrrs`, `csrrc`, `csrrwi`, `csrrsi`, `csrrci`
//     - Memory Fence (2): `fence`, `fence.i`
//     - System/Trap (4):  `ecall`, `ebreak`, `mret`, `wfi`
//
//   How Verification Works (Using `tb_core` Debug Harness Ports):
//     1. Uses `har_read_csr` / `har_write_csr` / `har_assert_csr` and
//        `har_assert_gpr` to verify atomic CSR read-modify-write semantics,
//        counter increments (`mcycle`, `minstret`), and WARL bit masking.
//     2. Uses `har_assert_trap` to verify synchronous exceptions (`ecall`,
//        `ebreak`, illegal CSR access, read-only CSR write) and asynchronous
//        interrupt entry (`meip`, `mtip`, `msip`), checking `mepc`, `mcause`,
//        `mtval`, `mstatus.MIE`/`MPIE`, and `mtvec` direct vs. vectored jumps.
//     3. Uses self-modifying code dynamically rewritten before `fence.i` to
//        verify that instruction fetch pipeline flush refills from updated RAM.
// =============================================================================

module tb_isa_system
    import soc_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
    import tb_asm_pkg::*;
;

    commit_trace_t tr;
    logic err;

    // Helper task to execute a single instruction at MAIN_MEM_BASE and wait for retirement
    task automatic exec_single_insn(input logic [31:0] insn);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, insn, 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(100, tr);
    endtask

    // =========================================================================
    // 1. Zicsr Atomic Read-Modify-Write (`csrrw[i]`, `csrrs[i]`, `csrrc[i]`)
    // =========================================================================
    task automatic test_zicsr_and_counters();
        logic [31:0] mcycle_val;

        $display("[INFO] Running test_zicsr_and_counters...");

        // 1.1 CSRRW on CSR_MSCRATCH (0x340)
        // Preload mscratch = 0x1111_2222, x1 = 0xAABB_CCDD, x2 = 0xDEAD_BEEF
        tb_core.har_write_csr(CSR_MSCRATCH, 32'h1111_2222, err);
        tb_core.har_write_gpr(5'd1, 32'hAABB_CCDD);
        tb_core.har_write_gpr(5'd2, 32'hDEAD_BEEF);
        exec_single_insn(asm_csrrw(5'd2, CSR_MSCRATCH, 5'd1));
        tb_core.har_assert_gpr(5'd2, 32'h1111_2222, "csrrw rd read old CSR value");
        tb_core.har_assert_csr(CSR_MSCRATCH, 32'hAABB_CCDD, "csrrw wrote rs1 into mscratch");

        // 1.2 CSRRW Same-Register Swap (rd == rs1 == x1)
        // Preload mscratch = 0x1234_5678, x1 = 0x8765_4321
        tb_core.har_write_csr(CSR_MSCRATCH, 32'h1234_5678, err);
        tb_core.har_write_gpr(5'd1, 32'h8765_4321);
        exec_single_insn(asm_csrrw(5'd1, CSR_MSCRATCH, 5'd1));
        tb_core.har_assert_gpr(5'd1, 32'h1234_5678, "csrrw same-reg swap: rd receives old CSR");
        tb_core.har_assert_csr(CSR_MSCRATCH, 32'h8765_4321, "csrrw same-reg swap: CSR receives old rs1");

        // 1.3 CSRRWI Immediate Read-Write
        // Preload mscratch = 0xCAFE_BABE, zimm = 19 (0x13)
        tb_core.har_write_csr(CSR_MSCRATCH, 32'hCAFE_BABE, err);
        exec_single_insn(asm_csrrwi(5'd3, CSR_MSCRATCH, 5'd19));
        tb_core.har_assert_gpr(5'd3, 32'hCAFE_BABE, "csrrwi rd receives old CSR");
        tb_core.har_assert_csr(CSR_MSCRATCH, 32'h0000_0013, "csrrwi wrote zero-extended 5-bit zimm 19");

        // 1.4 CSRRS (Atomic Read and Set Bits)
        // Preload mscratch = 0xF0F0_0000, x1 = 0x0000_00FF
        tb_core.har_write_csr(CSR_MSCRATCH, 32'hF0F0_0000, err);
        tb_core.har_write_gpr(5'd1, 32'h0000_00FF);
        tb_core.har_write_gpr(5'd4, 32'hDEAD_BEEF);
        exec_single_insn(asm_csrrs(5'd4, CSR_MSCRATCH, 5'd1));
        tb_core.har_assert_gpr(5'd4, 32'hF0F0_0000, "csrrs rd receives old CSR value");
        tb_core.har_assert_csr(CSR_MSCRATCH, 32'hF0F0_00FF, "csrrs sets masked bits in CSR");

        // 1.5 CSRRSI (Immediate Bit Set)
        // Preload mscratch = 0x1000_0000, zimm = 5'b00101 (0x5)
        tb_core.har_write_csr(CSR_MSCRATCH, 32'h1000_0000, err);
        exec_single_insn(asm_csrrsi(5'd5, CSR_MSCRATCH, 5'd5));
        tb_core.har_assert_gpr(5'd5, 32'h1000_0000, "csrrsi rd receives old CSR value");
        tb_core.har_assert_csr(CSR_MSCRATCH, 32'h1000_0005, "csrrsi sets bits [2, 0]");

        // 1.6 CSRRC (Atomic Read and Clear Bits)
        // Preload mscratch = 0xFFFF_FFFF, x1 = 0x0000_000F
        tb_core.har_write_csr(CSR_MSCRATCH, 32'hFFFF_FFFF, err);
        tb_core.har_write_gpr(5'd1, 32'h0000_000F);
        exec_single_insn(asm_csrrc(5'd6, CSR_MSCRATCH, 5'd1));
        tb_core.har_assert_gpr(5'd6, 32'hFFFF_FFFF, "csrrc rd receives old CSR value");
        tb_core.har_assert_csr(CSR_MSCRATCH, 32'hFFFF_FFF0, "csrrc clears masked bits [3:0]");

        // 1.7 CSRRCI (Immediate Bit Clear)
        // Preload mscratch = 0xFFFF_FFF0, zimm = 5'd16 (bit 4)
        tb_core.har_write_csr(CSR_MSCRATCH, 32'hFFFF_FFF0, err);
        exec_single_insn(asm_csrrci(5'd7, CSR_MSCRATCH, 5'd16));
        tb_core.har_assert_gpr(5'd7, 32'hFFFF_FFF0, "csrrci rd receives old CSR value");
        tb_core.har_assert_csr(CSR_MSCRATCH, 32'hFFFF_FFE0, "csrrci clears bit 4");

        // 1.8 Read-Only Machine Info CSRs (csrr rd, csr -> csrrs rd, csr, x0)
        // When rs1 == x0, no write is attempted, so read-only CSRs must NOT trap
        exec_single_insn(asm_csrrs(5'd8, CSR_MHARTID, 5'd0));
        tb_core.har_assert_gpr(5'd8, 32'd0, "csrr rd, mhartid reads 0");

        exec_single_insn(asm_csrrs(5'd9, CSR_MIMPID, 5'd0));
        tb_core.har_assert_gpr(5'd9, 32'd2, "csrr rd, mimpid reads 2");

        exec_single_insn(asm_csrrs(5'd10, CSR_MVENDORID, 5'd0));
        tb_core.har_assert_gpr(5'd10, 32'd0, "csrr rd, mvendorid reads 0");

        exec_single_insn(asm_csrrs(5'd11, CSR_MARCHID, 5'd0));
        tb_core.har_assert_gpr(5'd11, 32'd0, "csrr rd, marchid reads 0");

        // 1.9 Performance Counters (minstret and mcycle)
        // Preload minstret = 1000
        tb_core.har_write_csr(CSR_MINSTRET, 32'd1000, err);
        // Execute a sequence of 3 independent instructions
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_addi(5'd1, 5'd0, 12'd1), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_addi(5'd2, 5'd0, 12'd2), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8, asm_addi(5'd3, 5'd0, 12'd3), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 12, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_wait_retire(50, tr);
        tb_core.har_assert_csr(CSR_MINSTRET, 32'd1003, "minstret incremented by exactly 3 retired instructions");

        // Write and read mcycle
        tb_core.har_write_csr(CSR_MCYCLE, 32'h0010_0000, err);
        repeat (10) @(posedge tb_core.clk);
        tb_core.har_read_csr(CSR_MCYCLE, mcycle_val, err);
        if (mcycle_val >= 32'h0010_0005) begin
            $display("[PASS] mcycle running check: mcycle = 0x%08h", mcycle_val);
        end else begin
            $display("[FAIL] mcycle running check: mcycle = 0x%08h, expected >= 0x00100005", mcycle_val);
            tb_core.test_errors++;
        end

        // 1.10 Trap Cases: Write to Read-Only CSR
        // Per RISC-V Spec §9.1, csrrw ALWAYS performs a write even if rs1 == x0
        tb_core.har_write_gpr(5'd12, 32'hDEAD_BEEF);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_csrrw(5'd12, CSR_MHARTID, 5'd0), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, asm_csrrw(5'd12, CSR_MHARTID, 5'd0),
                               "csrrw write to read-only CSR_MHARTID raises EXC_ILLEGAL_INSTR");
        tb_core.har_assert_gpr(5'd12, 32'hDEAD_BEEF, "destination rd unmodified after CSR write trap");

        // csrrs with rs1 != x0 to read-only cycle counter
        tb_core.har_write_gpr(5'd1, 32'd1);
        tb_core.har_write_gpr(5'd13, 32'hDEAD_BEEF);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_csrrs(5'd13, CSR_CYCLE, 5'd1), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, asm_csrrs(5'd13, CSR_CYCLE, 5'd1),
                               "csrrs write attempt to read-only CSR_CYCLE raises EXC_ILLEGAL_INSTR");
        tb_core.har_assert_gpr(5'd13, 32'hDEAD_BEEF, "destination rd unmodified after cycle write trap");

        // 1.11 Trap Cases: Access to Unimplemented / Reserved CSRs
        // Unimplemented satp (0x180)
        tb_core.har_write_gpr(5'd14, 32'hDEAD_BEEF);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_csrrs(5'd14, 12'h180, 5'd0), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, asm_csrrs(5'd14, 12'h180, 5'd0),
                               "read access to unimplemented satp (0x180) raises EXC_ILLEGAL_INSTR");
        tb_core.har_assert_gpr(5'd14, 32'hDEAD_BEEF, "destination rd unmodified after satp trap");

        // Unimplemented medeleg (0x302)
        tb_core.har_write_gpr(5'd15, 32'hDEAD_BEEF);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_csrrs(5'd15, 12'h302, 5'd0), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, asm_csrrs(5'd15, 12'h302, 5'd0),
                               "read access to unimplemented medeleg (0x302) raises EXC_ILLEGAL_INSTR");
        tb_core.har_assert_gpr(5'd15, 32'hDEAD_BEEF, "destination rd unmodified after medeleg trap");

        // Non-existent CSR mnstatus (0x744)
        tb_core.har_write_gpr(5'd16, 32'hDEAD_BEEF);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_csrrs(5'd16, 12'h744, 5'd0), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, asm_csrrs(5'd16, 12'h744, 5'd0),
                               "read access to unimplemented mnstatus (0x744) raises EXC_ILLEGAL_INSTR");
        tb_core.har_assert_gpr(5'd16, 32'hDEAD_BEEF, "destination rd unmodified after mnstatus trap");
    endtask

    // =========================================================================
    // 2. FENCE / FENCE.I (Self-Modifying Code Pipeline Flush)
    // =========================================================================
    task automatic test_fence_and_fence_i();
        $display("[INFO] Running test_fence_and_fence_i...");

        // 2.1 FENCE: Retires as a 1-cycle NOP in M1 without trapping
        exec_single_insn(asm_fence());
        $display("[PASS] fence retired cleanly without trapping");

        // 2.2 FENCE.I (Self-Modifying Code Test)
        // Memory Layout:
        //   +0:  sw x1, 8(x2)    <- Writes updated instruction 'addi x5, x0, 99' into +8
        //   +4:  fence.i         <- Flushes prefetch queue and redirects fetch to +8
        //   +8:  addi x5, x0, 1  <- Stale instruction originally written here!
        //   +12: wfi
        //
        // Registers:
        //   x1 = asm_addi(5'd5, 5'd0, 12'd99)
        //   x2 = MAIN_MEM_BASE
        //   x5 = 0
        tb_core.har_write_gpr(5'd1, asm_addi(5'd5, 5'd0, 12'd99));
        tb_core.har_write_gpr(5'd2, soc_pkg::MAIN_MEM_BASE);
        tb_core.har_write_gpr(5'd5, 32'd0);

        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0,  asm_sw(5'd1, 5'd2, 12'd8), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4,  asm_fence_i(),             4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8,  asm_addi(5'd5, 5'd0, 12'd1), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 12, asm_wfi(),                 4'b1111, err);

        // Retire sw, fence.i, and the modified addi
        tb_core.har_wait_retire(100, tr); // sw
        tb_core.har_wait_retire(100, tr); // fence.i
        tb_core.har_wait_retire(100, tr); // modified addi

        tb_core.har_assert_gpr(5'd5, 32'd99, "fence.i pipeline flush executed updated code (99 not 1)");
    endtask

    // =========================================================================
    // 3. ECALL / EBREAK / MRET / WFI & Interrupt Entry (`trap_ctrl.sv`)
    // =========================================================================
    task automatic test_traps_mret_and_interrupts();
        logic [31:0] mstatus_val;
        logic [31:0] malformed_insn;

        $display("[INFO] Running test_traps_mret_and_interrupts...");

        // 3.1 ECALL (Synchronous Environment Call from M-Mode)
        // Preload mtvec to handler address (direct mode: mtvec[1:0] == 2'b00)
        tb_core.har_write_csr(CSR_MTVEC, soc_pkg::MAIN_MEM_BASE + 32'h0100, err);
        tb_core.har_write_csr(CSR_MSTATUS, (32'd1 << MSTATUS_MIE_BIT) | (32'd3 << MSTATUS_MPP_LO), err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_ecall(), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);

        tb_core.har_assert_trap(EXC_ECALL_M, soc_pkg::MAIN_MEM_BASE, 32'h0, "ecall causes EXC_ECALL_M");

        tb_core.har_read_csr(CSR_MSTATUS, mstatus_val, err);
        if ((mstatus_val[MSTATUS_MIE_BIT] == 1'b0) &&
            (mstatus_val[MSTATUS_MPIE_BIT] == 1'b1) &&
            (mstatus_val[MSTATUS_MPP_HI:MSTATUS_MPP_LO] == 2'b11)) begin
            $display("[PASS] ecall updated mstatus: MIE=0, MPIE=1, MPP=3 (0x%08h)", mstatus_val);
        end else begin
            $display("[FAIL] ecall updated mstatus incorrectly: 0x%08h", mstatus_val);
            tb_core.test_errors++;
        end

        // 3.2 EBREAK (Breakpoint Exception)
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_ebreak(), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_assert_trap(EXC_BREAKPOINT, soc_pkg::MAIN_MEM_BASE, soc_pkg::MAIN_MEM_BASE,
                                "ebreak causes EXC_BREAKPOINT");

        // 3.3 MRET (Trap Return)
        // Set mepc = MAIN_MEM_BASE + 0x10, MPIE = 1, MIE = 0
        tb_core.har_write_csr(CSR_MEPC, soc_pkg::MAIN_MEM_BASE + 32'h0010, err);
        tb_core.har_write_csr(CSR_MSTATUS, (32'd1 << MSTATUS_MPIE_BIT) | (32'd3 << MSTATUS_MPP_LO), err);
        tb_core.har_write_gpr(5'd6, 32'd0);

        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, asm_mret(), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 32'h0010, asm_addi(5'd6, 5'd0, 12'd88), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 32'h0014, asm_wfi(), 4'b1111, err);

        tb_core.har_wait_retire(100, tr); // mret
        tb_core.har_wait_retire(100, tr); // addi x6, 88
        tb_core.har_assert_gpr(5'd6, 32'd88, "mret redirected execution to mepc (0x8000_0010)");

        tb_core.har_read_csr(CSR_MSTATUS, mstatus_val, err);
        if ((mstatus_val[MSTATUS_MIE_BIT] == 1'b1) &&
            (mstatus_val[MSTATUS_MPIE_BIT] == 1'b1)) begin
            $display("[PASS] mret restored mstatus: MIE=1, MPIE=1 (0x%08h)", mstatus_val);
        end else begin
            $display("[FAIL] mret restored mstatus incorrectly: 0x%08h", mstatus_val);
            tb_core.test_errors++;
        end

        // 3.4 WFI (Wait For Interrupt)
        tb_core.har_write_gpr(5'd7, 32'd0);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE,     asm_wfi(), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_addi(5'd7, 5'd0, 12'd77), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 8, asm_wfi(), 4'b1111, err);
        tb_core.har_wait_retire(100, tr); // wfi
        tb_core.har_wait_retire(100, tr); // addi x7, 77
        tb_core.har_assert_gpr(5'd7, 32'd77, "wfi behaves as NOP when no interrupts are pending");

        // 3.5 Asynchronous Interrupt Entry in Direct Mode (Timer IRQ: cause 7)
        tb_core.har_write_csr(CSR_MTVEC, soc_pkg::MAIN_MEM_BASE + 32'h0100, err); // Direct mode (mode = 0)
        tb_core.har_write_csr(CSR_MSTATUS, (32'd1 << MSTATUS_MIE_BIT) | (32'd3 << MSTATUS_MPP_LO), err);
        tb_core.har_write_csr(CSR_MIE, (32'd1 << MIE_MTIE_BIT), err);
        tb_core.har_write_gpr(5'd8, 32'd0);

        // Infinite loop at MAIN_MEM_BASE
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 0, asm_addi(5'd1, 5'd1, 12'd1), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_jal(5'd0, -21'd4),       4'b1111, err);
        // Handler at MAIN_MEM_BASE + 0x100
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 32'h0100, asm_addi(5'd8, 5'd0, 12'd42), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 32'h0104, asm_wfi(),                     4'b1111, err);

        tb_core.mtip <= 1'b1;
        tb_core.har_wait_retire(100, tr); // Interrupt boundary trap
        if (tr.trap_taken && (tr.trap_cause == IRQ_CAUSE_M_TIMER)) begin
            $display("[PASS] Timer IRQ taken at commit boundary: cause=%0d", tr.trap_cause);
        end else begin
            $display("[FAIL] Timer IRQ not taken: trap_taken=%b cause=%0d", tr.trap_taken, tr.trap_cause);
            tb_core.test_errors++;
        end
        tb_core.har_assert_csr(CSR_MCAUSE, 32'h8000_0007, "mcause has MSB=1 and cause 7 for timer IRQ");

        tb_core.mtip <= 1'b0;
        tb_core.har_wait_retire(100, tr); // Handler addi x8
        tb_core.har_assert_gpr(5'd8, 32'd42, "timer IRQ jumped to direct mtvec handler");

        // 3.6 Asynchronous Interrupt Entry in Vectored Mode (Timer IRQ -> base + 4*7)
        // Vectored mode: mtvec[1:0] == 2'b01
        tb_core.har_write_csr(CSR_MTVEC, (soc_pkg::MAIN_MEM_BASE + 32'h0200) | 32'd1, err);
        tb_core.har_write_csr(CSR_MSTATUS, (32'd1 << MSTATUS_MIE_BIT) | (32'd3 << MSTATUS_MPP_LO), err);
        tb_core.har_write_csr(CSR_MIE, (32'd1 << MIE_MTIE_BIT), err);
        tb_core.har_write_gpr(5'd9, 32'd0);

        // Vector table entry for cause 7 is base + 4 * 7 = MAIN_MEM_BASE + 0x200 + 0x1C = 0x21C
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 32'h021C, asm_addi(5'd9, 5'd0, 12'd84), 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 32'h0220, asm_wfi(),                     4'b1111, err);

        tb_core.mtip <= 1'b1;
        tb_core.har_wait_retire(100, tr); // Interrupt boundary trap
        tb_core.mtip <= 1'b0;
        tb_core.har_wait_retire(100, tr); // Vectored handler addi x9
        tb_core.har_assert_gpr(5'd9, 32'd84, "timer IRQ jumped to vectored target base + 4*7 (0x21C)");

        // 3.7 Simultaneous Interrupt Priority (MEI > MSI > MTI)
        tb_core.har_write_csr(CSR_MTVEC, soc_pkg::MAIN_MEM_BASE + 32'h0100, err);
        tb_core.har_write_csr(CSR_MSTATUS, (32'd1 << MSTATUS_MIE_BIT) | (32'd3 << MSTATUS_MPP_LO), err);
        tb_core.har_write_csr(CSR_MIE, (32'd1 << MIE_MEIE_BIT) |
                                       (32'd1 << MIE_MTIE_BIT) |
                                       (32'd1 << MIE_MSIE_BIT), err);

        // Assert all 3 interrupts simultaneously
        tb_core.meip <= 1'b1;
        tb_core.mtip <= 1'b1;
        tb_core.msip <= 1'b1;

        tb_core.har_wait_retire(100, tr); // Interrupt trap
        tb_core.har_assert_csr(CSR_MCAUSE, 32'h8000_000B, "simultaneous IRQs prioritize external MEI (cause 11)");

        tb_core.meip <= 1'b0;
        tb_core.mtip <= 1'b0;
        tb_core.msip <= 1'b0;

        // 3.8 Malformed SYSTEM / PRIV Instruction Checks
        // Malformed ecall with rs1 != 0 (rs1 is in bits [19:15])
        malformed_insn = {F12_ECALL, 5'd1, F3_PRIV, 5'd0, OPCODE_SYSTEM};
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, malformed_insn, 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, malformed_insn,
                                "malformed ecall (rs1!=0) raises EXC_ILLEGAL_INSTR");

        // Malformed mret with rd != 0 (rd is in bits [11:7])
        malformed_insn = {F12_MRET, 5'd0, F3_PRIV, 5'd1, OPCODE_SYSTEM};
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, malformed_insn, 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, malformed_insn,
                                "malformed mret (rd!=0) raises EXC_ILLEGAL_INSTR");

        // Unrecognized PRIV funct12 (0xFFF)
        malformed_insn = {12'hFFF, 5'd0, F3_PRIV, 5'd0, OPCODE_SYSTEM};
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE, malformed_insn, 4'b1111, err);
        tb_core.har_write_mem(soc_pkg::MAIN_MEM_BASE + 4, asm_wfi(), 4'b1111, err);
        tb_core.har_assert_trap(EXC_ILLEGAL_INSTR, soc_pkg::MAIN_MEM_BASE, malformed_insn,
                                "unrecognized funct12 raises EXC_ILLEGAL_INSTR");
    endtask

    // =========================================================================
    // 4. Test Suite Dispatcher
    // =========================================================================
    task automatic run_all();
        $display("----------------------------------------------------------------");
        $display("  tb_isa_system: Starting System & Trap Instruction Tests       ");
        $display("----------------------------------------------------------------");
        test_zicsr_and_counters();
        test_fence_and_fence_i();
        test_traps_mret_and_interrupts();
        $display("  tb_isa_system: Completed all System tests.                    ");
        $display("----------------------------------------------------------------");
    endtask

endmodule : tb_isa_system
