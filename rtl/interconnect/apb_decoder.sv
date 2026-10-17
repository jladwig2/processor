`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/interconnect/apb_decoder.sv
// Module:      apb_decoder
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Combinational AMBA APB address decoder and response multiplexer for the
//   64 KB MMIO peripheral window (`0x1000_0000 .. 0x1000_FFFF`).
//
//   How Decoding Works:
//     - Each peripheral occupies a 4 KB page (`0x1000` bytes, bits [11:0]).
//     - Bits [31:16] must equal `16'h1000` (the MMIO window base).
//     - Bits [15:12] select which 4 KB peripheral slot is targeted (`apb_slot_e`
//       in `soc_pkg.sv`):
//         * `4'h0` (`0x1000_0000`): UART0          (`s_uart_req_o` / `s_uart_rsp_i`)
//         * `4'h1` (`0x1000_1000`): GPIO           (`s_gpio_req_o` / `s_gpio_rsp_i`)
//         * `4'h2` (`0x1000_2000`): 7-Segment      (`s_sevenseg_req_o` / `s_sevenseg_rsp_i`)
//         * `4'h3` (`0x1000_3000`): QSPI Ctrl      (`s_qspi_req_o` / `s_qspi_rsp_i`)
//         * `4'h4` (`0x1000_4000`): PS/2 HID       (`s_ps2_req_o` / `s_ps2_rsp_i`)
//         * `4'hF` (`0x1000_F000`): System Control (`s_sysctrl_req_o` / `s_sysctrl_rsp_i`)
//     - All shared APB request fields (`paddr`, `penable`, `pwrite`, `pwdata`,
//       `pstrb`) are broadcast to every slave port, while `psel` is asserted
//       ONLY on the decoded target slave when `m_apb_req_i.psel` is high.
//     - If `m_apb_req_i.psel` is asserted for an unmapped slot (or a disabled
//       peripheral, e.g., when `HAS_SEVENSEG == 0`), `apb_decoder` immediately
//       returns a synthetic error response (`pready = 1'b1`, `pslverr = 1'b1`,
//       `prdata = 32'h0`) so the bus never hangs on an invalid MMIO address.
//
// Connections:
//   - Instantiated by: `soc.sv` (in `rtl/top/soc.sv`).
//   - Upstream Master Port:
//       * `m_apb_req_i` / `m_apb_rsp_o` <- `cbus2apb.sv`
//   - Downstream Slave Ports:
//       * `s_uart_req_o`     / `s_uart_rsp_i`     -> `uart.sv`
//       * `s_gpio_req_o`     / `s_gpio_rsp_i`     -> `gpio.sv`
//       * `s_sevenseg_req_o` / `s_sevenseg_rsp_i` -> `sevenseg.sv`
//       * `s_qspi_req_o`     / `s_qspi_rsp_i`     -> `qspi_ctrl.sv` (M2)
//       * `s_ps2_req_o`      / `s_ps2_rsp_i`      -> `ps2_hid.sv` (M2)
//       * `s_sysctrl_req_o`  / `s_sysctrl_rsp_i`  -> `sysctrl.sv`
// =============================================================================

module apb_decoder
    import soc_pkg::*;
#(
    parameter bit HAS_SEVENSEG = 1'b1,
    parameter bit HAS_PS2      = 1'b1
) (
    // Upstream APB Master Interface (from cbus2apb)
    input  apb_req_t m_apb_req_i,
    output apb_rsp_t m_apb_rsp_o,

    // Slot 0 (0x1000_0000): UART0
    output apb_req_t s_uart_req_o,
    input  apb_rsp_t s_uart_rsp_i,

    // Slot 1 (0x1000_1000): GPIO (LEDs, Switches, Buttons)
    output apb_req_t s_gpio_req_o,
    input  apb_rsp_t s_gpio_rsp_i,

    // Slot 2 (0x1000_2000): 7-Segment Display
    output apb_req_t s_sevenseg_req_o,
    input  apb_rsp_t s_sevenseg_rsp_i,

    // Slot 3 (0x1000_3000): QSPI Flash Controller
    output apb_req_t s_qspi_req_o,
    input  apb_rsp_t s_qspi_rsp_i,

    // Slot 4 (0x1000_4000): PS/2 USB-HID Controller
    output apb_req_t s_ps2_req_o,
    input  apb_rsp_t s_ps2_rsp_i,

    // Slot F (0x1000_F000): System Control (sysctrl)
    output apb_req_t s_sysctrl_req_o,
    input  apb_rsp_t s_sysctrl_rsp_i
);

    wire is_mmio_window = (m_apb_req_i.paddr[31:16] == 16'h1000);
    wire [3:0] slot_sel = m_apb_req_i.paddr[15:12];

    // Broadcast shared request fields and assert psel only for selected slot
    always_comb begin
        s_uart_req_o     = m_apb_req_i;
        s_gpio_req_o     = m_apb_req_i;
        s_sevenseg_req_o = m_apb_req_i;
        s_qspi_req_o     = m_apb_req_i;
        s_ps2_req_o      = m_apb_req_i;
        s_sysctrl_req_o  = m_apb_req_i;

        s_uart_req_o.psel     = 1'b0;
        s_gpio_req_o.psel     = 1'b0;
        s_sevenseg_req_o.psel = 1'b0;
        s_qspi_req_o.psel     = 1'b0;
        s_ps2_req_o.psel      = 1'b0;
        s_sysctrl_req_o.psel  = 1'b0;

        if (m_apb_req_i.psel && is_mmio_window) begin
            case (slot_sel)
                APB_SLOT_UART0:     s_uart_req_o.psel     = 1'b1;
                APB_SLOT_GPIO:      s_gpio_req_o.psel     = 1'b1;
                APB_SLOT_SEVENSEG:  s_sevenseg_req_o.psel = HAS_SEVENSEG;
                APB_SLOT_QSPI_CTRL: s_qspi_req_o.psel     = 1'b1;
                APB_SLOT_PS2_HID:   s_ps2_req_o.psel      = HAS_PS2;
                APB_SLOT_SYSCTRL:   s_sysctrl_req_o.psel  = 1'b1;
                default: ; // Unmapped slot: psel remains 0
            endcase
        end
    end

    // Multiplex response from selected slave back to master
    always_comb begin
        m_apb_rsp_o.prdata  = 32'h0;
        m_apb_rsp_o.pready  = 1'b1;
        m_apb_rsp_o.pslverr = 1'b1; // Default error for unmapped/out-of-window

        if (is_mmio_window) begin
            case (slot_sel)
                APB_SLOT_UART0:     m_apb_rsp_o = s_uart_rsp_i;
                APB_SLOT_GPIO:      m_apb_rsp_o = s_gpio_rsp_i;
                APB_SLOT_SEVENSEG:  if (HAS_SEVENSEG) m_apb_rsp_o = s_sevenseg_rsp_i;
                APB_SLOT_QSPI_CTRL: m_apb_rsp_o = s_qspi_rsp_i;
                APB_SLOT_PS2_HID:   if (HAS_PS2)      m_apb_rsp_o = s_ps2_rsp_i;
                APB_SLOT_SYSCTRL:   m_apb_rsp_o = s_sysctrl_rsp_i;
                default: begin
                    m_apb_rsp_o.prdata  = 32'h0;
                    m_apb_rsp_o.pready  = 1'b1;
                    m_apb_rsp_o.pslverr = 1'b1;
                end
            endcase
        end
    end

endmodule : apb_decoder

