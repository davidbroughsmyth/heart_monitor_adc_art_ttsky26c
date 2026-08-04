# Integration: ECG SAR12 ↔ SNN heart monitor

Companion ADC project: [heart_monitor_adc_ttsky26c](https://github.com/davidbroughsmyth/heart_monitor_adc_ttsky26c)  
SNN project: [snn_lif_neurons_ttsky26c](https://github.com/davidbroughsmyth/snn_lif_neurons_ttsky26c)

Design overview: [ARCHITECTURE.md](ARCHITECTURE.md) · Datasheet: [info.md](info.md) · Component sheet: [DATASHEET.md](DATASHEET.md) · User manual: [USER_MANUAL.md](USER_MANUAL.md)

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

The AFE is built from **real `sky130_fd_pr` devices** and is **LVS-clean**: the
connected `mag/afe_analog` (S/H + comparator + 12-bit **R-2R** DAC) matches
`analog/sky130/sar_afe.spice` uniquely under netgen, and each sub-block
(`afe_sh`, `afe_cmp`, `afe_dac`) matches its own reference — see
[`mag/README.md`](../mag/README.md). Signoff DRC shows only benign `met1.6`
gencell gate-pad tiles. The `sar_digital` macro was re-hardened with the analog
pins (`cmp_out`, `sample`, `dac_bits[11:0]`) on the **south edge**. Keep
`sar_digital` a hierarchical child — **do not flatten**. (Do **not** use digital
`tt_tool.py --harden` for this analog custom_gds project.)

Done ✓ / remaining before trusting silicon / shuttle:

1. ✓ Real `sky130_fd_pr` devices, connected AFE, netgen LVS vs `sar_afe.spice`.
2. ✓ DAC matches the R-2R `analog/sky130/cdac_12b.spice` (poly resistors); both SPICE benches pass.
3. ✓ **DAC/AFE folded into 2 rows:** `mag/afe_analog_folded` (S/H + comparator +
   2-row R-2R DAC) is LVS-clean vs `sar_afe.spice` at **253 × 78 µm** (vs the
   ~400 × 66 µm single row), benign `met1.6` DRC only.
4. ✓ **Dense AFE:** `mag/afe_analog_dense` — same folded netlist, met2 track pitch
   tightened to 0.5 µm and rows pulled together — is **253 × 44 µm** and still
   LVS-clean vs `sar_afe.spice`. Getting *shorter* (not just narrower) is what lets
   it stack under the 140 µm macro (tile height is a fixed 225.76 µm for every
   `xN2`).
5. ✓ **Top-level fit + routing (2×2):** `mag/build_top_2x2.tcl` bumps the design to
   a **2×2** tile (334.88 × 225.76 µm), places the dense AFE (bottom) + `sar_digital`
   (top), and routes the full interface — `sample`, `dac_bits[11:0]`, `cmp_out`
   (met3/met4 channel), `vin_ecg`→`ua[0]`, `vref`→`ua[1]`, `gnd`→`VGND`,
   `vdd`→`VDPWR`. Signoff DRC = benign `met1.6` only; hierarchical extraction
   (`make top-verify`) confirms every AFE pin merges with the correct macro/`ua`
   pin. `info.yaml` `tiles` is now `2x2`.
6. **Remaining:** route the digital boundary I/O (`clk`/`rst_n`/`uo_out`/`uio_*`)
   and macro `VPWR`/`VGND` (currently left to the TT tile power grid); full-tile
   netgen LVS (top layout vs complete gate + AFE netlist); confirm GitHub
   `gds` / `precheck` Actions on the 2×2.

Lab stimulus: AWG / Analog Discovery into `ua[0]` (0…Vref) — [USER_MANUAL.md](USER_MANUAL.md) §3.4.

## Timing

- Production: **500 SPS** convert rate on 50 MHz clock.
- `sample_en` high for 4 clocks after each 12-bit conversion; SNN captures on `sample_en`.
- Idle time between strobes is large vs SAR latency (~12–20 clocks).

## Two-tile demo

1. Stream ECG or AWG QRS into the front-end → ADC `ua[0]` (Vref on `ua[1]`).
2. Observe SNN `uo[2:0]` class and `uo[3]` `diag_valid` on each beat window.
3. `uo[4]` alarm after three consecutive anomaly classes (1/2/4).
4. Optional bench: [Analog Discovery guide](https://tinytapeout.com/guides/analog-discovery/) + USER_MANUAL §3.4.
