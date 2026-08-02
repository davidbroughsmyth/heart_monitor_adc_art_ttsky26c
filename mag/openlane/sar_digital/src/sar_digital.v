/*
 * Copyright (c) 2025 davidbroughsmyth
 * SPDX-License-Identifier: Apache-2.0
 *
 * sar_digital.v — synthesizable digital SAR for LibreLane harden.
 * Analog cmp_out / sample / dac_bits interface (no DIGITAL_CMP_MODEL).
 */

`default_nettype none

module sar_digital (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cmp_out,
    output wire        sample,
    output wire [11:0] dac_bits,
    output wire [7:0]  uo_out,
    output wire [7:0]  uio_out,
    output wire [7:0]  uio_oe
);

    wire rst = ~rst_n;
    wire convert_strobe;
    wire [11:0] adc_data;
    wire        sample_en;
    wire        busy;
    wire        sample_w;
    wire [11:0] dac_bits_w;

    // Unused in silicon digital path (vin comes from AFE hold)
    wire [11:0] vin_unused = 12'd0;

    rate_divider #(
        .CLK_HZ(50_000_000),
        .SAMPLE_HZ(500)
    ) u_rate (
        .clk(clk),
        .rst(rst),
        .convert_strobe(convert_strobe)
    );

    sar_fsm u_sar (
        .clk(clk),
        .rst(rst),
        .convert_strobe(convert_strobe),
        .vin_code(vin_unused),
        .cmp_out(cmp_out),
        .sample(sample_w),
        .dac_bits(dac_bits_w),
        .adc_out(adc_data),
        .sample_en(sample_en),
        .busy(busy)
    );

    assign sample   = sample_w;
    assign dac_bits = dac_bits_w;
    assign uo_out   = adc_data[7:0];
    assign uio_out  = {3'b000, sample_en, adc_data[11:8]};
    assign uio_oe   = 8'b00011111;

    wire _unused = &{busy, 1'b0};

endmodule

`default_nettype wire
