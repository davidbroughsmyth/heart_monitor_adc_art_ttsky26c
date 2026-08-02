/*
 * Copyright (c) 2025 davidbroughsmyth
 * SPDX-License-Identifier: Apache-2.0
 *
 * sar_fsm.v — 12-bit SAR FSM with analog CDAC/CMP interface
 *
 * Outputs sample (track=1/hold=0) and dac_bits for the capacitive DAC.
 * Consumes cmp_out (1 = vin_hold >= dac).
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

    output reg         sample,     // 1=track, 0=hold
    output reg  [11:0] dac_bits,   // CDAC switch code
    output reg  [11:0] adc_out,
    output reg         sample_en,
    output reg         busy
);

    localparam S_IDLE  = 2'd0;
    localparam S_SAMPLE = 2'd1;
    localparam S_BIT   = 2'd2;
    localparam S_EMIT  = 2'd3;

    reg [1:0]  state;
    reg [3:0]  bit_idx;
    reg [11:0] vin_hold;
    reg [11:0] result;
    reg [2:0]  emit_cnt;
    reg        cmp_q;

    wire [11:0] dac_trial = result | (12'h001 << bit_idx);

`ifdef DIGITAL_CMP_MODEL
    wire cmp_ge = (vin_hold >= dac_trial);
`else
    wire cmp_ge = cmp_out;
`endif

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            bit_idx   <= 4'd0;
            vin_hold  <= 12'd0;
            result    <= 12'd0;
            dac_bits  <= 12'd0;
            adc_out   <= 12'd0;
            sample_en <= 1'b0;
            sample    <= 1'b1;
            busy      <= 1'b0;
            emit_cnt  <= 3'd0;
            cmp_q     <= 1'b0;
        end else begin
            sample_en <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy   <= 1'b0;
                    sample <= 1'b1; // track
                    dac_bits <= 12'd0;
                    if (convert_strobe) begin
                        busy     <= 1'b1;
                        vin_hold <= vin_code;
                        result   <= 12'd0;
                        bit_idx  <= 4'd11;
                        state    <= S_SAMPLE;
                    end
                end

                S_SAMPLE: begin
                    // Hold vin on CDAC/S&H; prime MSB trial
                    sample   <= 1'b0;
                    dac_bits <= 12'h800;
                    result   <= 12'd0;
                    bit_idx  <= 4'd11;
                    state    <= S_BIT;
                end

                S_BIT: begin
                    // Register comparator after DAC settle (1 cycle)
                    cmp_q <= cmp_ge;
                    if (cmp_ge)
                        result <= result | (12'h001 << bit_idx);

                    if (bit_idx == 4'd0) begin
                        emit_cnt <= 3'd0;
                        state    <= S_EMIT;
                    end else begin
                        bit_idx  <= bit_idx - 4'd1;
                        // Next trial code for CDAC
                        dac_bits <= (result | (cmp_ge ? (12'h001 << bit_idx) : 12'h0))
                                    | (12'h001 << (bit_idx - 4'd1));
                    end
                end

                S_EMIT: begin
                    adc_out   <= result;
                    dac_bits  <= result;
                    sample_en <= 1'b1;
                    emit_cnt  <= emit_cnt + 3'd1;
                    if (emit_cnt >= 3'd3) begin
                        busy   <= 1'b0;
                        sample <= 1'b1;
                        state  <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
