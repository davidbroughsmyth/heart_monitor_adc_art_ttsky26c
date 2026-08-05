# Fully-silicon mixed-signal lockstep cosim

Closes the SAR loop with **both** halves as real silicon:

* **Digital** — the *hardened gate-level netlist* of `sar_digital`
  (`sky130_fd_sc_hd` cells from the OpenLane harden run) runs in cocotb/iverilog.
  This is the actual synthesized logic that goes on the die, divider and all.
* **Analog** — the real sky130 AFE (`analog/sky130/sar_afe.spice`: S/H + R-2R
  CDAC + comparator, real `sky130_fd_pr` devices) runs in ngspice.

Every time the SAR presents a new `dac_bits` trial, `afe_ngspice.AFE` samples the
DC input, lets the DAC settle, and returns the real analog `cmp_out`, which is
driven back into the gate netlist — a true cycle-accurate lockstep. cocotb only
wakes on `dac_bits`/`uio_out` edges, so the 100 000-cycle sample divider costs
almost nothing (~13 ngspice comparisons per conversion; one persistent ngspice
process, so ~0.1 s each after a ~9 s one-time model setup).

The test asserts the silicon-logic result (`uo_out`/`uio_out`) equals an
independent binary-search reference driven by the **same** AFE — proving the
hardened gates implement the SAR correctly against the real analog comparator.
The results match `analog/run_sar_lockstep.sh` (B1) code-for-code.

## Run

```sh
./run_ms.sh                                  # default codes: 1024 2800
MS_CODES="256 1024 2048 2800 4095" ./run_ms.sh
```

Example (all PASS, monotonic; raw error is the un-trimmed AFE's offset + R-2R INL):

```
 vin  adc(gl)   ref  raw_err  match
 256      587   587     +331  OK
1024     1163  1163     +139  OK mono
2048     2226  2226     +178  OK mono
2800     3026  3026     +226  OK mono
4095     4095  4095       +0  OK mono
```

## Requirements

* volare sky130A (`PDK_ROOT`, defaults to the `mag/Makefile` hash)
* `iverilog`, `vvp`, `ngspice`, and the cocotb venv at `test/.venv`
* the OpenLane harden run present at
  `mag/openlane/sar_digital/runs/harden_met4/results/final/verilog/gl/sar_digital.v`
  (a build artifact — rebuild with `cd mag && make harden` if missing)

## Files

| File | Purpose |
|---|---|
| `tb_ms.v` | Verilog wrapper: free-running clk, ties VPWR/VGND, instances the gate netlist |
| `afe_ngspice.py` | Persistent `ngspice -p` handle to the real AFE (`compare()`, `set_vin()`) |
| `test_ms.py` | cocotb lockstep test + same-AFE reference check |
| `Makefile` / `run_ms.sh` | cocotb (icarus) build + convenience wrapper |
