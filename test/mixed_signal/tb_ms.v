/*
 * tb_ms.v — top wrapper for the fully-silicon mixed-signal cosim.
 *
 * Instantiates the *hardened gate-level netlist* of `sar_digital` (real
 * sky130_fd_sc_hd cells) with a free-running clock.  cocotb (test_ms.py) drives
 * rst_n and cmp_out, and reads sample/dac_bits/uo_out/uio_out.  cmp_out is
 * produced by the real sky130 AFE in ngspice (afe_ngspice.AFE) each time the
 * SAR presents a new dac_bits trial — closing the SAR loop through actual
 * synthesized silicon logic + the real analog front-end.
 */
`timescale 1ns/1ps
`default_nettype none

module tb_ms;
    reg  clk = 1'b0;
    reg  rst_n = 1'b0;
    reg  cmp_out = 1'b0;
    wire        sample;
    wire [11:0] dac_bits;
    wire [7:0]  uo_out;
    wire [7:0]  uio_out;
    wire [7:0]  uio_oe;

    // Free-running clock in the simulator (cocotb only wakes on dac_bits/uio_out
    // edges, so the 100k-cycle sample divider costs almost no Python overhead).
    always #10 clk = ~clk;

    sar_digital dut (
        .VGND    (1'b0),
        .VPWR    (1'b1),
        .clk     (clk),
        .rst_n   (rst_n),
        .cmp_out (cmp_out),
        .sample  (sample),
        .dac_bits(dac_bits),
        .uio_oe  (uio_oe),
        .uio_out (uio_out),
        .uo_out  (uo_out)
    );

    initial begin
        if ($test$plusargs("dump")) begin
            $dumpfile("ms.fst");
            $dumpvars(0, tb_ms);
        end
    end
endmodule

`default_nettype wire
