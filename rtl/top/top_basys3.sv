`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/top/top_basys3.sv
// Module:      top_basys3
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Physical FPGA pin-level wrapper for the Digilent Basys 3 board
//   (Xilinx Artix-7 XC7A35T-1CPG236C). This module isolates all board- and
//   vendor-specific I/O primitives from the portable System-on-Chip (`soc.sv`).
//
//   Specifically, `top_basys3` is responsible for:
//     1. Receiving the 100 MHz board crystal (`clk`, pin W5) and dedicated
//        active-high center reset button (`btnC`, pin U18) and feeding them
//        into `clk_rst_gen` (`rtl/top/clk_rst_gen.sv`) to produce the internal
//        core clock (`clk_core`) and synchronous active-low reset (`rst_core_n`).
//     2. Packing the 4 directional pushbuttons (`{btnD, btnR, btnL, btnU}`) into
//        a generic `gpio_btn_i[3:0]` bus for `soc`. Note that `btnC` is strictly
//        the hardware reset and is NOT exposed as a general-purpose button.
//     3. Routing the 4-digit 7-segment display (`seg[6:0]`, `dp`, `an[3:0]`),
//        16 slide switches (`sw[15:0]`), 16 green LEDs (`led[15:0]`), and
//        USB-UART pins (`RsRx`, `RsTx`) between the physical package pins
//        (constrained in `constrs/basys3.xdc`) and `soc`.
//     4. Instantiating Xilinx's `STARTUPE2` primitive so the QSPI flash
//        controller inside `soc` can drive the dedicated configuration clock
//        pin (`CCLK`) via `USRCCLKO` after FPGA configuration finishes.
//     5. Instantiating bidirectional tristate buffers (`IOBUF`) for the 4 QSPI
//        data lines (`QspiDB[3:0]`) and the 2 PS/2 USB-HID lines (`PS2Clk`,
//        `PS2Data`), converting them into split `_i`, `_o`, and `_oe` signals
//        for `soc`.
//
// Connections:
//   - Top-level ports -> Matched 1:1 with `constrs/basys3.xdc`.
//   - Child 1: `clk_rst_gen` (`rtl/top/clk_rst_gen.sv`)
//       * `.clk_board_i(clk)`, `.rst_btn_i(btnC)`, `.soft_rst_req_i(soft_rst_req)`
//       * Outputs `.clk_core_o(clk_core)`, `.rst_core_n_o(rst_core_n)`
//   - Child 2: `STARTUPE2` (Xilinx Unisim primitive, needed in M2 for QSPI)
//       * `.USRCCLKO(qspi_sck_o)`, `.USRCCLKTS(1'b0)`
//   - Child 3: `soc` (`rtl/top/soc.sv`), parameterized from `board_basys3_pkg`.
// =============================================================================

module top_basys3 (
    // 100 MHz onboard crystal oscillator (Pin W5)
    input  logic        clk,

    // Dedicated active-high system reset pushbutton (Center button, Pin U18)
    input  logic        btnC,

    // 4 directional pushbuttons exposed to GPIO peripheral (Active-High)
    // Mapped to GPIO.BTN[3:0] as {btnD, btnR, btnL, btnU}
    input  logic        btnU,
    input  logic        btnL,
    input  logic        btnR,
    input  logic        btnD,

    // 16 slide switches (Active-High, SW[15] also serves as boot mode select)
    input  logic [15:0] sw,

    // 16 discrete green LEDs (Active-High)
    output logic [15:0] led,

    // 4-digit 7-segment display (Active-Low cathodes seg[6:0]/dp and anodes an[3:0])
    output logic [6:0]  seg,
    output logic        dp,
    output logic [3:0]  an,

    // FT2232H USB-UART bridge (RsRx = FPGA input from host PC, RsTx = FPGA output to host PC)
    input  logic        RsRx,
    output logic        RsTx,

    // Onboard 4 MB Quad-SPI Flash (Spansion S25FL032P; SCK routed via STARTUPE2)
    output logic        QspiCSn,
    inout  wire  [3:0]  QspiDB,

    // PIC24 USB-HID Host controller (presents USB keyboard/mouse as PS/2)
    inout  wire         PS2Clk,
    inout  wire         PS2Data
);

    import board_basys3_pkg::*;

    // -------------------------------------------------------------------------
    // Internal Clocks and Resets
    // -------------------------------------------------------------------------
    logic clk_core;
    logic rst_core_n;
    logic pll_locked;
    logic soft_rst_req;

    clk_rst_gen #(
        .BOARD_OSC_HZ       (BOARD_OSC_HZ),
        .CORE_CLK_HZ        (CORE_CLK_HZ),
        .RST_STRETCH_CYCLES (64)
    ) u_clk_rst_gen (
        .clk_board_i    (clk),
        .rst_btn_i      (btnC),
        .soft_rst_req_i (soft_rst_req),
        .clk_core_o     (clk_core),
        .rst_core_n_o   (rst_core_n),
        .pll_locked_o   (pll_locked)
    );

    // -------------------------------------------------------------------------
    // Button Packing
    // -------------------------------------------------------------------------
    // Note: btnC (center) is reserved strictly for hardware reset into clk_rst_gen.
    // The 4 directional buttons are packed into gpio_btn_i as {btnD, btnR, btnL, btnU}.
    wire [N_BTN-1:0] gpio_btn = {btnD, btnR, btnL, btnU};

    // -------------------------------------------------------------------------
    // Split Tristate Signals for External Bidirectional Buses
    // -------------------------------------------------------------------------
    logic       qspi_sck;
    logic       qspi_cs_n;
    logic [3:0] qspi_io_i;
    logic [3:0] qspi_io_o;
    logic [3:0] qspi_io_oe;

    logic       ps2_clk_i;
    logic       ps2_clk_o;
    logic       ps2_clk_oe;
    logic       ps2_data_i;
    logic       ps2_data_o;
    logic       ps2_data_oe;

    // QSPI Flash Bidirectional Data Lines (QspiDB[3:0])
    genvar gi;
    generate
        for (gi = 0; gi < 4; gi++) begin : gen_qspi_io
            assign QspiDB[gi]    = qspi_io_oe[gi] ? qspi_io_o[gi] : 1'bz;
            assign qspi_io_i[gi] = QspiDB[gi];
        end
    endgenerate
    assign QspiCSn = qspi_cs_n;

    // Note for M2 (QSPI controller bring-up):
    // On 7-series FPGAs, CCLK is a dedicated configuration pin. After configuration,
    // it must be accessed via the STARTUPE2 primitive (.USRCCLKO(qspi_sck)).
    // In M0, qspi_sck is held idle (0) inside soc.sv.

    // PS/2 USB-HID Bidirectional Lines (PS2Clk, PS2Data)
    assign PS2Clk     = ps2_clk_oe  ? ps2_clk_o  : 1'bz;
    assign ps2_clk_i  = PS2Clk;
    assign PS2Data    = ps2_data_oe ? ps2_data_o : 1'bz;
    assign ps2_data_i = PS2Data;

    // -------------------------------------------------------------------------
    // System-on-Chip (SoC) Container
    // -------------------------------------------------------------------------
    soc #(
        .N_CORES        (N_CORES),
        .CORE_CLK_HZ    (CORE_CLK_HZ),
        .DEFAULT_BAUD   (DEFAULT_BAUD),
        .N_LED          (N_LED),
        .N_SW           (N_SW),
        .N_BTN          (N_BTN),
        .N_RGB          (N_RGB),
        .HAS_SEVENSEG   (HAS_SEVENSEG),
        .HAS_PS2        (HAS_PS2),
        .HAS_ETH        (HAS_ETH),
        .HAS_VECTOR     (HAS_VECTOR),
        .HAS_MULDIV     (HAS_MULDIV),
        .HAS_DEBUG      (HAS_DEBUG),
        .BOOT_SW_IDX    (BOOT_SW_IDX),
        .MAIN_MEM_BYTES (MAIN_MEM_BYTES),
        .FLASH_FW_BASE  (FLASH_FW_BASE),
        .FLASH_RW_BASE  (FLASH_RW_BASE)
    ) u_soc (
        .clk_i          (clk_core),
        .rst_n_i        (rst_core_n),
        .soft_rst_req_o (soft_rst_req),
        .gpio_sw_i      (sw),
        .gpio_btn_i     (gpio_btn),
        .gpio_led_o     (led),
        .sevenseg_seg_o (seg),
        .sevenseg_dp_o  (dp),
        .sevenseg_an_o  (an),
        .uart_rx_i      (RsRx),
        .uart_tx_o      (RsTx),
        .qspi_sck_o     (qspi_sck),
        .qspi_cs_n_o    (qspi_cs_n),
        .qspi_io_i      (qspi_io_i),
        .qspi_io_o      (qspi_io_o),
        .qspi_io_oe_o   (qspi_io_oe),
        .ps2_clk_i      (ps2_clk_i),
        .ps2_clk_o      (ps2_clk_o),
        .ps2_clk_oe_o   (ps2_clk_oe),
        .ps2_data_i     (ps2_data_i),
        .ps2_data_o     (ps2_data_o),
        .ps2_data_oe_o  (ps2_data_oe)
    );

endmodule : top_basys3


