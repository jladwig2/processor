`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/common/sync_2ff.sv
// Module:      sync_2ff
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Parameterized 2-Flip-Flop Single-Bit / Multi-Bit Metastability Synchronizer.
//
//   Why This Module Exists:
//     - External board pins such as slide switches (`sw_i`), pushbuttons
//       (`btn_i`), UART serial receive (`rx_i`), and PS/2 lines (`ps2_clk_i`,
//       `ps2_data_i`) change state completely asynchronously to `clk_i`.
//     - Sampling an asynchronous signal directly in logic or FSMs can violate
//       setup/hold times, causing flip-flops to enter a metastable state or
//       fan out inconsistent logic levels to different branches of a circuit.
//     - Passing the signal through two back-to-back flip-flops marked with
//       Xilinx's `(* ASYNC_REG = "TRUE" *)` synthesis attribute places both
//       flops in the same slice to maximize Mean Time Between Failures (MTBF).
//
//   Note on Multi-Bit Usage:
//     - `WIDTH > 1` is intended for independent asynchronous status/input pins
//       (such as the 16 slide switches or 4 pushbuttons), NOT for multi-bit
//       binary counters or buses crossing clock domains (use `async_fifo.sv` or
//       Gray-coded pointers for multi-bit coherent CDC).
//
// Connections:
//   - Instantiated by:
//       * `gpio.sv`     (`rtl/periph/gpio.sv`): Synchronizes `sw_i[N_SW-1:0]`.
//       * `debounce.sv` (`rtl/common/debounce.sv`): Synchronizes raw `btn_i`
//         before glitch-filtering counters.
//       * `uart.sv`     (`rtl/periph/uart.sv`): Synchronizes `rx_i` with
//         `RESET_VAL = 1'b1` (UART line idle high).
// =============================================================================

module sync_2ff #(
    parameter int unsigned WIDTH     = 1,
    parameter bit          RESET_VAL = 1'b0
) (
    input  logic             clk_i,
    input  logic             rst_n_i,
    input  logic [WIDTH-1:0] async_i,
    output logic [WIDTH-1:0] sync_o
);

    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] stage1_q;
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] stage2_q;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            stage1_q <= {WIDTH{RESET_VAL}};
            stage2_q <= {WIDTH{RESET_VAL}};
        end else begin
            stage1_q <= async_i;
            stage2_q <= stage1_q;
        end
    end

    assign sync_o = stage2_q;

endmodule : sync_2ff

