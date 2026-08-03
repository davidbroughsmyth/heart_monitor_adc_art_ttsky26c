# Integration: ECG SAR12 ↔ SNN heart monitor

Companion ADC project: [heart_monitor_adc_ttsky26c](https://github.com/davidbroughsmyth/heart_monitor_adc_ttsky26c)  
SNN project: [snn_lif_neurons_ttsky26c](https://github.com/davidbroughsmyth/snn_lif_neurons_ttsky26c)

Design overview: [ARCHITECTURE.md](ARCHITECTURE.md) · Datasheet: [info.md](info.md)

## Demoboard wiring

```text
ADC tile                         SNN tile
--------                         --------
uo[7:0]   (adc[7:0])      --->   ui_in[7:0]
uio[3:0]  (adc[11:8])     --->   uio_in[3:0]
uio[4]    (sample_en)     --->   uio_in[4]
clk                       --->   clk
rst_n                     --->   rst_n
GND                       --->   GND
```

Leave SNN `uio_in[7:5]` unused (or tie 0). ADC `uio[7:5]` are inputs for the digital
vin proxy during RTL sim only.

## Analog

| ADC pad | Function |
|---|---|
| `ua[0]` | `vin_ecg` — conditioned single-ended ECG (silicon input) |
| `ua[1]` | `vref` — SAR reference (silicon input) |

Digital `ui_in` / `uio_in[7:5]` drive the RTL stub only; they are not the silicon
ECG path. Schematic AFE: [`analog/sar_afe.spice`](../analog/sar_afe.spice).

External gain should place R-peaks at ADC codes **≥ 2200** (SNN peak threshold).

## Magic / layout checklist

Current repo includes Magic GDS/LEF from `mag/` (DEF pins + AFE paint + LibreLane
`sar_digital` child). Before shuttle submission:

1. Replace painted AFE with `sky130_fd_pr` devices; keep `analog/` topology.
2. Finish routing `sample`, `dac_bits[11:0]`, `cmp_out`, `ua[0]/1]` to the digital macro.
3. Tie unused digital outs to GND; DRC + netgen LVS of the full tile.
4. Re-run `cd mag && make update_gds` and confirm GitHub `gds` / `precheck` Actions.

## Timing

- Production: **500 SPS** convert rate on 50 MHz clock.
- `sample_en` high for 4 clocks after each 12-bit conversion; SNN captures on `sample_en`.
- Idle time between strobes is large vs SAR latency (~12–20 clocks).

## Two-tile demo

1. Stream ECG (or function-gen QRS) into the front-end → ADC.
2. Observe SNN `uo[2:0]` class and `uo[3]` `diag_valid` on each beat window.
3. `uo[4]` alarm after three consecutive anomaly classes (1/2/4).
