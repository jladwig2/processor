`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/pkg/board_basys3_pkg.sv
// Package:     board_basys3_pkg
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Hardware configuration package for the Digilent Basys 3 board
//   (Xilinx Artix-7 XC7A35T-1CPG236C). Defines board-specific physical
//   constants, peripheral counts, clock frequencies, default UART baud rate,
//   QSPI flash partition offsets, and the Basys 3 synthesis profile flags.
//
// Connections & Consumers:
//   - Imported by `top_basys3.sv` (in rtl/top/top_basys3.sv) to parameterize
//     `clk_rst_gen` and `soc`.
//   - Used to configure the Basys 3 build profile (`PROFILE_BASYS3`) so the
//     board-agnostic `soc.sv` instantiates only the peripherals and memory
//     sizes physically present on the Basys 3.
// =============================================================================

package board_basys3_pkg;

    // --- Clock & UART Configuration ---
    localparam int unsigned BOARD_OSC_HZ     = 100_000_000; // 100 MHz onboard crystal (pin W5)
    localparam int unsigned CORE_CLK_HZ      = 100_000_000; // 100 MHz core clock for M0 bring-up
    localparam int unsigned DEFAULT_BAUD     = 1_000_000;   // 1 Mbaud via FT2232H USB-UART bridge

    // --- Board Peripheral Counts & Feature Flags ---
    localparam int unsigned N_LED            = 16;          // 16 discrete green LEDs (LD15..LD0)
    localparam int unsigned N_SW             = 16;          // 16 slide switches (SW15..SW0)
    localparam int unsigned N_BTN            = 4;           // 4 directional buttons {btnD, btnR, btnL, btnU}; btnC is dedicated reset
    localparam int unsigned N_RGB            = 0;           // Basys 3 has no RGB LEDs
    localparam bit          HAS_SEVENSEG     = 1'b1;        // 4-digit 7-segment display present
    localparam bit          HAS_PS2          = 1'b1;        // PIC24 USB-HID host exposes PS2Clk/PS2Data
    localparam bit          HAS_ETH          = 1'b0;        // No Ethernet PHY on Basys 3
    localparam int unsigned BOOT_SW_IDX      = 15;          // SW[15]: 0 = QSPI flash boot, 1 = UART boot

    // --- Basys 3 Core / Memory Profile Parameters ---
    localparam int unsigned N_CORES          = 1;           // Single core on XC7A35T hardware build
    localparam bit          HAS_VECTOR       = 1'b0;        // Disabled by default on 35T profile (or enabled with small queues)
    localparam bit          HAS_MULDIV       = 1'b1;        // RV32M enabled
    localparam bit          HAS_DEBUG        = 1'b1;        // JTAG BSCANE2 debug enabled
    localparam bit          HAS_L1_PREFETCH  = 1'b1;        // L1 I/D prefetchers enabled
    localparam bit          HAS_L2_PREFETCH  = 1'b0;        // L2 stream prefetcher disabled (no DDR3 on Basys 3)
    localparam int unsigned MAIN_MEM_BYTES   = 96 * 1024;   // 96 KB on-chip BRAM main memory

    // --- QSPI Flash Partition Map (Spansion S25FL032P, 4 MB = 0x40_0000 bytes) ---
    // [0x00_0000 .. 0x27_FFFF] (2.5 MB): FPGA configuration bitstream (Read-Only)
    // [0x28_0000 .. 0x37_FFFF] (1.0 MB): RISC-V firmware image (Read-Only, flashed via JTAG)
    // [0x38_0000 .. 0x3F_FFFF] (512 KB): User Read/Write data region
    localparam logic [31:0] FLASH_TOTAL_BYTES = 32'h0040_0000;
    localparam logic [31:0] FLASH_FW_BASE     = 32'h0028_0000;
    localparam logic [31:0] FLASH_RW_BASE     = 32'h0038_0000;

endpackage : board_basys3_pkg

