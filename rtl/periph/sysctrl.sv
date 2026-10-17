`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/periph/sysctrl.sv
// Module:      sysctrl
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   System Control & Hardware Discovery APB peripheral mapped at base address
//   `0x1000_F000` (`SYSCTRL_BASE` in `soc_pkg.sv`).
//
//   Why This Module Exists:
//     - Because `processor-complex` is parameterized across multiple build
//       profiles (`PROFILE_BASYS3`, `PROFILE_ARTY100T`, `PROFILE_SIM`), bare-
//       metal boot ROM and firmware need a standard place to query the active
//       hardware configuration at runtime: how many cores exist, the core clock
//       frequency (to compute timer ticks and UART dividers), how much main RAM
//       is installed, which optional ISA/peripheral features are synthesized,
//       which boot mode switch is selected, and where the QSPI flash partitions
//       begin.
//     - It also provides a software warm-reset trigger (`SYS_REG_RESET`) and
//       four 32-bit scratch registers (`SYS_REG_SCRATCH0..3`) useful for boot
//       handshakes across harts and simulation test status reporting.
//
//   Register Map (Byte offsets relative to `0x1000_F000`):
//     - `0x000` (`SYS_REG_ID`,            RO):  `32'h5256_0002` ("RV" magic + v0.2)
//     - `0x004` (`SYS_REG_NCORES`,        RO):  `N_CORES`
//     - `0x008` (`SYS_REG_CLK_HZ`,        RO):  `CORE_CLK_HZ`
//     - `0x00C` (`SYS_REG_MEM_SIZE`,      RO):  `MAIN_MEM_BYTES`
//     - `0x010` (`SYS_REG_FEATURES`,      RO):  Feature bitmask:
//                                                 Bit [0]: `HAS_MULDIV`
//                                                 Bit [1]: `HAS_VECTOR`
//                                                 Bit [2]: `HAS_DEBUG`
//                                                 Bit [3]: `HAS_SEVENSEG`
//                                                 Bit [4]: `HAS_PS2`
//                                                 Bit [5]: `HAS_ETH`
//     - `0x014` (`SYS_REG_BOOT_MODE`,     RO):  `{31'b0, boot_mode_i}`
//                                               (0 = QSPI flash boot, 1 = UART boot)
//     - `0x018` (`SYS_REG_FLASH_FW_BASE`, RO):  `FLASH_FW_BASE`
//     - `0x01C` (`SYS_REG_FLASH_RW_BASE`, RO):  `FLASH_RW_BASE`
//     - `0x020` (`SYS_REG_RESET`,         WO):  Writing magic value `32'hDEAD_BEEF`
//                                               pulses `soft_rst_req_o` high for
//                                               1 cycle to trigger a warm reset
//                                               in `clk_rst_gen`.
//     - `0x030..0x03C` (`SYS_REG_SCRATCH0..3`, RW): Four 32-bit R/W registers.
//
// Connections:
//   - Instantiated by: `soc.sv` (`u_sysctrl`).
//   - APB Slave Port:
//       * `apb_req_i` / `apb_rsp_o` <- `apb_decoder.sv` (`s_sysctrl_req_o` / `s_sysctrl_rsp_i`)
//   - Control Signals:
//       * `boot_mode_i`    <- Synchronized boot select switch (`sw_sync[BOOT_SW_IDX]`)
//       * `soft_rst_req_o` -> `soc.sv` -> `clk_rst_gen.sv` (`soft_rst_req_i`)
//
// What Needs to Be Implemented:
//   1. Implement the four 32-bit scratch registers (`scratch_q[0:3]`) and the
//      `soft_rst_req_o` pulse on writing `32'hDEAD_BEEF` to `SYS_REG_RESET`.
//   2. Implement the combinational APB read multiplexer returning the
//      parameter-backed discovery values and `scratch_q` registers.
// =============================================================================

module sysctrl
    import soc_pkg::*;
#(
    parameter int unsigned N_CORES        = 1,
    parameter int unsigned CORE_CLK_HZ    = 100_000_000,
    parameter int unsigned MAIN_MEM_BYTES = 96 * 1024,
    parameter bit          HAS_MULDIV     = 1'b1,
    parameter bit          HAS_VECTOR     = 1'b0,
    parameter bit          HAS_DEBUG      = 1'b1,
    parameter bit          HAS_SEVENSEG   = 1'b1,
    parameter bit          HAS_PS2        = 1'b1,
    parameter bit          HAS_ETH        = 1'b0,
    parameter logic [31:0] FLASH_FW_BASE  = 32'h0028_0000,
    parameter logic [31:0] FLASH_RW_BASE  = 32'h0038_0000
) (
    input  logic     clk_i,
    input  logic     rst_n_i,

    // APB Slave Interface (from apb_decoder, Slot F @ 0x1000_F000)
    input  apb_req_t apb_req_i,
    output apb_rsp_t apb_rsp_o,

    // Sampled boot mode select switch (0 = QSPI flash boot, 1 = UART boot)
    input  logic     boot_mode_i,

    // Warm reset pulse back to clk_rst_gen
    output logic     soft_rst_req_o
);

    // -------------------------------------------------------------------------
    // TODO:
    //   Implement APB read multiplexer, `scratch_q[0:3]` write logic, and
    //   `soft_rst_req_o` pulse generation on `SYS_REG_RESET == 32'hDEAD_BEEF`.
    // -------------------------------------------------------------------------

    // Temporary stub tie-offs (replace when implementing System Control)
    assign apb_rsp_o.prdata  = 32'h0;
    assign apb_rsp_o.pready  = 1'b1;
    assign apb_rsp_o.pslverr = 1'b0;
    assign soft_rst_req_o = 1'b0;

endmodule : sysctrl

