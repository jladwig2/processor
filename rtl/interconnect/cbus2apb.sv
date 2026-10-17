`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/interconnect/cbus2apb.sv
// Module:      cbus2apb
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   Protocol bridge from an uncached `cbus` request/response channel pair
//   (`cbus_req_t` / `cbus_rsp_t` defined in `cbus_pkg.sv`) to a single master
//   AMBA APB3/APB4 peripheral bus bundle (`apb_req_t` / `apb_rsp_t` defined in
//   `soc_pkg.sv`).
//
//   Why This Module Exists:
//     - The processor core (and the M0 Switch-to-LED test FSM) speaks `cbus`
//       with decoupled valid/ready request and response channels.
//     - Simple low-speed MMIO peripherals (`gpio`, `sevenseg`, `uart`, `sysctrl`)
//       are much cleaner and smaller when written as 2-cycle APB slaves
//       (`SETUP` phase -> `ACCESS` phase) without per-peripheral valid/ready
//       FIFOs.
//
//   APB Transaction State Machine:
//     1. `ST_IDLE`:
//        - `cbus_req_ready_o = 1'b1`, `apb_req_o.psel = 1'b0`,
//          `apb_req_o.penable = 1'b0`.
//        - When `cbus_req_valid_i` is asserted, latch the incoming `cbus_req_i`
//          fields (`addr`, `wdata`, `wstrb`, `src_id`, and whether `opcode` is
//          a write `CBUS_PUT_FULL`/`CBUS_PUT_PARTIAL` vs. read `CBUS_GET`), and
//          transition to `ST_SETUP`.
//     2. `ST_SETUP` (APB cycle 1):
//        - Drive `apb_req_o.psel = 1'b1`, `apb_req_o.penable = 1'b0`, along
//          with latched `paddr`, `pwrite`, `pwdata`, and `pstrb`.
//        - Unconditionally advance to `ST_ACCESS` on the next rising clock edge.
//     3. `ST_ACCESS` (APB cycle 2+):
//        - Drive `apb_req_o.psel = 1'b1`, `apb_req_o.penable = 1'b1`.
//        - Wait until `apb_rsp_i.pready == 1'b1`. When `pready` is high, capture
//          `apb_rsp_i.prdata` and `apb_rsp_i.pslverr` into the response register
//          and advance to `ST_RESP` (or present `cbus_rsp_valid_o` directly if
//          `cbus_rsp_ready_i` is high).
//     4. `ST_RESP`:
//        - Present `cbus_rsp_valid_o = 1'b1` with `opcode = pwrite ?
//          CBUS_ACCESS_ACK : CBUS_ACCESS_ACK_DATA`, `rdata`, `err = pslverr`,
//          and echoed `src_id`.
//        - When `cbus_rsp_ready_i` is high, return to `ST_IDLE`.
//
// Connections:
//   - Instantiated by: `soc.sv` (in `rtl/top/soc.sv`).
//   - Upstream (`cbus` slave port):
//       * Connected to the M0 Switch-to-LED test FSM in `soc.sv` (and in M1+,
//         to the uncached MMIO master port of `soc_xbar.sv`).
//   - Downstream (`apb` master port):
//       * Connected to `apb_decoder.sv` (`m_apb_req_i` / `m_apb_rsp_o`).
// =============================================================================

module cbus2apb
    import cbus_pkg::*;
    import soc_pkg::*;
(
    input  logic      clk_i,
    input  logic      rst_n_i,

    // Upstream cbus Slave Interface (from M0 FSM or soc_xbar)
    input  logic      cbus_req_valid_i,
    output logic      cbus_req_ready_o,
    input  cbus_req_t cbus_req_i,

    output logic      cbus_rsp_valid_o,
    input  logic      cbus_rsp_ready_i,
    output cbus_rsp_t cbus_rsp_o,

    // Downstream APB Master Interface (to apb_decoder)
    output apb_req_t  apb_req_o,
    input  apb_rsp_t  apb_rsp_i
);

    typedef enum logic [1:0] {
        ST_IDLE   = 2'd0,
        ST_SETUP  = 2'd1,
        ST_ACCESS = 2'd2,
        ST_RESP   = 2'd3
    } state_e;

    state_e state_q, state_d;

    // Latched request registers
    logic [31:0]               paddr_q;
    logic                      pwrite_q;
    logic [APB_DATA_WIDTH-1:0] pwdata_q;
    logic [APB_STRB_WIDTH-1:0] pstrb_q;
    logic [CBUS_SRC_WIDTH-1:0] src_id_q;

    // Response registers
    logic [APB_DATA_WIDTH-1:0] prdata_q;
    logic                      pslverr_q;

    always_comb begin
        state_d          = state_q;
        cbus_req_ready_o = 1'b0;
        cbus_rsp_valid_o = 1'b0;

        apb_req_o.paddr   = paddr_q;
        apb_req_o.pwrite  = pwrite_q;
        apb_req_o.pwdata  = pwdata_q;
        apb_req_o.pstrb   = pstrb_q;
        apb_req_o.psel    = 1'b0;
        apb_req_o.penable = 1'b0;

        cbus_rsp_o.opcode = pwrite_q ? CBUS_ACCESS_ACK : CBUS_ACCESS_ACK_DATA;
        cbus_rsp_o.rdata  = prdata_q;
        cbus_rsp_o.err    = pslverr_q;
        cbus_rsp_o.src_id = src_id_q;

        case (state_q)
            ST_IDLE: begin
                cbus_req_ready_o = 1'b1;
                if (cbus_req_valid_i) begin
                    state_d = ST_SETUP;
                end
            end

            ST_SETUP: begin
                apb_req_o.psel    = 1'b1;
                apb_req_o.penable = 1'b0;
                state_d           = ST_ACCESS;
            end

            ST_ACCESS: begin
                apb_req_o.psel    = 1'b1;
                apb_req_o.penable = 1'b1;
                if (apb_rsp_i.pready) begin
                    state_d = ST_RESP;
                end
            end

            ST_RESP: begin
                cbus_rsp_valid_o = 1'b1;
                if (cbus_rsp_ready_i) begin
                    state_d = ST_IDLE;
                end
            end

            default: state_d = ST_IDLE;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state_q   <= ST_IDLE;
            paddr_q   <= '0;
            pwrite_q  <= 1'b0;
            pwdata_q  <= '0;
            pstrb_q   <= '0;
            src_id_q  <= '0;
            prdata_q  <= '0;
            pslverr_q <= 1'b0;
        end else begin
            state_q <= state_d;

            if (state_q == ST_IDLE && cbus_req_valid_i) begin
                paddr_q  <= cbus_req_i.addr;
                pwrite_q <= (cbus_req_i.opcode == CBUS_PUT_FULL || cbus_req_i.opcode == CBUS_PUT_PARTIAL);
                pwdata_q <= cbus_req_i.wdata;
                pstrb_q  <= cbus_req_i.wstrb;
                src_id_q <= cbus_req_i.src_id;
            end

            if (state_q == ST_ACCESS && apb_rsp_i.pready) begin
                prdata_q  <= apb_rsp_i.prdata;
                pslverr_q <= apb_rsp_i.pslverr;
            end
        end
    end

endmodule : cbus2apb

