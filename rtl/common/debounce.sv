`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/common/debounce.sv
// Module:      debounce
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Multi-Channel Mechanical Switch/Button Debouncer with built-in 2-FF
//   input synchronization.
//
//   Why This Module Exists:
//     - Physical pushbuttons on the Basys 3 (`btnU`, `btnL`, `btnR`, `btnD`)
//       exhibit mechanical contact bounce for ~1–5 ms when pressed or released,
//       producing dozens of rapid 0/1 transitions.
//     - Without hardware debouncing, a single button press would trigger
//       multiple edge interrupts in `gpio.sv` (`IRQ_GPIO_BTN`).
//
//   How It Works:
//     1. First passes `raw_i[WIDTH-1:0]` through `sync_2ff` (`rtl/common/sync_2ff.sv`)
//        to produce a synchronized signal `sync_in[WIDTH-1:0]`.
//     2. For each channel `ch` in `0 .. WIDTH-1`, compares `sync_in[ch]` against
//        the currently accepted stable output `clean_o[ch]`:
//          - If `sync_in[ch] == clean_o[ch]`, the input matches the stable state
//            and the channel's stability counter resets to `0`.
//          - If `sync_in[ch] != clean_o[ch]`, the channel's counter increments
//            each clock cycle. Only if the input remains continuously in the
//            new state for `STABLE_CYCLES` consecutive clock cycles (e.g.,
//            `1_000_000` cycles = 10 ms at 100 MHz, or a smaller value in RTL
//            simulation) does `clean_o[ch]` flip to `sync_in[ch]`.
//
// Connections:
//   - Instantiated by: `gpio.sv` (`rtl/periph/gpio.sv`) for `btn_i[N_BTN-1:0]`.
//   - Child module: `sync_2ff #(.WIDTH(WIDTH))` (`rtl/common/sync_2ff.sv`).
// =============================================================================

module debounce #(
    parameter int unsigned WIDTH         = 4,
    parameter int unsigned STABLE_CYCLES = 1_000_000 // 10 ms @ 100 MHz (override to e.g. 16 in testbenches)
) (
    input  logic             clk_i,
    input  logic             rst_n_i,
    input  logic [WIDTH-1:0] raw_i,
    output logic [WIDTH-1:0] clean_o
);

    logic [WIDTH-1:0] sync_in;

    sync_2ff #(
        .WIDTH     (WIDTH),
        .RESET_VAL (1'b0)
    ) u_sync (
        .clk_i   (clk_i),
        .rst_n_i (rst_n_i),
        .async_i (raw_i),
        .sync_o  (sync_in)
    );

    generate
        if (STABLE_CYCLES <= 1) begin : g_bypass
            assign clean_o = sync_in;
        end else begin : g_debounce
            localparam int unsigned CNT_W = $clog2(STABLE_CYCLES);
            logic [CNT_W-1:0] count_q [WIDTH];
            logic [WIDTH-1:0] clean_q;

            for (genvar ch = 0; ch < WIDTH; ch++) begin : gen_ch
                always_ff @(posedge clk_i or negedge rst_n_i) begin
                    if (!rst_n_i) begin
                        count_q[ch] <= '0;
                        clean_q[ch] <= 1'b0;
                    end else begin
                        if (sync_in[ch] == clean_q[ch]) begin
                            count_q[ch] <= '0;
                        end else if (count_q[ch] == (CNT_W)'(STABLE_CYCLES - 1)) begin
                            count_q[ch] <= '0;
                            clean_q[ch] <= sync_in[ch];
                        end else begin
                            count_q[ch] <= count_q[ch] + 1'b1;
                        end
                    end
                end
            end

            assign clean_o = clean_q;
        end
    endgenerate

endmodule : debounce

