`timescale 1ns / 1ps
// =============================================================================
// File:        sim/tb_core.sv
// Module:      tb_core
// Project:     processor-complex
// Milestone:   M1 (Scalar RV32IM + Zicsr/Zifencei Core Skeleton)
//
// Description:
//   Self-contained Verification & Co-Simulation Testbench for `core.sv` and
//   the M1 memory subsystem (`soc_xbar.sv`, `boot_rom.sv`, `axi_bram_mem.sv`).
//
//   What This Testbench Verifies in M1:
//     1. Executes all 40 `rv32ui-p-*` and 8 `rv32um-p-*` ISA compliance tests
//        from `sw/tests/riscv-tests/isa/`.
//     2. Supports runtime hex loading into `axi_bram_mem` (`0x8000_0000`) via
//        `+mem_hex=<path/to/test.hex>`.
//     3. Monitors memory writes to the `riscv-tests` `tohost` address
//        (`0x8000_1000`, configurable via `+tohost_addr=<hex>`):
//          - `wdata == 32'd1`: Test **PASSED** (`$finish(0)`).
//          - `wdata >  32'd1`: Test **FAILED** at test case `wdata >> 1`
//            (`$fatal(1)`).
//     4. Logs every retired instruction from `commit_trace_o` (`pc`, `insn`,
//        `rd_addr`, `rd_wdata`, `mem_addr`, `mem_wdata`, `trap_cause`) to a
//        trace file (`+trace_log=<path>`) for automated lockstep comparison
//        against Spike (`spike --isa=rv32im_zicsr_zifencei_zicntr -l --log-commits`).
//
// Connections:
//   - Instantiates:
//       * `core` (`u_core`) with `RESET_PC = 32'h8000_0000` (or `0x0000_1000`
//         via Boot ROM trampoline)
//       * `soc_xbar` (`u_soc_xbar`)
//       * `boot_rom` (`u_boot_rom`)
//       * `axi_bram_mem` (`u_main_mem`)
//
// What Needs to Be Implemented:
//   1. Instantiate `core`, `soc_xbar`, `boot_rom`, and `axi_bram_mem`.
//   2. Implement clock/reset generation, `tohost` write detection monitor,
//      retirement trace logger (`+trace_log`), and watchdog timeout.
// =============================================================================

module tb_core
    import soc_pkg::*;
    import cbus_pkg::*;
    import rv_pkg::*;
    import core_pkg::*;
;

    // -------------------------------------------------------------------------
    // TODO:
    //   Instantiate `core`, `soc_xbar`, `boot_rom`, and `axi_bram_mem`;
    //   implement `tohost` pass/fail monitor and Spike commit-trace logger.
    // -------------------------------------------------------------------------

endmodule : tb_core

