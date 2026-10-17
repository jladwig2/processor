`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/top/clk_rst_gen.sv
// Module:      clk_rst_gen
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Clock and Reset Generator for the SoC. Takes the raw external board
//   oscillator (`clk_board_i`), the raw asynchronous reset button
//   (`rst_btn_i`, active-high `btnC` on Basys 3), and a software warm-reset
//   request pulse (`soft_rst_req_i` from `sysctrl.sv`), and produces:
//     - `clk_core_o`:   Buffered system clock driving the cores, caches,
//                       interconnect, and APB peripherals.
//     - `rst_core_n_o`: Clean active-low reset synchronized to `clk_core_o`
//                       and stretched for a minimum hold window so all BRAMs,
//                       FIFOs, and state machines reset deterministically.
//     - `pll_locked_o`: Status flag indicating clock synthesizer lock.
//
// Connections:
//   - Instantiated by: `top_basys3.sv` (and later `top_arty_a7.sv`).
//   - Upstream inputs:
//       * `clk_board_i`    <- Board oscillator pin (`clk` in `top_basys3.sv`).
//       * `rst_btn_i`      <- Dedicated reset button (`btnC` in `top_basys3.sv`).
//       * `soft_rst_req_i` <- `soc.sv` <- `sysctrl.sv` (`SYS_REG_RESET` write).
//   - Downstream outputs:
//       * `clk_core_o`     -> `soc.sv` (`clk_i`)
//       * `rst_core_n_o`   -> `soc.sv` (`rst_n_i`)
//   - Child modules:
//       * `reset_sync` (`rtl/common/reset_sync.sv`) for asynchronous reset
//         assertion, synchronous deassertion, and reset pulse stretching.
//       * Optional Xilinx `MMCME2_BASE` when `BOARD_OSC_HZ != CORE_CLK_HZ`.
// =============================================================================

module clk_rst_gen #(
    parameter int unsigned BOARD_OSC_HZ = 100_000_000,
    parameter int unsigned CORE_CLK_HZ  = 100_000_000,
    parameter int unsigned RST_STRETCH_CYCLES = 64
) (
    // Raw board clock input (100 MHz on Basys 3)
    input  logic clk_board_i,

    // Raw asynchronous active-high reset pushbutton input (btnC on Basys 3)
    input  logic rst_btn_i,

    // Synchronous active-high warm reset request from `sysctrl` peripheral
    input  logic soft_rst_req_i,

    // Generated core clock output
    output logic clk_core_o,

    // Synchronized, stretched active-low core reset output
    output logic rst_core_n_o,

    // Clock synthesizer lock indicator (1 = clock stable)
    output logic pll_locked_o
);

    // For 100 MHz bring-up (BOARD_OSC_HZ == CORE_CLK_HZ), pass board clock directly.
    // MMCM frequency synthesizer can be wrapped here when scaling frequency.
    assign clk_core_o   = clk_board_i;
    assign pll_locked_o = 1'b1;

    wire rst_combined_async = rst_btn_i | soft_rst_req_i | (~pll_locked_o);

    reset_sync #(
        .STRETCH_CYCLES (RST_STRETCH_CYCLES)
    ) u_reset_sync (
        .clk_i       (clk_core_o),
        .rst_async_i (rst_combined_async),
        .rst_n_o     (rst_core_n_o)
    );

endmodule : clk_rst_gen

