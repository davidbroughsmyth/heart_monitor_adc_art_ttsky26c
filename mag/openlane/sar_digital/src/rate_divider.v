/*
 * Copyright (c) 2025 davidbroughsmyth
 * SPDX-License-Identifier: Apache-2.0
 *
 * rate_divider.v — programmable convert strobe from system clock
 * Default: 50 MHz / 500 SPS = 100_000 cycles per sample.
 */

`default_nettype none

module rate_divider #(
    parameter CLK_HZ    = 50_000_000,
    parameter SAMPLE_HZ = 500
)(
    input  wire clk,
    input  wire rst,
    output reg  convert_strobe
);

    localparam integer DIV_I = CLK_HZ / SAMPLE_HZ;
    localparam [16:0] DIV = DIV_I[16:0];
    reg [16:0] cnt;

    always @(posedge clk) begin
        if (rst) begin
            cnt            <= 17'd0;
            convert_strobe <= 1'b0;
        end else if (cnt >= (DIV - 17'd1)) begin
            cnt            <= 17'd0;
            convert_strobe <= 1'b1;
        end else begin
            cnt            <= cnt + 17'd1;
            convert_strobe <= 1'b0;
        end
    end

endmodule
