`timescale 1ns / 1ps
// =============================================================================
// File:        sim/tb_core.sv
// Module:      tb_core
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Core Verification & Debug-Port Inspection Harness (`tb_core`).
//   Instantiates `core.sv` (`HAS_DEBUG = 1'b1`), `debug_module.sv` (with
//   `dm_sba.sv`), `soc_xbar.sv`, `boot_rom.sv`, and `axi_bram_mem.sv`.
//
//   Why This Harness Uses the `HAS_DEBUG` Subsystem:
//     Instead of relying solely on a single final `tohost` pass/fail write at
//     the end of a test (which cannot distinguish whether an instruction
//     computed the wrong result vs. whether a subsequent instruction or trap
//     corrupted state), this harness connects to the `HAS_DEBUG`-gated ports on
//     `debug_module.sv` (`har_reg_*` -> `core.sv` -> `debug_ctrl.sv` ->
//     `prf.sv` / `csr_unit.sv`, and `har_mem_*` -> `dm_sba.sv` ->
//     `soc_xbar.sv`):
//       1. **Register File (`prf.sv`) Inspection & Preloading:**
//          - `har_read_gpr` / `har_write_gpr` / `har_assert_gpr` read or write
//            any architectural register (`x0..x31`) through `debug_ctrl.sv`.
//          - Verifies both positive outcomes (e.g., `add x5, x1, x2` wrote the
//            expected sum to `x5`) and negative/exception outcomes (e.g., an
//            illegal instruction or faulting load with destination `x5` left
//            the previous sentinel value in `x5` untouched!).
//       2. **CSR (`csr_unit.sv`) Inspection & Trap Verification:**
//          - `har_read_csr` / `har_write_csr` / `har_assert_csr` inspect
//            `mcause`, `mepc`, `mtval`, `mstatus`, `mtvec`, `mcycle`, and
//            `minstret` directly via `debug_ctrl.sv`.
//          - Verifies whether a trap was taken for the exact expected cause and
//            faulting PC/address (`mtval`), or whether an unexpected trap
//            fired.
//       3. **Physical Memory (`axi_bram_mem` / `boot_rom`) Inspection via SBA:**
//          - `har_read_mem` / `har_write_mem` / `har_assert_mem` access physical
//            memory over the Debug System Bus Access (`dm_sba.sv`) master port
//            on `soc_xbar.sv`, completely independent of the CPU's LSU!
//          - Verifies that `sb`/`sh`/`sw` modified only the targeted byte lanes
//            in RAM, and that a faulting store to read-only `boot_rom` did not
//            corrupt the ROM contents.
//       4. **Cycle-Accurate Retirement Trace (`commit_trace_o`):**
//          - `har_wait_retire` captures the `commit_trace_t` bundle emitted by
//            `commit.sv` on each retired or trapped instruction and logs it for
//            Spike lockstep comparison.
//
// Connections:
//   - Instantiates:
//       * `core #(.HAS_DEBUG(1'b1))`         (`u_core`)
//       * `debug_module #(.N_CORES(1))`      (`u_debug_module`)
//       * `soc_xbar #(.HAS_DEBUG(1'b1))`     (`u_soc_xbar`)
//       * `boot_rom`                         (`u_boot_rom`)
//       * `axi_bram_mem`                     (`u_main_mem`)
//   - Unit Test Suites Instantiated:
//       * `tb_isa_alu`                       (`u_test_alu`)
//       * `tb_isa_bru`                       (`u_test_bru`)
//       * `tb_isa_muldiv`                    (`u_test_muldiv`)
//       * `tb_isa_lsu`                       (`u_test_lsu`)
//       * `tb_isa_system`                    (`u_test_system`)
// =============================================================================

module tb_core
    import soc_pkg::*;
    import cbus_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
;

    // -------------------------------------------------------------------------
    // 1. Clock & Reset Signals
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #5.0 clk = ~clk; // 100 MHz simulation clock

    // -------------------------------------------------------------------------
    // 2. Interconnect, Core & Debug Harness Signals
    // -------------------------------------------------------------------------
    // Core <-> Crossbar cbus
    wire          core_req_valid;
    wire          core_req_ready;
    cbus_req_t    core_req;
    wire          core_rsp_valid;
    wire          core_rsp_ready;
    cbus_rsp_t    core_rsp;

    // Debug SBA <-> Crossbar cbus (gated by HAS_DEBUG)
    wire          sba_req_valid;
    wire          sba_req_ready;
    cbus_req_t    sba_req;
    wire          sba_rsp_valid;
    wire          sba_rsp_ready;
    cbus_rsp_t    sba_rsp;

    // Crossbar <-> Slaves (Boot ROM, MMIO tie-off, Main Memory BRAM)
    wire          rom_req_valid,  rom_req_ready,  rom_rsp_valid,  rom_rsp_ready;
    cbus_req_t    rom_req;
    cbus_rsp_t    rom_rsp;

    wire          mmio_req_valid, mmio_req_ready, mmio_rsp_valid, mmio_rsp_ready;
    cbus_req_t    mmio_req;
    cbus_rsp_t    mmio_rsp;

    wire          ram_req_valid,  ram_req_ready,  ram_rsp_valid,  ram_rsp_ready;
    cbus_req_t    ram_req;
    cbus_rsp_t    ram_rsp;

    // Interrupt lines (driven by testbench in directed interrupt tests)
    logic         meip;
    logic         mtip;
    logic         msip;

    // Debug Module <-> Core (gated by HAS_DEBUG)
    wire          core_debug_req;
    wire          core_dbg_halted;
    dbg_reg_req_t core_dbg_reg_req;
    dbg_reg_rsp_t core_dbg_reg_rsp;

    // Testbench Harness <-> Debug Module Inspection Ports
    dbg_reg_req_t har_reg_req;
    dbg_reg_rsp_t har_reg_rsp;

    logic         har_mem_req_valid;
    wire          har_mem_req_ready;
    logic         har_mem_req_write;
    logic [31:0]  har_mem_req_addr;
    logic [31:0]  har_mem_req_wdata;
    logic [3:0]   har_mem_req_wstrb;
    wire          har_mem_rsp_valid;
    wire  [31:0]  har_mem_rsp_rdata;
    wire          har_mem_rsp_err;

    // Architectural Retirement Trace Output
    commit_trace_t commit_trace;

    // -------------------------------------------------------------------------
    // 3. DUT & Subsystem Instantiations
    // -------------------------------------------------------------------------
    core #(
        .RESET_ADDR     (soc_pkg::MAIN_MEM_BASE),
        .MAIN_MEM_BYTES (96 * 1024),
        .HAS_MULDIV     (1'b1),
        .HAS_VECTOR     (1'b0),
        .HAS_DEBUG      (1'b1)
    ) u_core (
        .clk_i            (clk),
        .rst_n_i          (rst_n),
        .hart_id_i        (32'd0),
        .cbus_req_valid_o (core_req_valid),
        .cbus_req_ready_i (core_req_ready),
        .cbus_req_o       (core_req),
        .cbus_rsp_valid_i (core_rsp_valid),
        .cbus_rsp_ready_o (core_rsp_ready),
        .cbus_rsp_i       (core_rsp),
        .meip_i           (meip),
        .mtip_i           (mtip),
        .msip_i           (msip),
        .debug_req_i      (core_debug_req),
        .dbg_halted_o     (core_dbg_halted),
        .dbg_reg_req_i    (core_dbg_reg_req),
        .dbg_reg_rsp_o    (core_dbg_reg_rsp),
        .commit_trace_o   (commit_trace)
    );

    debug_module #(
        .N_CORES (1)
    ) u_debug_module (
        .clk_i               (clk),
        .rst_n_i             (rst_n),
        .har_reg_req_i       (har_reg_req),
        .har_reg_rsp_o       (har_reg_rsp),
        .har_mem_req_valid_i (har_mem_req_valid),
        .har_mem_req_ready_o (har_mem_req_ready),
        .har_mem_req_write_i (har_mem_req_write),
        .har_mem_req_addr_i  (har_mem_req_addr),
        .har_mem_req_wdata_i (har_mem_req_wdata),
        .har_mem_req_wstrb_i (har_mem_req_wstrb),
        .har_mem_rsp_valid_o (har_mem_rsp_valid),
        .har_mem_rsp_rdata_o (har_mem_rsp_rdata),
        .har_mem_rsp_err_o   (har_mem_rsp_err),
        .core_debug_req_o    (core_debug_req),
        .core_dbg_halted_i   (core_dbg_halted),
        .core_dbg_reg_req_o  (core_dbg_reg_req),
        .core_dbg_reg_rsp_i  (core_dbg_reg_rsp),
        .sba_req_valid_o     (sba_req_valid),
        .sba_req_ready_i     (sba_req_ready),
        .sba_req_o           (sba_req),
        .sba_rsp_valid_i     (sba_rsp_valid),
        .sba_rsp_ready_o     (sba_rsp_ready),
        .sba_rsp_i           (sba_rsp)
    );

    soc_xbar #(
        .MAIN_MEM_BYTES (96 * 1024),
        .HAS_DEBUG      (1'b1)
    ) u_soc_xbar (
        .clk_i              (clk),
        .rst_n_i            (rst_n),
        .m_core_req_valid_i (core_req_valid),
        .m_core_req_ready_o (core_req_ready),
        .m_core_req_i       (core_req),
        .m_core_rsp_valid_o (core_rsp_valid),
        .m_core_rsp_ready_i (core_rsp_ready),
        .m_core_rsp_o       (core_rsp),
        .m_sba_req_valid_i  (sba_req_valid),
        .m_sba_req_ready_o  (sba_req_ready),
        .m_sba_req_i        (sba_req),
        .m_sba_rsp_valid_o  (sba_rsp_valid),
        .m_sba_rsp_ready_i  (sba_rsp_ready),
        .m_sba_rsp_o        (sba_rsp),
        .s_rom_req_valid_o  (rom_req_valid),
        .s_rom_req_ready_i  (rom_req_ready),
        .s_rom_req_o        (rom_req),
        .s_rom_rsp_valid_i  (rom_rsp_valid),
        .s_rom_rsp_ready_o  (rom_rsp_ready),
        .s_rom_rsp_i        (rom_rsp),
        .s_mmio_req_valid_o (mmio_req_valid),
        .s_mmio_req_ready_i (mmio_req_ready),
        .s_mmio_req_o       (mmio_req),
        .s_mmio_rsp_valid_i (mmio_rsp_valid),
        .s_mmio_rsp_ready_o (mmio_rsp_ready),
        .s_mmio_rsp_i       (mmio_rsp),
        .s_ram_req_valid_o  (ram_req_valid),
        .s_ram_req_ready_i  (ram_req_ready),
        .s_ram_req_o        (ram_req),
        .s_ram_rsp_valid_i  (ram_rsp_valid),
        .s_ram_rsp_ready_o  (ram_rsp_ready),
        .s_ram_rsp_i        (ram_rsp)
    );

    boot_rom #(
        .ROM_BYTES (soc_pkg::BOOT_ROM_SIZE)
    ) u_boot_rom (
        .clk_i            (clk),
        .rst_n_i          (rst_n),
        .cbus_req_valid_i (rom_req_valid),
        .cbus_req_ready_o (rom_req_ready),
        .cbus_req_i       (rom_req),
        .cbus_rsp_valid_o (rom_rsp_valid),
        .cbus_rsp_ready_i (rom_rsp_ready),
        .cbus_rsp_o       (rom_rsp)
    );

    axi_bram_mem #(
        .MEM_BYTES (96 * 1024)
    ) u_main_mem (
        .clk_i            (clk),
        .rst_n_i          (rst_n),
        .cbus_req_valid_i (ram_req_valid),
        .cbus_req_ready_o (ram_req_ready),
        .cbus_req_i       (ram_req),
        .cbus_rsp_valid_o (ram_rsp_valid),
        .cbus_rsp_ready_i (ram_rsp_ready),
        .cbus_rsp_o       (ram_rsp)
    );

    // Default tie-off for MMIO in standalone core testbench
    assign mmio_req_ready = 1'b1;
    assign mmio_rsp_valid = 1'b0;
    assign mmio_rsp       = '0;

    // -------------------------------------------------------------------------
    // 4. Verification Harness Inspection Tasks (Using HAS_DEBUG Ports)
    // -------------------------------------------------------------------------
    int unsigned test_errors = 0;

    // Read a 32-bit GPR (`x0..x31`) via the Debug Register Inspection port
    task automatic har_read_gpr(
        input  logic [4:0]  reg_idx,
        output logic [31:0] rdata
    );
        @(posedge clk);
        har_reg_req.valid <= 1'b1;
        har_reg_req.write <= 1'b0;
        har_reg_req.is_csr <= 1'b0;
        har_reg_req.addr <= {7'b0, reg_idx};
        har_reg_req.wdata <= '0;
        do @(posedge clk); while (!har_reg_rsp.ready);
        rdata = har_reg_rsp.rdata;
        har_reg_req.valid <= 1'b0;
    endtask

    // Write/Preload a 32-bit GPR (`x1..x31`) via the Debug Register Inspection port
    task automatic har_write_gpr(
        input logic [4:0]  reg_idx,
        input logic [31:0] wdata
    );
        @(posedge clk);
        har_reg_req.valid <= 1'b1;
        har_reg_req.write <= 1'b1;
        har_reg_req.is_csr <= 1'b0;
        har_reg_req.addr <= {7'b0, reg_idx};
        har_reg_req.wdata <= wdata;
        do @(posedge clk); while (!har_reg_rsp.ready);
        har_reg_req.valid <= 1'b0;
    endtask

    // Assert that GPR `reg_idx` holds `expected_val`
    task automatic har_assert_gpr(
        input logic [4:0]  reg_idx,
        input logic [31:0] expected_val,
        input string       desc
    );
        logic [31:0] actual_val;
        har_read_gpr(reg_idx, actual_val);
        if (actual_val === expected_val) begin
            $display("[PASS] %s: GPR x%0d = 0x%08h", desc, reg_idx, actual_val);
        end else begin
            $display("[FAIL] %s: GPR x%0d = 0x%08h, expected 0x%08h", desc, reg_idx, actual_val, expected_val);
            test_errors++;
        end
    endtask

    // Read a 32-bit CSR via the Debug Register Inspection port
    task automatic har_read_csr(
        input  logic [11:0] csr_addr,
        output logic [31:0] rdata,
        output logic        err
    );
        @(posedge clk);
        har_reg_req.valid <= 1'b1;
        har_reg_req.write <= 1'b0;
        har_reg_req.is_csr <= 1'b1;
        har_reg_req.addr <= csr_addr;
        har_reg_req.wdata <= '0;
        do @(posedge clk); while (!har_reg_rsp.ready);
        rdata = har_reg_rsp.rdata;
        err   = har_reg_rsp.err;
        har_reg_req.valid <= 1'b0;
    endtask

    // Write/Preload a 32-bit CSR via the Debug Register Inspection port
    task automatic har_write_csr(
        input  logic [11:0] csr_addr,
        input  logic [31:0] wdata,
        output logic        err
    );
        @(posedge clk);
        har_reg_req.valid <= 1'b1;
        har_reg_req.write <= 1'b1;
        har_reg_req.is_csr <= 1'b1;
        har_reg_req.addr <= csr_addr;
        har_reg_req.wdata <= wdata;
        do @(posedge clk); while (!har_reg_rsp.ready);
        err = har_reg_rsp.err;
        har_reg_req.valid <= 1'b0;
    endtask

    // Assert that CSR `csr_addr` holds `expected_val`
    task automatic har_assert_csr(
        input logic [11:0] csr_addr,
        input logic [31:0] expected_val,
        input string       desc
    );
        logic [31:0] actual_val;
        logic err;
        har_read_csr(csr_addr, actual_val, err);
        if (!err && (actual_val === expected_val)) begin
            $display("[PASS] %s: CSR 0x%03h = 0x%08h", desc, csr_addr, actual_val);
        end else begin
            $display("[FAIL] %s: CSR 0x%03h = 0x%08h (err=%b), expected 0x%08h", desc, csr_addr, actual_val, err, expected_val);
            test_errors++;
        end
    endtask

    // Read a 32-bit word from physical memory via the Debug SBA port
    task automatic har_read_mem(
        input  logic [31:0] addr,
        output logic [31:0] rdata,
        output logic        err
    );
        @(posedge clk);
        har_mem_req_valid <= 1'b1;
        har_mem_req_write <= 1'b0;
        har_mem_req_addr  <= addr;
        har_mem_req_wdata <= '0;
        har_mem_req_wstrb <= 4'b1111;
        do @(posedge clk); while (!har_mem_rsp_valid);
        rdata = har_mem_rsp_rdata;
        err   = har_mem_rsp_err;
        har_mem_req_valid <= 1'b0;
    endtask

    // Write a 32-bit word (or byte-masked lanes) to physical memory via Debug SBA
    task automatic har_write_mem(
        input  logic [31:0] addr,
        input  logic [31:0] wdata,
        input  logic [3:0]  wstrb,
        output logic        err
    );
        @(posedge clk);
        har_mem_req_valid <= 1'b1;
        har_mem_req_write <= 1'b1;
        har_mem_req_addr  <= addr;
        har_mem_req_wdata <= wdata;
        har_mem_req_wstrb <= wstrb;
        do @(posedge clk); while (!har_mem_rsp_valid);
        err = har_mem_rsp_err;
        har_mem_req_valid <= 1'b0;
    endtask

    // Assert that physical memory at `addr` holds `expected_val`
    task automatic har_assert_mem(
        input logic [31:0] addr,
        input logic [31:0] expected_val,
        input string       desc
    );
        logic [31:0] actual_val;
        logic err;
        har_read_mem(addr, actual_val, err);
        if (!err && (actual_val === expected_val)) begin
            $display("[PASS] %s: Mem[0x%08h] = 0x%08h", desc, addr, actual_val);
        end else begin
            $display("[FAIL] %s: Mem[0x%08h] = 0x%08h (err=%b), expected 0x%08h", desc, addr, actual_val, err, expected_val);
            test_errors++;
        end
    endtask

    // Wait for the next instruction retirement or trap on `commit_trace_o`
    task automatic har_wait_retire(
        input  int unsigned   timeout_cycles,
        output commit_trace_t trace_out
    );
        int unsigned cnt = 0;
        trace_out = '0;
        while (cnt < timeout_cycles) begin
            @(posedge clk);
            cnt++;
            if (commit_trace.valid) begin
                trace_out = commit_trace;
                return;
            end
        end
        $display("[TIMEOUT] har_wait_retire timed out after %0d cycles", timeout_cycles);
        test_errors++;
    endtask

    // Verify that a precise trap occurred with expected `mcause`, `mepc`, and `mtval`
    task automatic har_assert_trap(
        input logic [3:0]  expected_cause,
        input logic [31:0] expected_epc,
        input logic [31:0] expected_tval,
        input string       desc
    );
        commit_trace_t tr;
        har_wait_retire(100, tr);
        if (tr.trap_taken && (tr.trap_cause == expected_cause)) begin
            $display("[PASS] %s: Trap taken cause=%0d, epc=0x%08h", desc, tr.trap_cause, tr.pc);
        end else begin
            $display("[FAIL] %s: Expected trap cause=%0d, got trap_taken=%b cause=%0d epc=0x%08h",
                     desc, expected_cause, tr.trap_taken, tr.trap_cause, tr.pc);
            test_errors++;
        end
        har_assert_csr(CSR_MEPC, expected_epc, $sformatf("%s (MEPC check)", desc));
        har_assert_csr(CSR_MTVAL, expected_tval, $sformatf("%s (MTVAL check)", desc));
    endtask

    // -------------------------------------------------------------------------
    // 5. Unit Test Suite Instantiations
    // -------------------------------------------------------------------------
    tb_isa_alu    u_test_alu();
    tb_isa_bru    u_test_bru();
    tb_isa_muldiv u_test_muldiv();
    tb_isa_lsu    u_test_lsu();
    tb_isa_system u_test_system();

    // -------------------------------------------------------------------------
    // 6. Main Test Runner
    // -------------------------------------------------------------------------
    initial begin
        rst_n             = 1'b0;
        meip              = 1'b0;
        mtip              = 1'b0;
        msip              = 1'b0;
        har_reg_req       = '0;
        har_mem_req_valid = 1'b0;
        har_mem_req_write = 1'b0;
        har_mem_req_addr  = '0;
        har_mem_req_wdata = '0;
        har_mem_req_wstrb = 4'b1111;

        $display("================================================================");
        $display("  processor-complex: M1 Core Verification Harness (tb_core)     ");
        $display("================================================================");

        // Reset sequence
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);

        // Run directed unit tests if selected or by default
        if ($test$plusargs("test_alu") || $test$plusargs("test_all")) begin
            u_test_alu.run_all();
        end
        if ($test$plusargs("test_bru") || $test$plusargs("test_all")) begin
            u_test_bru.run_all();
        end
        if ($test$plusargs("test_muldiv") || $test$plusargs("test_all")) begin
            u_test_muldiv.run_all();
        end
        if ($test$plusargs("test_lsu") || $test$plusargs("test_all")) begin
            u_test_lsu.run_all();
        end
        if ($test$plusargs("test_system") || $test$plusargs("test_all")) begin
            u_test_system.run_all();
        end

        // Final summary
        repeat (20) @(posedge clk);
        $display("----------------------------------------------------------------");
        if (test_errors == 0) begin
            $display("[SUCCESS] All executed verification tests PASSED with 0 errors!");
        end else begin
            $display("[FAILURE] %0d error(s) detected during verification run!", test_errors);
        end
        $display("================================================================");
        $finish(test_errors == 0 ? 0 : 1);
    end

    // Simulation watchdog (100 us timeout)
    initial begin
        #100_000;
        $display("[ERROR] tb_core timed out after 100 us!");
        $finish(2);
    end

endmodule : tb_core
