# Analog front-end (AFE) for ECG SAR12

Schematic-level **SPICE** model of the silicon path:

`ua[0] vin_ecg` → sample/hold → comparator  
`ua[1] vref` → 12-bit CDAC → comparator → `cmp_out` → SAR FSM

## Files

| File | Description |
|---|---|
| `sample_hold.spice` | Track/hold on `vin_ecg` |
| `cdac_12b.spice` | Ideal binary DAC (behavioral CDAC) |
| `comparator.spice` | Ideal level comparator |
| `sar_afe.spice` | Top AFE subcircuit |
| `tb_afe.spice` | ngspice polarity checks |
| `run_tb.sh` | Batch run + assertions |

## Run

```sh
./run_tb.sh
```

Requires `ngspice` on `PATH`.

## PDK / silicon

This tree uses **ideal** sources so it runs without `PDK_ROOT`. For sky130 tapeout:

1. Replace switches/caps with `sky130_fd_pr` devices (or xschem symbols).
2. Replace `comparator` with a StrongARM or preamp+latch cell.
3. Place/route in Magic against Tiny Tapeout `tt_analog_1x2.def`.
4. Connect `ua[0]`/`ua[1]` and digital `sample` / `dac_bits` / `cmp_out` to the hardened SAR.
5. LVS against `sar_afe` + digital netlist.

RTL cocotb continues to use `src/analog_frontend_stub.v` under `-DDIGITAL_CMP_MODEL`.
