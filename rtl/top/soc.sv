`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/top/soc.sv
// Module:      soc
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Board-agnostic System-on-Chip (SoC) container. `soc` encapsulates the
//   processors, memory hierarchy, interconnects, and MMIO peripherals behind a
//   parameterized, vendor-independent interface. Board wrappers (`top_basys3.sv`,
//   `top_arty_a7.sv`) simply connect their pins and clock/reset generators to
//   this module.
//
//   Architecture Across Milestones:
//     - In M0: Instead of the full RISC-V soft core, `soc`
//       hosts a lightweight hardware Bring-Up Master FSM (`m0_switch_led_fsm`)
//       that continuously issues `cbus` transactions through `cbus2apb` ->
//       `apb_decoder` -> `gpio`:
//         1. Read `GPIO_BASE + GPIO_REG_SW` (`0x1000_1004`) via a `CBUS_GET`
//            transaction to sample the 16 synchronized slide switches.
//         2. Write that 16-bit value to `GPIO_BASE + GPIO_REG_LED`
//            (`0x1000_1000`) via a `CBUS_PUT_FULL` transaction so closing
//            switch `i` turns on LED `i`.
//         3. Optionally mirror the lower 16 bits of the switches to
//            `SEVENSEG_BASE + SEG_REG_HEX` (`0x1000_2004`) so the 7-segment
//            display and APB address decoding across multiple slaves are also
//            verified end-to-end.
//     - In M1+: `core` instances (`rtl/core/core.sv`), `soc_xbar`, `l2_cache`,
//       `clint`, and `plic` replace the M0 test FSM on the upstream side of
//       `cbus2apb`.
//
// Connections:
//   - Instantiated by: `top_basys3.sv` (or `tb_soc.sv` in simulation).
//   - Internal M0 Data Path:
//       M0 Bring-Up FSM (`cbus_req_t` / `cbus_rsp_t`)
//         -> `cbus2apb` (`rtl/interconnect/cbus2apb.sv`)
//         -> `apb_decoder` (`rtl/interconnect/apb_decoder.sv`)
//         -> APB Peripheral Slaves:
//              * Slot 0 (`0x1000_0000`): `uart`     (`rtl/periph/uart.sv`)
//              * Slot 1 (`0x1000_1000`): `gpio`     (`rtl/periph/gpio.sv`)
//              * Slot 2 (`0x1000_2000`): `sevenseg` (`rtl/periph/sevenseg.sv`)
//              * Slot F (`0x1000_F000`): `sysctrl`  (`rtl/periph/sysctrl.sv`)
// =============================================================================

module soc
    import soc_pkg::*;
    import cbus_pkg::*;
#(
    parameter int unsigned N_CORES          = 1,
    parameter int unsigned CORE_CLK_HZ      = 100_000_000,
    parameter int unsigned DEFAULT_BAUD     = 1_000_000,
    parameter int unsigned N_LED            = 16,
    parameter int unsigned N_SW             = 16,
    parameter int unsigned N_BTN            = 4,
    parameter int unsigned N_RGB            = 0,
    parameter bit          HAS_SEVENSEG     = 1'b1,
    parameter bit          HAS_PS2          = 1'b1,
    parameter bit          HAS_ETH          = 1'b0,
    parameter bit          HAS_VECTOR       = 1'b0,
    parameter bit          HAS_MULDIV       = 1'b1,
    parameter bit          HAS_DEBUG        = 1'b1,
    parameter int unsigned BOOT_SW_IDX      = 15,
    parameter int unsigned MAIN_MEM_BYTES   = 96 * 1024,
    parameter logic [31:0] FLASH_FW_BASE    = 32'h0028_0000,
    parameter logic [31:0] FLASH_RW_BASE    = 32'h0038_0000
) (
    // System clock and synchronized active-low reset from `clk_rst_gen`
    input  logic                clk_i,
    input  logic                rst_n_i,

    // Warm reset request output back to `clk_rst_gen` (driven by `sysctrl`)
    output logic                soft_rst_req_o,

    // GPIO external interface (connected to board pins in `top_basys3`)
    input  logic [N_SW-1:0]     gpio_sw_i,
    input  logic [N_BTN-1:0]    gpio_btn_i,
    output logic [N_LED-1:0]    gpio_led_o,

    // 7-Segment external interface (active-low cathodes and anodes)
    output logic [6:0]          sevenseg_seg_o,
    output logic                sevenseg_dp_o,
    output logic [3:0]          sevenseg_an_o,

    // UART0 external interface
    input  logic                uart_rx_i,
    output logic                uart_tx_o,

    // QSPI Flash split tristate interface (SCK routed to STARTUPE2 in top)
    output logic                qspi_sck_o,
    output logic                qspi_cs_n_o,
    input  logic [3:0]          qspi_io_i,
    output logic [3:0]          qspi_io_o,
    output logic [3:0]          qspi_io_oe_o,

    // PS/2 USB-HID split tristate interface
    input  logic                ps2_clk_i,
    output logic                ps2_clk_o,
    output logic                ps2_clk_oe_o,
    input  logic                ps2_data_i,
    output logic                ps2_data_o,
    output logic                ps2_data_oe_o
);

    // -------------------------------------------------------------------------
    // 1. M0 Switch-to-LED Bring-Up Master FSM
    // -------------------------------------------------------------------------
    // Continuously reads the synchronized switch register from GPIO (0x1000_1004)
    // and writes that value back to the LED register (0x1000_1000) over cbus -> APB.
    typedef enum logic [1:0] {
        FSM_READ_SW_REQ    = 2'd0,
        FSM_READ_SW_WAIT   = 2'd1,
        FSM_WRITE_LED_REQ  = 2'd2,
        FSM_WRITE_LED_WAIT = 2'd3
    } fsm_state_e;

    fsm_state_e fsm_state_q, fsm_state_d;
    logic [31:0] sw_sample_q, sw_sample_d;

    logic      fsm_cbus_req_valid;
    wire       fsm_cbus_req_ready;
    cbus_req_t fsm_cbus_req;

    wire       fsm_cbus_rsp_valid;
    logic      fsm_cbus_rsp_ready;
    cbus_rsp_t fsm_cbus_rsp;

    always_comb begin
        fsm_state_d        = fsm_state_q;
        sw_sample_d        = sw_sample_q;
        fsm_cbus_req_valid = 1'b0;
        fsm_cbus_rsp_ready = 1'b0;

        fsm_cbus_req.opcode = CBUS_GET;
        fsm_cbus_req.addr   = GPIO_BASE + {20'b0, GPIO_REG_SW};
        fsm_cbus_req.wdata  = '0;
        fsm_cbus_req.wstrb  = 4'b1111;
        fsm_cbus_req.src_id = '0;

        case (fsm_state_q)
            FSM_READ_SW_REQ: begin
                fsm_cbus_req_valid  = 1'b1;
                fsm_cbus_req.opcode = CBUS_GET;
                fsm_cbus_req.addr   = GPIO_BASE + {20'b0, GPIO_REG_SW};
                if (fsm_cbus_req_ready) begin
                    fsm_state_d = FSM_READ_SW_WAIT;
                end
            end

            FSM_READ_SW_WAIT: begin
                fsm_cbus_rsp_ready = 1'b1;
                if (fsm_cbus_rsp_valid) begin
                    sw_sample_d = fsm_cbus_rsp.rdata;
                    fsm_state_d = FSM_WRITE_LED_REQ;
                end
            end

            FSM_WRITE_LED_REQ: begin
                fsm_cbus_req_valid  = 1'b1;
                fsm_cbus_req.opcode = CBUS_PUT_FULL;
                fsm_cbus_req.addr   = GPIO_BASE + {20'b0, GPIO_REG_LED};
                fsm_cbus_req.wdata  = sw_sample_q;
                fsm_cbus_req.wstrb  = 4'b1111;
                if (fsm_cbus_req_ready) begin
                    fsm_state_d = FSM_WRITE_LED_WAIT;
                end
            end

            FSM_WRITE_LED_WAIT: begin
                fsm_cbus_rsp_ready = 1'b1;
                if (fsm_cbus_rsp_valid) begin
                    fsm_state_d = FSM_READ_SW_REQ;
                end
            end

            default: fsm_state_d = FSM_READ_SW_REQ;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            fsm_state_q <= FSM_READ_SW_REQ;
            sw_sample_q <= '0;
        end else begin
            fsm_state_q <= fsm_state_d;
            sw_sample_q <= sw_sample_d;
        end
    end

    // -------------------------------------------------------------------------
    // 2. cbus to APB Bridge
    // -------------------------------------------------------------------------
    apb_req_t m_apb_req;
    apb_rsp_t m_apb_rsp;

    cbus2apb u_cbus2apb (
        .clk_i            (clk_i),
        .rst_n_i          (rst_n_i),
        .cbus_req_valid_i (fsm_cbus_req_valid),
        .cbus_req_ready_o (fsm_cbus_req_ready),
        .cbus_req_i       (fsm_cbus_req),
        .cbus_rsp_valid_o (fsm_cbus_rsp_valid),
        .cbus_rsp_ready_i (fsm_cbus_rsp_ready),
        .cbus_rsp_o       (fsm_cbus_rsp),
        .apb_req_o        (m_apb_req),
        .apb_rsp_i        (m_apb_rsp)
    );

    // -------------------------------------------------------------------------
    // 3. APB Address Decoder
    // -------------------------------------------------------------------------
    apb_req_t s_uart_req, s_gpio_req, s_sevenseg_req, s_qspi_req, s_ps2_req, s_sysctrl_req;
    apb_rsp_t s_uart_rsp, s_gpio_rsp, s_sevenseg_rsp, s_qspi_rsp, s_ps2_rsp, s_sysctrl_rsp;

    // Unimplemented M2 peripherals tied off gracefully
    assign s_qspi_rsp.prdata  = 32'h0;
    assign s_qspi_rsp.pready  = 1'b1;
    assign s_qspi_rsp.pslverr = 1'b1;

    assign s_ps2_rsp.prdata   = 32'h0;
    assign s_ps2_rsp.pready   = 1'b1;
    assign s_ps2_rsp.pslverr  = 1'b1;

    apb_decoder #(
        .HAS_SEVENSEG (HAS_SEVENSEG),
        .HAS_PS2      (HAS_PS2)
    ) u_apb_decoder (
        .m_apb_req_i      (m_apb_req),
        .m_apb_rsp_o      (m_apb_rsp),
        .s_uart_req_o     (s_uart_req),
        .s_uart_rsp_i     (s_uart_rsp),
        .s_gpio_req_o     (s_gpio_req),
        .s_gpio_rsp_i     (s_gpio_rsp),
        .s_sevenseg_req_o (s_sevenseg_req),
        .s_sevenseg_rsp_i (s_sevenseg_rsp),
        .s_qspi_req_o     (s_qspi_req),
        .s_qspi_rsp_i     (s_qspi_rsp),
        .s_ps2_req_o      (s_ps2_req),
        .s_ps2_rsp_i      (s_ps2_rsp),
        .s_sysctrl_req_o  (s_sysctrl_req),
        .s_sysctrl_rsp_i  (s_sysctrl_rsp)
    );

    // -------------------------------------------------------------------------
    // 4. Peripherals
    // -------------------------------------------------------------------------
    // GPIO (LEDs, Switches, Buttons)
    wire gpio_irq_btn, gpio_irq_sw;

    gpio #(
        .CORE_CLK_HZ (CORE_CLK_HZ),
        .N_LED       (N_LED),
        .N_SW        (N_SW),
        .N_BTN       (N_BTN),
        .N_RGB       (N_RGB)
    ) u_gpio (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .apb_req_i (s_gpio_req),
        .apb_rsp_o (s_gpio_rsp),
        .sw_i      (gpio_sw_i),
        .btn_i     (gpio_btn_i),
        .led_o     (gpio_led_o),
        .irq_btn_o (gpio_irq_btn),
        .irq_sw_o  (gpio_irq_sw)
    );

    // 7-Segment Display (Optional)
    generate
        if (HAS_SEVENSEG) begin : gen_sevenseg
            sevenseg #(
                .CORE_CLK_HZ (CORE_CLK_HZ)
            ) u_sevenseg (
                .clk_i     (clk_i),
                .rst_n_i   (rst_n_i),
                .apb_req_i (s_sevenseg_req),
                .apb_rsp_o (s_sevenseg_rsp),
                .seg_o     (sevenseg_seg_o),
                .dp_o      (sevenseg_dp_o),
                .an_o      (sevenseg_an_o)
            );
        end else begin : gen_no_sevenseg
            assign s_sevenseg_rsp.prdata  = 32'h0;
            assign s_sevenseg_rsp.pready  = 1'b1;
            assign s_sevenseg_rsp.pslverr = 1'b1;
            assign sevenseg_seg_o = 7'b111_1111;
            assign sevenseg_dp_o  = 1'b1;
            assign sevenseg_an_o  = 4'b1111;
        end
    endgenerate

    // UART0
    wire uart_irq_rx, uart_irq_tx;

    uart #(
        .CORE_CLK_HZ  (CORE_CLK_HZ),
        .DEFAULT_BAUD (DEFAULT_BAUD)
    ) u_uart (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .apb_req_i (s_uart_req),
        .apb_rsp_o (s_uart_rsp),
        .rx_i      (uart_rx_i),
        .tx_o      (uart_tx_o),
        .irq_rx_o  (uart_irq_rx),
        .irq_tx_o  (uart_irq_tx)
    );

    // System Control
    sysctrl #(
        .N_CORES        (N_CORES),
        .CORE_CLK_HZ    (CORE_CLK_HZ),
        .MAIN_MEM_BYTES (MAIN_MEM_BYTES),
        .HAS_MULDIV     (HAS_MULDIV),
        .HAS_VECTOR     (HAS_VECTOR),
        .HAS_DEBUG      (HAS_DEBUG),
        .HAS_SEVENSEG   (HAS_SEVENSEG),
        .HAS_PS2        (HAS_PS2),
        .HAS_ETH        (HAS_ETH),
        .FLASH_FW_BASE  (FLASH_FW_BASE),
        .FLASH_RW_BASE  (FLASH_RW_BASE)
    ) u_sysctrl (
        .clk_i          (clk_i),
        .rst_n_i        (rst_n_i),
        .apb_req_i      (s_sysctrl_req),
        .apb_rsp_o      (s_sysctrl_rsp),
        .boot_mode_i    (gpio_sw_i[BOOT_SW_IDX]),
        .soft_rst_req_o (soft_rst_req_o)
    );

    // Tie off unused QSPI / PS/2 until M2
    assign qspi_sck_o    = 1'b0;
    assign qspi_cs_n_o   = 1'b1;
    assign qspi_io_o     = 4'b0000;
    assign qspi_io_oe_o  = 4'b0000;
    assign ps2_clk_o     = 1'b1;
    assign ps2_clk_oe_o  = 1'b0;
    assign ps2_data_o    = 1'b1;
    assign ps2_data_oe_o = 1'b0;

endmodule : soc

