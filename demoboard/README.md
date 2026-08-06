# Demoboard MicroPython HIL packages

Hardware-in-the-loop tests for the Tiny Tapeout **demo PCB** (RP2350) + ASIC
**breakout**, using the [tt-micropython-firmware](https://github.com/TinyTapeout/tt-micropython-firmware)
`DemoBoard` / microcotb API.

This repo is the **art fork** ([`heart_monitor_adc_art_ttsky26c`](https://github.com/davidbroughsmyth/heart_monitor_adc_art_ttsky26c)):
decorative met4 cats/hearts/`DBS` on-die do **not** change the pinout or HIL APIs.
Scripts still enable `tt_um_davidbroughsmyth_ecg_sar12` with the same wiring as the
pristine ADC.

See [docs/USER_MANUAL.md](../docs/USER_MANUAL.md) for circuits and procedures
(including Analog Discovery / AWG on `ua[]`, §3.4).

| Package | Enables | Role |
|---|---|---|
| `tt_um_davidbroughsmyth_ecg_sar12/` | ADC | Digital vin → read `sample_en` + code |
| `tt_um_snn_lif_neuron/` | SNN | RP emulates ADC traffic → class / alarm |

Copy onto the RP2 under `examples/` (or import from this path if mounted).
