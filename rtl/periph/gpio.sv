`timescale 1ns / 1ps
// =============================================================================
// File:        rtl/periph/gpio.sv
// Module:      gpio
// Project:     processor-complex
// Milestone:   M0 (Infrastructure & Peripherals)
//
// Description:
//   General-Purpose Input/Output (GPIO) APB peripheral mapped at base address
//   `0x1000_1000` (`GPIO_BASE` in `soc_pkg.sv`). Manages discrete board LEDs,
//   slide switches, and mechanical pushbuttons across different FPGA boards via
//   parameterized bus widths (`N_LED`, `N_SW`, `N_BTN`, `N_RGB`).
//
//   Key Responsibilities:
//     1. Synchronize raw asynchronous slide switch inputs (`sw_i`) into the
//        core clock domain using `sync_2ff` (`rtl/common/sync_2ff.sv`) to
//        prevent metastability.
//     2. Synchronize and debounce mechanical pushbutton inputs (`btn_i`) using
//        `debounce` (`rtl/common/debounce.sv`) so each physical button press
//        produces a single clean edge.
//     3. Drive the board's discrete LEDs (`led_o`) from an APB-writable
//        register (`GPIO_REG_LED`).
//     4. Detect switch state changes and button press/release edges to latch
//        pending interrupt bits in `GPIO_REG_IRQ_PEND` (Write-1-to-Clear) and
//        assert separate PLIC interrupt lines for buttons (`irq_btn_o`, PLIC
//        ID 3) and switches (`irq_sw_o`, PLIC ID 4).
//
//   Register Map (Byte offsets relative to `0x1000_1000`):
//     - `0x000` (`GPIO_REG_LED`,      RW):   [N_LED-1:0] LED output state.
//     - `0x004` (`GPIO_REG_SW`,       RO):   [N_SW-1:0]  Synchronized switch state.
//     - `0x008` (`GPIO_REG_BTN`,      RO):   [N_BTN-1:0] Debounced button state
//                                            (Basys 3: `{btnD, btnR, btnL, btnU}`).
//     - `0x00C` (`GPIO_REG_IRQ_EN`,   RW):   [15:0] Switch change IRQ enable mask,
//                                            [19:16] Button edge IRQ enable mask.
//     - `0x010` (`GPIO_REG_IRQ_PEND`, RW1C): [15:0] Switch change pending flags,
//                                            [19:16] Button edge pending flags.
//                                            Writing 1 to a bit clears that bit.
//     - `0x014` (`GPIO_REG_IRQ_EDGE`, RW):   Button trigger polarity:
//                                            [0] = 1 enables rising-edge (press),
//                                            [1] = 1 enables falling-edge (release).
//                                            (Default on reset: `2'b01` rising edge).
//     - `0x018` (`GPIO_REG_INFO`,     RO):   Board hardware discovery register:
//                                            `{8'(N_RGB), 8'(N_BTN), 8'(N_SW), 8'(N_LED)}`.
//
// Connections:
//   - Instantiated by: `soc.sv` (`u_gpio`).
//   - APB Slave Port:
//       * `apb_req_i` / `apb_rsp_o` <- `apb_decoder.sv` (`s_gpio_req_o` / `s_gpio_rsp_i`)
//   - External Board Pins (via `soc.sv` <-> `top_basys3.sv`):
//       * `sw_i`  <- `gpio_sw_i`  <- `sw[15:0]`
//       * `btn_i` <- `gpio_btn_i` <- `{btnD, btnR, btnL, btnU}`
//       * `led_o` -> `gpio_led_o` -> `led[15:0]`
//   - Interrupt Outputs (to `plic.sv` in M2):
//       * `irq_btn_o` -> PLIC source ID 3 (`IRQ_GPIO_BTN`)
//       * `irq_sw_o`  -> PLIC source ID 4 (`IRQ_GPIO_SW`)
//   - Child Modules to Instantiate:
//       * `sync_2ff #(.WIDTH(N_SW))`  (`rtl/common/sync_2ff.sv`) for `sw_i`.
//       * `debounce #(.WIDTH(N_BTN))` (`rtl/common/debounce.sv`) for `btn_i`.
// =============================================================================

module gpio
    import soc_pkg::*;
#(
    parameter int unsigned CORE_CLK_HZ = 100_000_000,
    parameter int unsigned N_LED       = 16,
    parameter int unsigned N_SW        = 16,
    parameter int unsigned N_BTN       = 4,
    parameter int unsigned N_RGB       = 0
) (
    input  logic             clk_i,
    input  logic             rst_n_i,

    // APB Slave Interface (from apb_decoder, Slot 1 @ 0x1000_1000)
    input  apb_req_t         apb_req_i,
    output apb_rsp_t         apb_rsp_o,

    // Physical Board I/O Signals (from/to top_basys3 via soc)
    input  logic [N_SW-1:0]  sw_i,
    input  logic [N_BTN-1:0] btn_i,
    output logic [N_LED-1:0] led_o,

    // Interrupt Lines to PLIC (ID 3 = Buttons, ID 4 = Switches)
    output logic             irq_btn_o,
    output logic             irq_sw_o
);

    // -------------------------------------------------------------------------
    // Input Synchronization and Debouncing
    // -------------------------------------------------------------------------
    logic [N_SW-1:0]  sw_sync;
    logic [N_SW-1:0]  sw_sync_d;

    sync_2ff #(
        .WIDTH     (N_SW),
        .RESET_VAL (1'b0)
    ) u_sw_sync (
        .clk_i   (clk_i),
        .rst_n_i (rst_n_i),
        .async_i (sw_i),
        .sync_o  (sw_sync)
    );

    logic [N_BTN-1:0] btn_clean;
    logic [N_BTN-1:0] btn_clean_d;

    debounce #(
        .WIDTH         (N_BTN),
        .STABLE_CYCLES (1_000_000)
    ) u_btn_debounce (
        .clk_i   (clk_i),
        .rst_n_i (rst_n_i),
        .raw_i   (btn_i),
        .clean_o (btn_clean)
    );

    // -------------------------------------------------------------------------
    // Edge Detection for Interrupts
    // -------------------------------------------------------------------------
    wire [N_SW-1:0]  sw_changed = sw_sync ^ sw_sync_d;
    wire [N_BTN-1:0] btn_rose    = btn_clean & ~btn_clean_d;
    wire [N_BTN-1:0] btn_fell    = ~btn_clean & btn_clean_d;

    logic [1:0] irq_edge_q; // [0] = rising, [1] = falling
    wire [N_BTN-1:0] btn_event = ({N_BTN{irq_edge_q[0]}} & btn_rose) |
                                 ({N_BTN{irq_edge_q[1]}} & btn_fell);

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------
    logic [N_LED-1:0] led_q;
    logic [19:0]      irq_en_q;   // [15:0] sw change, [19:16] btn
    logic [19:0]      irq_pend_q; // [15:0] sw change, [19:16] btn (W1C)

    wire reg_wr_en = apb_req_i.psel && apb_req_i.penable && apb_req_i.pwrite;
    wire [11:0] reg_addr = apb_req_i.paddr[11:0];

    // Hardware events to set in irq_pend
    logic [19:0] hw_events;
    always_comb begin
        hw_events = '0;
        hw_events[N_SW-1:0] = sw_changed;
        hw_events[16 +: N_BTN] = btn_event;
    end

    // Write-1-to-Clear mask for GPIO_REG_IRQ_PEND
    logic [19:0] w1c_clear_mask;
    always_comb begin
        w1c_clear_mask = '0;
        if (reg_wr_en && (reg_addr == GPIO_REG_IRQ_PEND)) begin
            if (apb_req_i.pstrb[0]) w1c_clear_mask[7:0]   = apb_req_i.pwdata[7:0];
            if (apb_req_i.pstrb[1]) w1c_clear_mask[15:8]  = apb_req_i.pwdata[15:8];
            if (apb_req_i.pstrb[2]) w1c_clear_mask[19:16] = apb_req_i.pwdata[19:16];
        end
    end

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            sw_sync_d   <= '0;
            btn_clean_d <= '0;
            led_q       <= '0;
            irq_en_q    <= '0;
            irq_pend_q  <= '0;
            irq_edge_q  <= 2'b01; // Default: rising edge (press)
        end else begin
            sw_sync_d   <= sw_sync;
            btn_clean_d <= btn_clean;

            // Update pending IRQ flags: clear bits written with 1, latch new hardware events
            irq_pend_q <= (irq_pend_q & ~w1c_clear_mask) | hw_events;

            if (reg_wr_en) begin
                case (reg_addr)
                    GPIO_REG_LED: begin
                        if (apb_req_i.pstrb[0]) led_q[7:0]  <= apb_req_i.pwdata[7:0];
                        if (apb_req_i.pstrb[1]) led_q[15:8] <= apb_req_i.pwdata[15:8];
                    end

                    GPIO_REG_IRQ_EN: begin
                        if (apb_req_i.pstrb[0]) irq_en_q[7:0]   <= apb_req_i.pwdata[7:0];
                        if (apb_req_i.pstrb[1]) irq_en_q[15:8]  <= apb_req_i.pwdata[15:8];
                        if (apb_req_i.pstrb[2]) irq_en_q[19:16] <= apb_req_i.pwdata[19:16];
                    end

                    GPIO_REG_IRQ_EDGE: begin
                        if (apb_req_i.pstrb[0]) begin
                            irq_edge_q <= apb_req_i.pwdata[1:0];
                        end
                    end

                    default: ;
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // APB Read Response
    // -------------------------------------------------------------------------
    logic [31:0] prdata_comb;

    always_comb begin
        prdata_comb = 32'h0;
        case (reg_addr)
            GPIO_REG_LED:      prdata_comb[N_LED-1:0] = led_q;
            GPIO_REG_SW:       prdata_comb[N_SW-1:0]  = sw_sync;
            GPIO_REG_BTN:      prdata_comb[N_BTN-1:0] = btn_clean;
            GPIO_REG_IRQ_EN:   prdata_comb[19:0]      = irq_en_q;
            GPIO_REG_IRQ_PEND: prdata_comb[19:0]      = irq_pend_q;
            GPIO_REG_IRQ_EDGE: prdata_comb[1:0]       = irq_edge_q;
            GPIO_REG_INFO:     prdata_comb            = {8'(N_RGB), 8'(N_BTN), 8'(N_SW), 8'(N_LED)};
            default:           prdata_comb            = 32'h0;
        endcase
    end

    assign apb_rsp_o.prdata  = prdata_comb;
    assign apb_rsp_o.pready  = 1'b1;
    assign apb_rsp_o.pslverr = 1'b0;

    assign led_o = led_q;

    assign irq_sw_o  = |(irq_pend_q[15:0] & irq_en_q[15:0]);
    assign irq_btn_o = |(irq_pend_q[19:16] & irq_en_q[19:16]);

endmodule : gpio

