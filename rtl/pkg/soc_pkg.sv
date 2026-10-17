`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/pkg/soc_pkg.sv
// Package:     soc_pkg
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Central System-on-Chip (SoC) definitions package. This file is the single
//   source of truth for:
//     1. The 32-bit physical address space map (Boot ROM, CLINT, PLIC, MMIO
//        peripherals, QSPI XIP window, and Main Memory).
//     2. APB3/APB4 peripheral bus request and response structures used between
//        `apb_decoder` (in rtl/interconnect/apb_decoder.sv) and all MMIO
//        peripherals (in rtl/periph/*.sv).
//     3. Peripheral register offsets for UART0, GPIO, 7-Segment, QSPI
//        Controller, PS/2 HID, and System Control (`sysctrl`).
//     4. Platform-Level Interrupt Controller (PLIC) interrupt source IDs.
//
// Connections & Consumers:
//   - Imported by `soc.sv`, `cbus2apb.sv`, `apb_decoder.sv`, `pma.sv`, and all
//     peripheral modules (`gpio.sv`, `sevenseg.sv`, `uart.sv`, `sysctrl.sv`,
//     `qspi_ctrl.sv`, `ps2_hid.sv`, `clint.sv`, `plic.sv`).
//   - Parsed by `scripts/gen_soc_h.py` to auto-generate `sw/include/soc.h` so
//     firmware and hardware never drift out of sync.
// =============================================================================

package soc_pkg;

    // =========================================================================
    // 1. Top-Level Physical Address Map (32-bit Address Space)
    // =========================================================================
    // Region               Base Address     Size       Attributes
    // -------------------  ---------------  ---------  ------------------------
    // Null / Guard Page    0x0000_0000      4 KB       Fault on access
    // Boot ROM             0x0000_1000      8 KB       RX, Cached (Reset PC)
    // CLINT                0x0200_0000      64 KB      RW, Uncached IO
    // PLIC                 0x0C00_0000      64 MB      RW, Uncached IO
    // APB MMIO Window      0x1000_0000      64 KB      RW, Uncached IO
    //   ├─ UART0           0x1000_0000      4 KB       RW, Uncached IO
    //   ├─ GPIO            0x1000_1000      4 KB       RW, Uncached IO
    //   ├─ 7-Segment       0x1000_2000      4 KB       RW, Uncached IO
    //   ├─ QSPI Ctrl       0x1000_3000      4 KB       RW, Uncached IO
    //   ├─ PS/2 HID        0x1000_4000      4 KB       RW, Uncached IO
    //   ├─ Ethernet MAC    0x1000_5000      4 KB       RW, Uncached IO (Future)
    //   └─ System Control  0x1000_F000      4 KB       RW, Uncached IO
    // QSPI Flash XIP       0x2000_0000      256 MB     RX, Cached (Read-only)
    // Main Memory (RAM)    0x8000_0000      Up to 2GB  RWX, Cached

    localparam logic [31:0] RESET_PC         = 32'h0000_1000;

    localparam logic [31:0] BOOT_ROM_BASE    = 32'h0000_1000;
    localparam logic [31:0] BOOT_ROM_SIZE    = 32'h0000_2000; // 8 KB

    localparam logic [31:0] CLINT_BASE       = 32'h0200_0000;
    localparam logic [31:0] CLINT_SIZE       = 32'h0001_0000; // 64 KB

    localparam logic [31:0] PLIC_BASE        = 32'h0C00_0000;
    localparam logic [31:0] PLIC_SIZE        = 32'h0400_0000; // 64 MB

    localparam logic [31:0] MMIO_BASE        = 32'h1000_0000;
    localparam logic [31:0] MMIO_SIZE        = 32'h0001_0000; // 64 KB APB window

    localparam logic [31:0] UART0_BASE       = 32'h1000_0000;
    localparam logic [31:0] GPIO_BASE        = 32'h1000_1000;
    localparam logic [31:0] SEVENSEG_BASE    = 32'h1000_2000;
    localparam logic [31:0] QSPI_CTRL_BASE   = 32'h1000_3000;
    localparam logic [31:0] PS2_HID_BASE     = 32'h1000_4000;
    localparam logic [31:0] ETH_MAC_BASE     = 32'h1000_5000;
    localparam logic [31:0] SYSCTRL_BASE     = 32'h1000_F000;
    localparam logic [31:0] APB_SLAVE_SIZE   = 32'h0000_1000; // 4 KB per slave

    localparam logic [31:0] FLASH_XIP_BASE   = 32'h2000_0000;
    localparam logic [31:0] FLASH_XIP_SIZE   = 32'h1000_0000; // 256 MB window

    localparam logic [31:0] MAIN_MEM_BASE    = 32'h8000_0000;

    // =========================================================================
    // 2. APB Peripheral Bus Definitions
    // =========================================================================
    // Every 4 KB peripheral slot in `0x1000_0000 .. 0x1000_FFFF` is indexed by
    // bits [15:12] of the byte address. `apb_decoder` uses `apb_slot_e` to
    // assert the appropriate `PSEL` line.

    localparam int unsigned APB_ADDR_WIDTH = 12; // 4 KB per peripheral slave
    localparam int unsigned APB_DATA_WIDTH = 32;
    localparam int unsigned APB_STRB_WIDTH = APB_DATA_WIDTH / 8;

    typedef enum logic [3:0] {
        APB_SLOT_UART0     = 4'h0, // 0x1000_0000
        APB_SLOT_GPIO      = 4'h1, // 0x1000_1000
        APB_SLOT_SEVENSEG  = 4'h2, // 0x1000_2000
        APB_SLOT_QSPI_CTRL = 4'h3, // 0x1000_3000
        APB_SLOT_PS2_HID   = 4'h4, // 0x1000_4000
        APB_SLOT_ETH_MAC   = 4'h5, // 0x1000_5000
        APB_SLOT_SYSCTRL   = 4'hF  // 0x1000_F000
    } apb_slot_e;

    // Master-to-Slave APB request bundle
    typedef struct packed {
        logic [31:0]                 paddr;   // Full 32-bit byte address (slaves inspect [11:0])
        logic                        psel;    // Slave select (asserted in SETUP and ACCESS phases)
        logic                        penable; // Access phase enable (asserted in ACCESS phase)
        logic                        pwrite;  // 1 = Write, 0 = Read
        logic [APB_DATA_WIDTH-1:0]   pwdata;  // Write data
        logic [APB_STRB_WIDTH-1:0]   pstrb;   // Byte write strobes (1 bit per byte lane)
    } apb_req_t;

    // Slave-to-Master APB response bundle
    typedef struct packed {
        logic [APB_DATA_WIDTH-1:0]   prdata;  // Read data (valid when psel & penable & !pwrite & pready)
        logic                        pready;  // Slave ready (1 = complete transfer on this rising edge)
        logic                        pslverr; // 1 = Bus error (unmapped register or write-protect violation)
    } apb_rsp_t;

    // =========================================================================
    // 3. Peripheral Register Offsets (Byte Offsets within 4 KB Slot)
    // =========================================================================

    // --- UART0 (0x1000_0000) ---
    localparam logic [11:0] UART_REG_TXDATA  = 12'h000; // [W]   [7:0] TX byte (ignored if TX FIFO full)
    localparam logic [11:0] UART_REG_RXDATA  = 12'h004; // [R]   [7:0] RX byte, [31] rx_empty flag
    localparam logic [11:0] UART_REG_STATUS  = 12'h008; // [R]   [0] tx_full, [1] tx_empty, [2] rx_empty, [3] rx_overrun
    localparam logic [11:0] UART_REG_CTRL    = 12'h00C; // [RW]  [0] rx_irq_en, [1] tx_empty_irq_en
    localparam logic [11:0] UART_REG_BAUDDIV = 12'h010; // [RW]  Clock divider = CLK_HZ / BAUD_RATE

    // --- GPIO (0x1000_1000) ---
    localparam logic [11:0] GPIO_REG_LED      = 12'h000; // [RW]  [15:0] Discrete LED output state
    localparam logic [11:0] GPIO_REG_SW       = 12'h004; // [R]   [15:0] Synchronized slide switch inputs
    localparam logic [11:0] GPIO_REG_BTN      = 12'h008; // [R]   [3:0]  Debounced directional buttons {D, R, L, U}
    localparam logic [11:0] GPIO_REG_IRQ_EN   = 12'h00C; // [RW]  [15:0] sw change IRQ en, [19:16] btn IRQ en
    localparam logic [11:0] GPIO_REG_IRQ_PEND = 12'h010; // [RW1C][15:0] sw change pending, [19:16] btn pending
    localparam logic [11:0] GPIO_REG_IRQ_EDGE = 12'h014; // [RW]  [0] button rising-edge trigger, [1] falling-edge
    localparam logic [11:0] GPIO_REG_INFO     = 12'h018; // [R]   [7:0] N_LED, [15:8] N_SW, [23:16] N_BTN, [31:24] N_RGB

    // --- 7-Segment Display (0x1000_2000) ---
    localparam logic [11:0] SEG_REG_CTRL      = 12'h000; // [RW]  [0] enable, [1] mode (0=hex, 1=raw), [11:8] brightness
    localparam logic [11:0] SEG_REG_HEX       = 12'h004; // [RW]  [15:0] Four 4-bit hex digits {digit3, digit2, digit1, digit0}
    localparam logic [11:0] SEG_REG_DP        = 12'h008; // [RW]  [3:0]  Decimal point enable per digit (1 = on)
    localparam logic [11:0] SEG_REG_RAW       = 12'h00C; // [RW]  [31:0] Four 8-bit raw segment masks {dp, g, f, e, d, c, b, a}

    // --- System Control (0x1000_F000) ---
    localparam logic [11:0] SYS_REG_ID            = 12'h000; // [R]  SoC magic + version (e.g., 32'h5256_0002 = "RV" v0.2)
    localparam logic [11:0] SYS_REG_NCORES        = 12'h004; // [R]  Number of synthesized harts
    localparam logic [11:0] SYS_REG_CLK_HZ        = 12'h008; // [R]  Core clock frequency in Hz
    localparam logic [11:0] SYS_REG_MEM_SIZE      = 12'h00C; // [R]  Main memory size in bytes
    localparam logic [11:0] SYS_REG_FEATURES      = 12'h010; // [R]  Feature bitmask {HAS_DEBUG, HAS_VECTOR, HAS_MULDIV, ...}
    localparam logic [11:0] SYS_REG_BOOT_MODE     = 12'h014; // [R]  Sampled boot switch (0 = QSPI flash, 1 = UART)
    localparam logic [11:0] SYS_REG_FLASH_FW_BASE = 12'h018; // [R]  Flash byte offset where firmware image starts
    localparam logic [11:0] SYS_REG_FLASH_RW_BASE = 12'h01C; // [R]  Flash byte offset where R/W user region starts
    localparam logic [11:0] SYS_REG_RESET         = 12'h020; // [W]  Write 32'hDEAD_BEEF to trigger warm SoC reset
    localparam logic [11:0] SYS_REG_SCRATCH0      = 12'h030; // [RW] General-purpose software scratch register 0

    // =========================================================================
    // 4. PLIC Interrupt Source Assignments
    // =========================================================================
    localparam int unsigned N_PLIC_IRQS      = 16;

    localparam int unsigned IRQ_NONE         = 0;
    localparam int unsigned IRQ_UART0_RX     = 1;
    localparam int unsigned IRQ_UART0_TX     = 2;
    localparam int unsigned IRQ_GPIO_BTN     = 3;
    localparam int unsigned IRQ_GPIO_SW      = 4;
    localparam int unsigned IRQ_QSPI_DONE    = 5;
    localparam int unsigned IRQ_PS2_RX       = 6;
    localparam int unsigned IRQ_ETH_MAC      = 7;

endpackage : soc_pkg

