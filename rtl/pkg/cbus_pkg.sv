`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/pkg/cbus_pkg.sv
// Package:     cbus_pkg
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Defines the core-to-SoC interconnect protocol (`cbus`). Across the full
//   project, `cbus` is a 5-channel TileLink-C-style coherent bus (channels A,
//   B, C, D, E) connecting each `core` to the shared L2 cache (`l2_cache`) and
//   the uncached MMIO crossbar (`soc_xbar` -> `cbus2apb`).
//
//   For Milestone 0 (before caches or the OoO core are built), only the
//   uncached request/response subset (`CBUS_GET` and `CBUS_PUT_FULL` /
//   `CBUS_PUT_PARTIAL` on channels A and D) is exercised by the M0 test FSM
//   in `soc.sv` to talk to `cbus2apb.sv`.
//
// Connections & Consumers:
//   - Mastered by:
//       * In M0: The switch-to-LED bring-up FSM inside `soc.sv`.
//       * In M1+: `core_cbus_arb.sv` inside `core.sv` (and `dm_sba.sv` for JTAG
//         System Bus Access).
//   - Slaved by:
//       * `soc_xbar.sv` (which routes cacheable addresses to `l2_cache.sv` and
//         uncached IO addresses `0x0200_0000..0x1FFF_FFFF` to `cbus2apb.sv`).
//       * In M0, `soc.sv` can wire the M0 test FSM's `cbus` port directly into
//         `cbus2apb.sv`.
//
// What Needs to Be Implemented (Later Milestones):
//   - M3/M6: Expand channel B (Probe) and channel C (Release/ProbeAck) helper
//     encodings when L1D MESI coherence is integrated.
// =============================================================================

package cbus_pkg;

    localparam int unsigned CBUS_ADDR_WIDTH = 32;
    localparam int unsigned CBUS_DATA_WIDTH = 32; // Uncached word width (L1<->L2 beat width expands to 128b in M3)
    localparam int unsigned CBUS_STRB_WIDTH = CBUS_DATA_WIDTH / 8;
    localparam int unsigned CBUS_SRC_WIDTH  = 4;

    // Channel A opcodes (Master -> Slave request)
    typedef enum logic [2:0] {
        CBUS_PUT_FULL     = 3'd0, // Uncached 32-bit write (all byte lanes active)
        CBUS_PUT_PARTIAL  = 3'd1, // Uncached masked write (byte/halfword using wstrb)
        CBUS_GET          = 3'd4, // Uncached 32-bit read
        CBUS_ACQUIRE_BLK  = 3'd6, // Cache line acquire (M3+ L1->L2)
        CBUS_ACQUIRE_PERM = 3'd7  // Cache line upgrade to M (M6+ MESI)
    } cbus_a_op_e;

    // Channel D opcodes (Slave -> Master response)
    typedef enum logic [2:0] {
        CBUS_ACCESS_ACK      = 3'd0, // Write completion acknowledgment
        CBUS_ACCESS_ACK_DATA = 3'd1, // Read completion with data payload
        CBUS_GRANT           = 3'd4, // Coherence permission grant (M3+)
        CBUS_GRANT_DATA      = 3'd5  // Coherence cache line refill grant (M3+)
    } cbus_d_op_e;

    // Channel A payload (Request: Core/FSM -> Interconnect)
    typedef struct packed {
        cbus_a_op_e                    opcode; // Operation type (CBUS_GET, CBUS_PUT_FULL, etc.)
        logic [CBUS_ADDR_WIDTH-1:0]    addr;   // 32-bit physical byte address
        logic [CBUS_DATA_WIDTH-1:0]    wdata;  // Write data payload
        logic [CBUS_STRB_WIDTH-1:0]    wstrb;  // Byte write enable mask (4'b1111 for full word)
        logic [CBUS_SRC_WIDTH-1:0]     src_id; // Transaction / MSHR / hart source tag
    } cbus_req_t;

    // Channel D payload (Response: Interconnect -> Core/FSM)
    typedef struct packed {
        cbus_d_op_e                    opcode; // Response type (CBUS_ACCESS_ACK, CBUS_ACCESS_ACK_DATA)
        logic [CBUS_DATA_WIDTH-1:0]    rdata;  // Read data payload
        logic                          err;    // 1 = Bus fault / access error (from PSLVERR or unmapped decode)
        logic [CBUS_SRC_WIDTH-1:0]     src_id; // Echoed transaction tag from request
    } cbus_rsp_t;

endpackage : cbus_pkg

