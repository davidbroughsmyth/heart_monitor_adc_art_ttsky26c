# Integration: ECG SAR12 ↔ SNN heart monitor

Companion ADC project (art fork): [heart_monitor_adc_art_ttsky26c](https://github.com/davidbroughsmyth/heart_monitor_adc_art_ttsky26c)  
Pristine ADC (no art): [heart_monitor_adc_ttsky26c](https://github.com/davidbroughsmyth/heart_monitor_adc_ttsky26c)  
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
5. ✓ **Complete top-level integration (2×2):** `mag/build_top_2x2.tcl` bumps the
   design to a **2×2** tile (334.88 × 225.76 µm) and stacks the dense AFE (bottom)
   + `sar_digital` (top) with a routing channel **below** the macro (AFE↔macro
   interface) and **above** it (digital I/O to the north boundary pins). It routes
   **everything**:
   - AFE↔macro: `sample`, `cmp_out`, `dac_bits[11:0]` (14-net met3/met4 channel);
   - analog in: `vin_ecg`→`ua[0]`, `vref`→`ua[1]` (south pins);
   - **all 26 digital boundary nets** — `clk`, `rst_n`, `uo_out[7:0]`,
     `uio_out[7:0]`, `uio_oe[7:0]` — macro-north → tile-north (top channel; track
     order solved from the vertical-conflict graph so every riser pair is
     short-free);
   - **power:** AFE `gnd`/`vdd` **and** the macro `VPWR`/`VGND` PDN straps are
     physically tied to the `VGND`/`VDPWR` met4 stripes (top-margin met3 bridges).
     (`ui_in`/`uio_in` are sim-only `vin` proxies and are correctly unused in
     silicon — the SAR uses the real comparator `cmp_out`.)
6. ✓ **Full-tile signoff:** DRC is **clean** — KLayout `mr` FEOL+BEOL = 0 items,
   Magic DRC = 0. Hierarchical full-tile connectivity LVS (`make top-verify`)
   confirms every intended net: analog I/O, the shared `sample`/`cmp_out`/12-bit
   DAC bus, all digital I/O to the boundary, and — critically — `sar_digital`'s
   `VPWR`→`VDPWR` / `VGND`→`VGND` (the macro is now **powered**; the previously
   floating `VPWR` net is gone). `info.yaml` `tiles` is `2x2`.
7. ✓ **Decorative silicon art:** `mag/macros/silicon_art` (185×130 µm met4 cats /
   hearts + `DBS`) placed at `(140, 68)` to the right of `sar_digital` by
   `build_top_2x2.tcl`. Floating metal only — no pins / power / SAR impact.
   TT precheck (Magic + KLayout, including offgrid) is green with art included.
   Demoboard wiring and HIL scripts are unchanged vs the pristine ADC.

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
