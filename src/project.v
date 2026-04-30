// SPDX-FileCopyrightText: 2025 Nemalipuri Rajkamal
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

// ============================================================
//  tt_um_rajkamal_analog
//  Multi-Stage Configurable Ring Oscillator
//  Sky130 Process  |  Tiny Tapeout Analog
//
//  Digital Control Interface (ui_in[7:0]):
//    ui_in[2:0]  – stage_sel : selects active inverter bank
//                  000 → 7 stages   (fastest)
//                  001 → 15 stages
//                  010 → 21 stages
//                  011 → 31 stages
//                  100 → 41 stages
//                  101 → 51 stages
//                  110 → 57 stages
//                  111 → 63 stages  (slowest, max area)
//    ui_in[3]    – en       : global oscillator enable (active-high)
//    ui_in[4]    – bypass   : route osc output directly to uio_out[0]
//    ui_in[7:5]  – reserved (tie low)
//
//  Analog port:
//    ua[0]  – analog frequency output (buffered oscillator node)
//             Can be probed with an oscilloscope or fed to an
//             on-chip frequency counter.
//
//  Digital output:
//    uo_out[0]   – divided clock  (/2 flip-flop)
//    uo_out[1]   – raw oscillator output (digital approximation)
//    uo_out[7:2] – reserved / tie-off status bits
//    uio_out[0]  – bypass / direct oscillator output
// ============================================================

module tt_um_rajkamal_analog (
    input  wire [7:0] ui_in,    // dedicated digital inputs
    output wire [7:0] uo_out,   // dedicated digital outputs
    input  wire [7:0] uio_in,   // bidirectional IOs – input path
    output wire [7:0] uio_out,  // bidirectional IOs – output path
    output wire [7:0] uio_oe,   // bidirectional IOs – output enable
    inout  wire [7:0] ua,        // analog I/O
    input  wire       ena,       // module enable from TT framework
    input  wire       clk,       // reference clock (unused by oscillator)
    input  wire       rst_n      // active-low reset
);

    // ── Control signals ──────────────────────────────────────
    wire [2:0] stage_sel = ui_in[2:0];
    wire       osc_en    = ui_in[3] & ena & rst_n;
    wire       bypass    = ui_in[4];

    // ── 63-stage ring oscillator (behavioural RTL model) ─────
    // In the actual GDS the inverter chain is drawn as custom
    // analog cells (sky130_fd_sc_hd__inv_X sized). This RTL
    // wrapper is synthesised into the digital wrapper only;
    // the real oscillation happens in the analog domain.
    //
    // For simulation / formal purposes we model the oscillator
    // as a parameterised delay chain toggling on a gated clock.

    localparam STAGES_7  = 3'd0,
               STAGES_15 = 3'd1,
               STAGES_21 = 3'd2,
               STAGES_31 = 3'd3,
               STAGES_41 = 3'd4,
               STAGES_51 = 3'd5,
               STAGES_57 = 3'd6,
               STAGES_63 = 3'd7;

    // Internal oscillator representation (behavioural toggle)
    reg osc_out_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            osc_out_r <= 1'b0;
        else if (osc_en)
            osc_out_r <= ~osc_out_r;   // toggle every ref-clk edge for sim
        else
            osc_out_r <= 1'b0;
    end

    // ── Divide-by-2 output ───────────────────────────────────
    reg div2_r;
    always @(posedge osc_out_r or negedge rst_n) begin
        if (!rst_n)
            div2_r <= 1'b0;
        else
            div2_r <= ~div2_r;
    end

    // ── Stage-count status bits (for debug readback) ─────────
    // uo_out[7:2] mirrors the selected stage count as a 6-bit value
    reg [5:0] stage_cnt_r;
    always @(*) begin
        case (stage_sel)
            STAGES_7  : stage_cnt_r = 6'd7;
            STAGES_15 : stage_cnt_r = 6'd15;
            STAGES_21 : stage_cnt_r = 6'd21;
            STAGES_31 : stage_cnt_r = 6'd31;
            STAGES_41 : stage_cnt_r = 6'd41;
            STAGES_51 : stage_cnt_r = 6'd51;
            STAGES_57 : stage_cnt_r = 6'd57;
            default   : stage_cnt_r = 6'd63;
        endcase
    end

    // ── Output assignments ───────────────────────────────────
    assign uo_out[0]   = div2_r;
    assign uo_out[1]   = osc_out_r;
    assign uo_out[7:2] = stage_cnt_r;

    // Bidirectional port: uio_out[0] = bypass/direct osc output
    assign uio_out     = {7'b0, (bypass ? osc_out_r : div2_r)};
    assign uio_oe      = 8'h01;   // only uio[0] is driven as output

    // ── Analog output (ua[0]) ────────────────────────────────
    // ua[0] is connected to the buffered mid-point of the ring
    // in the custom layout. In RTL we mark it as high-Z so the
    // synthesis tool does not try to drive it digitally.
    assign ua[0] = (osc_en) ? 1'bz : 1'bz;  // driven by analog cell
    assign ua[7:1] = 7'bz;                    // unused analog pins

endmodule
