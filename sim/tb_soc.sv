`timescale 1ns / 1ps
// =============================================================================
// File:        sim/tb_soc.sv
// Module:      tb_soc
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Top-level simulation testbench for `top_basys3` / `soc`.
//
//   In Milestone 0, this testbench verifies the end-to-end hardware bring-up
//   path:
//     1. Generates the 100 MHz system clock (`clk`) and pulses the dedicated
//        active-high reset button (`btnC`).
//     2. Verifies `clk_rst_gen` and `reset_sync` release `rst_core_n` cleanly
//        after the reset stretch period.
//     3. Drives a sequence of patterns onto the 16 slide switches (`sw[15:0]`)
//        and verifies that the M0 Switch-to-LED Master FSM inside `soc.sv`
//        reads `GPIO_REG_SW` (`0x1000_1004`) over `cbus` -> `cbus2apb` ->
//        `apb_decoder` -> `gpio` and writes the sampled switch state back to
//        `GPIO_REG_LED` (`0x1000_1000`), causing `led[15:0]` to match
//        `sw[15:0]`.
//     4. Exercises `btnU/L/R/D` and `RsRx` to verify debouncing, 7-segment
//        anode scanning, and UART framing once those peripheral internals are
//        implemented.
//
// Connections:
//   - Instantiates `top_basys3` (`u_dut`) from `rtl/top/top_basys3.sv`.
// =============================================================================

module tb_soc;

    // 100 MHz clock (10 ns period)
    logic        clk;
    initial      clk = 1'b0;
    always #5.0  clk = ~clk;

    // Board stimulus and observed outputs
    logic        btnC;
    logic        btnU;
    logic        btnL;
    logic        btnR;
    logic        btnD;
    logic [15:0] sw;
    logic [15:0] led;
    logic [6:0]  seg;
    logic        dp;
    logic [3:0]  an;
    logic        RsRx = 1'b1;
    logic        RsTx;
    logic        QspiCSn;
    tri   [3:0]  QspiDB;
    tri          PS2Clk;
    tri          PS2Data;

    // -------------------------------------------------------------------------
    // Device Under Test (top_basys3)
    // -------------------------------------------------------------------------
    top_basys3 u_dut (
        .clk     (clk),
        .btnC    (btnC),
        .btnU    (btnU),
        .btnL    (btnL),
        .btnR    (btnR),
        .btnD    (btnD),
        .sw      (sw),
        .led     (led),
        .seg     (seg),
        .dp      (dp),
        .an      (an),
        .RsRx    (RsRx),
        .RsTx    (RsTx),
        .QspiCSn (QspiCSn),
        .QspiDB  (QspiDB),
        .PS2Clk  (PS2Clk),
        .PS2Data (PS2Data)
    );

    // -------------------------------------------------------------------------
    // Test Sequence & Verification
    // -------------------------------------------------------------------------
    int unsigned errors = 0;

    task automatic check_led(input logic [15:0] expected_val, input string desc);
        // Allow up to 30 clock cycles (~300 ns) for 2-FF sync + APB master FSM latency
        repeat (30) @(posedge clk);
        if (led === expected_val) begin
            $display("[PASS] %s: sw=0x%04h -> led=0x%04h (matched)", desc, sw, led);
        end else begin
            $display("[FAIL] %s: sw=0x%04h -> expected led=0x%04h, got led=0x%04h",
                     desc, sw, expected_val, led);
            errors++;
        end
    endtask

    initial begin
        $display("================================================================");
        $display("  processor-complex: M0 Top-Level Bring-Up Simulation (tb_soc)  ");
        $display("  Target: Digilent Basys 3 (XC7A35T-1CPG236C)                   ");
        $display("================================================================");

        // Optional VCD dump for waveform viewing
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_soc.vcd");
            $dumpvars(0, tb_soc);
        end

        // Step 1: Initial state and reset assertion
        btnC = 1'b1;
        sw   = 16'h0000;
        btnU = 1'b0;
        btnL = 1'b0;
        btnR = 1'b0;
        btnD = 1'b0;
        RsRx = 1'b1;

        $display("[INFO] Asserting hardware reset (btnC=1)...");
        repeat (10) @(posedge clk);

        // Step 2: Deassert reset and wait for reset_sync stretch (64 cycles)
        $display("[INFO] Deasserting hardware reset (btnC=0), awaiting stretch release...");
        btnC = 1'b0;
        repeat (80) @(posedge clk);

        // Verify initial state
        check_led(16'h0000, "Initial state (all switches OFF)");

        // Step 3: Pattern 1 - Alternating 0xA5A5
        $display("[INFO] Applying Pattern 1: 0xA5A5");
        sw = 16'hA5A5;
        check_led(16'hA5A5, "Pattern 1 (0xA5A5)");

        // Step 4: Pattern 2 - Inverted 0x5A5A
        $display("[INFO] Applying Pattern 2: 0x5A5A");
        sw = 16'h5A5A;
        check_led(16'h5A5A, "Pattern 2 (0x5A5A)");

        // Step 5: Pattern 3 - All switches ON 0xFFFF
        $display("[INFO] Applying Pattern 3: 0xFFFF");
        sw = 16'hFFFF;
        check_led(16'hFFFF, "Pattern 3 (0xFFFF)");

        // Step 6: Pattern 4 - Walking 1s across all 16 channels
        $display("[INFO] Applying Pattern 4: Walking 1s across 16 switch/LED channels");
        for (int i = 0; i < 16; i++) begin
            sw = 16'h0001 << i;
            check_led(16'h0001 << i, $sformatf("Walking 1 bit %0d", i));
        end

        // Step 7: Return to all OFF
        $display("[INFO] Returning to all switches OFF (0x0000)");
        sw = 16'h0000;
        check_led(16'h0000, "Final state (all OFF)");

        // Summary
        $display("----------------------------------------------------------------");
        if (errors == 0) begin
            $display("[SUCCESS] All M0 switch-to-LED tests PASSED without errors!");
            $display("================================================================");
            $finish(0);
        end else begin
            $display("[FAILURE] %0d error(s) detected during M0 bring-up test!", errors);
            $display("================================================================");
            $fatal(1);
        end
    end

    // Simulation watchdog (50 microseconds timeout)
    initial begin
        #50_000; // 50 us
        $display("[ERROR] Simulation timed out after 50 us!");
        $fatal(2);
    end

endmodule : tb_soc

