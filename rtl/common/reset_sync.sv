`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/common/reset_sync.sv
// Module:      reset_sync
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Asynchronous-Assert, Synchronous-Deassert Reset Bridge with an optional
//   hold/stretch counter.
//
//   Why This Module Exists:
//     - External reset buttons (`btnC` on Basys 3) and PLL/MMCM lock drops can
//       occur asynchronously to `clk_i`. Feeding a raw asynchronous signal into
//       synchronous state machines or BRAM control logic risks metastability
//       and partial reset release across the chip on the deassertion edge.
//     - By using an asynchronous preset (`posedge rst_async_i`) on a 2-stage
//       (`ASYNC_REG = "TRUE"`) shift register that shifts in `0` on `posedge
//       clk_i`, reset assertion is immediate even if the clock is startup-
//       gated, while reset deassertion is guaranteed synchronous to `clk_i`.
//     - Furthermore, the stretch counter holds `rst_n_o` low for at least
//       `STRETCH_CYCLES` clock cycles after the asynchronous reset releases,
//       filtering contact bounce on `btnC` and ensuring multi-cycle pipelines
//       and FIFOs flush completely.
//
// Connections:
//   - Instantiated by: `clk_rst_gen.sv` (`rtl/top/clk_rst_gen.sv`).
//   - Inputs:
//       * `clk_i`       <- Core clock (`clk_core_o` in `clk_rst_gen`).
//       * `rst_async_i` <- Active-high combined reset (`rst_btn_i | soft_rst_req_i | ~pll_locked_o`).
//   - Outputs:
//       * `rst_n_o`     -> `rst_core_n_o` driving `soc.sv` and all synchronous
//                          logic in the `clk_core` domain.
// =============================================================================

module reset_sync #(
    parameter int unsigned STRETCH_CYCLES = 64
) (
    input  logic clk_i,
    input  logic rst_async_i, // Active-high asynchronous reset input
    output logic rst_n_o      // Active-low synchronous reset output
);

    (* ASYNC_REG = "TRUE" *) logic [1:0] sync_q;

    always_ff @(posedge clk_i or posedge rst_async_i) begin
        if (rst_async_i) begin
            sync_q <= 2'b11;
        end else begin
            sync_q <= {sync_q[0], 1'b0};
        end
    end

    generate
        if (STRETCH_CYCLES > 1) begin : g_stretch
            localparam int unsigned CNT_W = $clog2(STRETCH_CYCLES);
            logic [CNT_W-1:0] count_q;
            logic rst_n_q;

            always_ff @(posedge clk_i or posedge rst_async_i) begin
                if (rst_async_i) begin
                    count_q <= '0;
                    rst_n_q <= 1'b0;
                end else if (sync_q[1]) begin
                    count_q <= '0;
                    rst_n_q <= 1'b0;
                end else if (count_q == (CNT_W)'(STRETCH_CYCLES - 1)) begin
                    rst_n_q <= 1'b1;
                end else begin
                    count_q <= count_q + 1'b1;
                    rst_n_q <= 1'b0;
                end
            end

            assign rst_n_o = rst_n_q;
        end else begin : g_no_stretch
            assign rst_n_o = ~sync_q[1];
        end
    endgenerate

endmodule : reset_sync

