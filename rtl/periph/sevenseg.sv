`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/periph/sevenseg.sv
// Module:      sevenseg
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   4-Digit Multiplexed 7-Segment Display Controller APB peripheral mapped at
//   base address `0x1000_2000` (`SEVENSEG_BASE` in `soc_pkg.sv`).
//
//   Hardware Interface (Digilent Basys 3 Common-Anode Display):
//     - All 4 digits share 7 segment cathode pins (`seg_o[6:0]` = `{CG..CA}`)
//       and 1 decimal-point cathode pin (`dp_o`).
//     - Each digit has its own PNP transistor anode enable (`an_o[3:0]`).
//     - Both anodes (`an_o`) and cathodes (`seg_o`, `dp_o`) are **active-low**:
//       driving `an_o[d] = 1'b0` and `seg_o[s] = 1'b0` illuminates segment `s`
//       on digit `d`.
//     - To display 4 independent digits simultaneously without flicker, this
//       module time-multiplexes the 4 digits in hardware at ~1 kHz (~250 Hz
//       full-display refresh rate, i.e., ~25,000 cycles per digit at 100 MHz).
//
//   Register Map (Byte offsets relative to `0x1000_2000`):
//     - `0x000` (`SEG_REG_CTRL`, RW):
//         * Bit [0]:     `enable` (1 = display active, 0 = all anodes blanked;
//                        defaults to `1'b1` on reset so M0/boot diagnostics
//                        appear immediately).
//         * Bit [1]:     `raw_mode` (0 = decode 4-bit hex nibbles from
//                        `SEG_REG_HEX`, 1 = drive raw segment patterns from
//                        `SEG_REG_RAW`).
//         * Bits [11:8]: `brightness` (4-bit PWM duty cycle `0x0..0xF`, default
//                        `4'hF` = 100% duty cycle within each anode time slot).
//     - `0x004` (`SEG_REG_HEX`,  RW):
//         * Bits [15:0]: Four 4-bit hexadecimal nibbles `{digit3, digit2,
//                        digit1, digit0}` decoded into 7-segment patterns
//                        (`0..9, A..F`) when `raw_mode == 0`.
//     - `0x008` (`SEG_REG_DP`,   RW):
//         * Bits [3:0]:  Per-digit decimal point enable (`1` = decimal point
//                        illuminated on that digit, `0` = off) used in hex mode.
//     - `0x00C` (`SEG_REG_RAW`,  RW):
//         * Bits [31:0]: Four 8-bit raw active-high segment masks
//                        `{raw_digit3, raw_digit2, raw_digit1, raw_digit0}`,
//                        where each byte is `{dp, g, f, e, d, c, b, a}` (`1` =
//                        illuminated). Inverted at the output pin driver.
//
// Connections:
//   - Instantiated by: `soc.sv` (`u_sevenseg`, inside `if (HAS_SEVENSEG)`).
//   - APB Slave Port:
//       * `apb_req_i` / `apb_rsp_o` <- `apb_decoder.sv` (`s_sevenseg_req_o` / `s_sevenseg_rsp_i`)
//   - External Board Pins (via `soc.sv` <-> `top_basys3.sv`):
//       * `seg_o[6:0]` -> `sevenseg_seg_o` -> `seg[6:0]`
//       * `dp_o`       -> `sevenseg_dp_o`  -> `dp`
//       * `an_o[3:0]`  -> `sevenseg_an_o`  -> `an[3:0]`
//
// What Needs to Be Implemented:
//   1. Implement the APB configuration registers (`ctrl_q`, `hex_q`, `dp_q`,
//      `raw_q`) and read/write decoder (`pready = 1'b1`, `pslverr = 1'b0`).
//   2. Implement a free-running refresh counter dividing `CORE_CLK_HZ` down to
//      a 2-bit digit selector `digit_sel[1:0]` (~1 kHz per digit) and a 4-bit
//      sub-slot PWM counter compared against `ctrl_q[11:8]` (`brightness`).
//   3. Implement the 4-bit hex-to-7-segment lookup table (`0..F` -> active-low
//      `seg_o[6:0]`) and mux between hex mode (`raw_mode == 0`) and raw mode
//      (`raw_mode == 1`).
//   4. Drive active-low `an_o[3:0]`, `seg_o[6:0]`, and `dp_o`.
// =============================================================================

module sevenseg
    import soc_pkg::*;
#(
    parameter int unsigned CORE_CLK_HZ     = 100_000_000,
    parameter int unsigned REFRESH_RATE_HZ = 1000
) (
    input  logic       clk_i,
    input  logic       rst_n_i,

    // APB Slave Interface (from apb_decoder, Slot 2 @ 0x1000_2000)
    input  apb_req_t   apb_req_i,
    output apb_rsp_t   apb_rsp_o,

    // Active-Low 7-Segment Display Pins (to top_basys3 via soc)
    output logic [6:0] seg_o,
    output logic       dp_o,
    output logic [3:0] an_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Implement APB registers (`ctrl_q`, `hex_q`, `dp_q`, `raw_q`).
    //   2. Implement anode multiplexing counter, PWM brightness comparator, and
    //      hex-to-7-segment decoder.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs (replace when implementing Seven-Segment Display)
    assign apb_rsp_o.prdata  = 32'h0;
    assign apb_rsp_o.pready  = 1'b1;
    assign apb_rsp_o.pslverr = 1'b0;
    assign seg_o     = 7'b111_1111; // Active-low segments off
    assign dp_o      = 1'b1;        // Active-low decimal point off
    assign an_o      = 4'b1111;     // Active-low anodes off

endmodule : sevenseg

