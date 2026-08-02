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

Ideal SPICE proves topology without `PDK_ROOT`. Layout lives under [`mag/`](../mag/):

1. OpenLane-hardened `sar_digital` macro (`mag/macros/sar_digital/`).
2. Magic AFE paint (`layout_afe.tcl`) + TT `tt_analog_1x2.def` pins.
3. Top export: `gds/` + `lef/` (see `mag/Makefile`).

Still to harden before shuttle: sky130_fd_pr device swap for S/H/CDAC/CMP,
complete digital↔AFE routing, and netgen LVS of the full tile.

RTL cocotb continues to use `src/analog_frontend_stub.v` under `-DDIGITAL_CMP_MODEL`.
