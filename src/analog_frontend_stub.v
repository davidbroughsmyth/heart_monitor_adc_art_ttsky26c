/*
 * Copyright (c) 2025 davidbroughsmyth
 * SPDX-License-Identifier: Apache-2.0
 *
 * analog_frontend_stub.v — behavioral stand-in for CDAC + S/H + comparator
 */

`default_nettype none

module analog_frontend_stub (
    input  wire        clk,
    input  wire        rst,
    input  wire        sample,
    input  wire [11:0] dac_bits,
    input  wire [11:0] vin_code,
    inout  wire        ua_vin_ecg,
    inout  wire        ua_vref,

    output wire        cmp_out
);

    reg [11:0] vin_hold;

    always @(posedge clk) begin
        if (rst)
            vin_hold <= 12'd0;
        else if (sample)
            vin_hold <= vin_code;
    end

    // Combinational compare (matches CDAC+CMP settling in zero time for RTL)
    assign cmp_out = (vin_hold >= dac_bits);

    wire _unused = &{ua_vin_ecg, ua_vref, rst, 1'b0};

endmodule
