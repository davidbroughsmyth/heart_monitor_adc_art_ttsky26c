/*
 * Copyright (c) 2025 davidbroughsmyth
 * SPDX-License-Identifier: Apache-2.0
 *
 * sar_fsm.v — 12-bit SAR FSM with analog S/H + R-2R DAC + CMP interface
 *
 * Outputs sample (track=1/hold=0) and dac_bits for the AFE.
 * Consumes cmp_out (1 = vin_hold >= dac).
 *
 * SETTLE_CYCLES clocks after updating dac_bits before sampling cmp_out
 * (default 8 → 160 ns @ 50 MHz). sample high during track also AZs the
 * autozeroed comparator in the AFE; dac_bits held at midscale (12'h800)
 * so the AZ→signal reconnect is referenced around Vref/2.
 *
 * With DIGITAL_CMP_MODEL (cocotb default): cmp is computed from vin_code.
 */

`default_nettype none

module sar_fsm (
    input  wire        clk,
    input  wire        rst,
    input  wire        convert_strobe,
    input  wire [11:0] vin_code,   // digital-sim vin only
    input  wire        cmp_out,    // from analog comparator (or model)

    output reg         sample,     // 1=track (and AZ), 0=hold
    output reg  [11:0] dac_bits,   // R-2R switch code
    output reg  [11:0] adc_out,
    output reg         sample_en,
    output reg         busy
);

    // Clocks to wait after dac_bits change before registering cmp_out.
    localparam integer SETTLE_CYCLES = 8;
    localparam [3:0]   SETTLE_MAX    = SETTLE_CYCLES - 1;

    localparam S_IDLE   = 3'd0;
    localparam S_SAMPLE = 3'd1;
    localparam S_SETTLE = 3'd2;
    localparam S_BIT    = 3'd3;
    localparam S_EMIT   = 3'd4;

    reg [2:0]  state;
    reg [3:0]  bit_idx;
    reg [11:0] vin_hold;
    reg [11:0] result;
    reg [2:0]  emit_cnt;
    reg [3:0]  settle_cnt;
    reg        cmp_q;

    wire [11:0] dac_trial = result | (12'h001 << bit_idx);

`ifdef DIGITAL_CMP_MODEL
    wire cmp_ge = (vin_hold >= dac_trial);
`else
    wire cmp_ge = cmp_out;
`endif

    always @(posedge clk) begin
        if (rst) begin
            state      <= S_IDLE;
            bit_idx    <= 4'd0;
            vin_hold   <= 12'd0;
            result     <= 12'd0;
            dac_bits   <= 12'h800; // midscale during idle track + AZ
            adc_out    <= 12'd0;
            sample_en  <= 1'b0;
            sample     <= 1'b1;
            busy       <= 1'b0;
            emit_cnt   <= 3'd0;
            settle_cnt <= 4'd0;
            cmp_q      <= 1'b0;
        end else begin
            sample_en <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy   <= 1'b0;
                    sample <= 1'b1; // track + AZ
                    dac_bits <= 12'h800; // AZ reconnect around midscale
                    if (convert_strobe) begin
                        busy     <= 1'b1;
                        vin_hold <= vin_code;
                        result   <= 12'd0;
                        bit_idx  <= 4'd11;
                        state    <= S_SAMPLE;
                    end
                end

                S_SAMPLE: begin
                    // Hold vin; prime MSB trial; AZ opens with sample
                    sample     <= 1'b0;
                    dac_bits   <= 12'h800;
                    result     <= 12'd0;
                    bit_idx    <= 4'd11;
                    settle_cnt <= 4'd0;
                    state      <= S_SETTLE;
                end

                S_SETTLE: begin
                    if (settle_cnt >= SETTLE_MAX) begin
                        settle_cnt <= 4'd0;
                        state      <= S_BIT;
                    end else begin
                        settle_cnt <= settle_cnt + 4'd1;
                    end
                end

                S_BIT: begin
                    cmp_q <= cmp_ge;
                    if (cmp_ge)
                        result <= result | (12'h001 << bit_idx);

                    if (bit_idx == 4'd0) begin
                        emit_cnt <= 3'd0;
                        state    <= S_EMIT;
                    end else begin
                        bit_idx  <= bit_idx - 4'd1;
                        dac_bits <= (result | (cmp_ge ? (12'h001 << bit_idx) : 12'h0))
                                    | (12'h001 << (bit_idx - 4'd1));
                        settle_cnt <= 4'd0;
                        state      <= S_SETTLE;
                    end
                end

                S_EMIT: begin
                    adc_out   <= result;
                    dac_bits  <= result;
                    sample_en <= 1'b1;
                    emit_cnt  <= emit_cnt + 3'd1;
                    if (emit_cnt >= 3'd3) begin
                        busy     <= 1'b0;
                        sample   <= 1'b1;
                        dac_bits <= 12'h800;
                        state    <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
