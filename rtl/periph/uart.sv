`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/periph/uart.sv
// Module:      uart
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Full-duplex Universal Asynchronous Receiver/Transmitter (8 data bits, no
//   parity, 1 stop bit — 8N1) APB peripheral mapped at base address
//   `0x1000_0000` (`UART0_BASE` in `soc_pkg.sv`).
//
//   Key Features:
//     1. Buffered TX and RX paths using two 16-entry × 8-bit synchronous FIFOs
//        (`fifo.sv` in `rtl/common/fifo.sv`).
//     2. Runtime-programmable fractional/integer baud rate divider register
//        (`UART_REG_BAUDDIV`), initialized on reset to
//        `CORE_CLK_HZ / DEFAULT_BAUD` (100 cycles/bit for 1 Mbaud at 100 MHz).
//     3. Double-flop synchronizer (`sync_2ff.sv`) on the asynchronous `rx_i`
//        serial input pin, with mid-bit sampling and start-bit glitch rejection.
//     4. Separate PLIC interrupt outputs for RX data available (`irq_rx_o`,
//        PLIC ID 1) and TX FIFO empty (`irq_tx_o`, PLIC ID 2).
//     5. Non-destructive status inspection via `UART_REG_STATUS` and side-effect
//        pop on reading `UART_REG_RXDATA` (which is why MMIO loads execute
//        non-speculatively at the ROB head in the OoO core).
//
//   Register Map (Byte offsets relative to `0x1000_0000`):
//     - `0x000` (`UART_REG_TXDATA`,  WO):
//         * Bits [7:0]: Byte to push into the TX FIFO (ignored if `tx_full`).
//     - `0x004` (`UART_REG_RXDATA`,  RO):
//         * Bits [7:0]: Oldest received byte popped from the RX FIFO (`8'h00` if
//                       empty).
//         * Bit [31]:   `rx_empty` (1 = no byte was available, 0 = valid byte
//                       popped on this read).
//     - `0x008` (`UART_REG_STATUS`,  RO, W1C on bit [3]):
//         * Bit [0]:    `tx_full`    (1 = TX FIFO is full)
//         * Bit [1]:    `tx_empty`   (1 = TX FIFO is empty AND TX shifter idle)
//         * Bit [2]:    `rx_empty`   (1 = RX FIFO is empty)
//         * Bit [3]:    `rx_overrun` (1 = byte arrived while RX FIFO was full;
//                                     Write-1-to-Clear)
//     - `0x00C` (`UART_REG_CTRL`,    RW):
//         * Bit [0]:    `rx_irq_en`       (Enable `irq_rx_o` when `!rx_empty`)
//         * Bit [1]:    `tx_empty_irq_en` (Enable `irq_tx_o` when `tx_empty`)
//     - `0x010` (`UART_REG_BAUDDIV`, RW):
//         * Bits [19:0]: Clock cycles per bit period (minimum 4; reset value =
//                        `CORE_CLK_HZ / DEFAULT_BAUD`).
//
// Connections:
//   - Instantiated by: `soc.sv` (`u_uart`).
//   - APB Slave Port:
//       * `apb_req_i` / `apb_rsp_o` <- `apb_decoder.sv` (`s_uart_req_o` / `s_uart_rsp_i`)
//   - External Board Pins (via `soc.sv` <-> `top_basys3.sv`):
//       * `rx_i` <- `uart_rx_i` <- `RsRx` (Pin B18 on Basys 3)
//       * `tx_o` -> `uart_tx_o` -> `RsTx` (Pin A18 on Basys 3)
//   - Interrupt Outputs (to `plic.sv` in M2):
//       * `irq_rx_o` -> PLIC source ID 1 (`IRQ_UART0_RX`)
//       * `irq_tx_o` -> PLIC source ID 2 (`IRQ_UART0_TX`)
//   - Child Modules to Instantiate:
//       * `sync_2ff #(.WIDTH(1), .RESET_VAL(1'b1))` (`rtl/common/sync_2ff.sv`)
//         for `rx_i`.
//       * Two instances of `fifo #(.DATA_WIDTH(8), .DEPTH(FIFO_DEPTH))`
//         (`rtl/common/fifo.sv`) for the TX and RX queues.
//
// What Needs to Be Implemented:
//   1. Instantiate `sync_2ff` on `rx_i`, `u_tx_fifo`, and `u_rx_fifo`.
//   2. Implement the TX serializer FSM (`TX_IDLE -> TX_START -> TX_DATA[0..7]
//      -> TX_STOP`), popping one byte from `u_tx_fifo` whenever idle and
//      `!tx_fifo_empty`, stepping every `bauddiv_q` cycles.
//   3. Implement the RX deserializer FSM (`RX_IDLE -> RX_START_HALF ->
//      RX_DATA[0..7] -> RX_STOP`), detecting the falling edge of `rx_sync`,
//      verifying `rx_sync == 0` at `bauddiv_q / 2`, sampling 8 data bits spaced
//      by `bauddiv_q` cycles, and pushing into `u_rx_fifo` (or setting
//      `rx_overrun_q` if `rx_fifo_full`).
//   4. Implement the APB register interface (`TXDATA` push, `RXDATA` pop on
//      `psel & penable & !pwrite`, `STATUS`, `CTRL`, `BAUDDIV`).
// =============================================================================

module uart
    import soc_pkg::*;
#(
    parameter int unsigned CORE_CLK_HZ  = 100_000_000,
    parameter int unsigned DEFAULT_BAUD = 1_000_000,
    parameter int unsigned FIFO_DEPTH   = 16
) (
    input  logic     clk_i,
    input  logic     rst_n_i,

    // APB Slave Interface (from apb_decoder, Slot 0 @ 0x1000_0000)
    input  apb_req_t apb_req_i,
    output apb_rsp_t apb_rsp_o,

    // Serial RX/TX Signals (from/to FT2232H USB-UART bridge via soc/top_basys3)
    input  logic     rx_i,
    output logic     tx_o,

    // Interrupt Lines to PLIC (ID 1 = RX not empty, ID 2 = TX empty)
    output logic     irq_rx_o,
    output logic     irq_tx_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   1. Instantiate `sync_2ff` (`u_rx_sync`), `fifo` (`u_tx_fifo`), and
    //      `fifo` (`u_rx_fifo`).
    //   2. Implement TX serializer FSM, RX deserializer FSM, and APB register
    //      read/write logic.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs (replace when implementing UART)
    assign apb_rsp_o.prdata  = 32'h0;
    assign apb_rsp_o.pready  = 1'b1;
    assign apb_rsp_o.pslverr = 1'b0;
    assign tx_o      = 1'b1; // UART idle high
    assign irq_rx_o  = 1'b0;
    assign irq_tx_o  = 1'b0;

endmodule : uart

