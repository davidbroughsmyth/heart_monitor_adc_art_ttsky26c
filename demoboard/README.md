# Demoboard MicroPython HIL packages

Hardware-in-the-loop tests for the Tiny Tapeout **demo PCB** (RP2350) + ASIC
**breakout**, using the [tt-micropython-firmware](https://github.com/TinyTapeout/tt-micropython-firmware)
`DemoBoard` / microcotb API.

See [docs/USER_MANUAL.md](../docs/USER_MANUAL.md) for circuits and procedures
(including Analog Discovery / AWG on `ua[]`, §3.4).

| Package | Enables | Role |
|---|---|---|
| `tt_um_davidbroughsmyth_ecg_sar12/` | ADC | Digital vin → read `sample_en` + code |
| `tt_um_snn_lif_neuron/` | SNN | RP emulates ADC traffic → class / alarm |

Copy onto the RP2 under `examples/` (or import from this path if mounted).
