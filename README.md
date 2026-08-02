![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg)

# heart_monitor_adc (Tiny Tapeout)

12-bit ~500 SPS **SAR ADC** companion for the SNN heart monitor
([snn_lif_neurons_ttsky26c](https://github.com/davidbroughsmyth/snn_lif_neurons_ttsky26c)).

Based on [ttsky-analog-template](https://github.com/TinyTapeout/ttsky-analog-template) (1×2, 2 analog pins).

- [Project docs](docs/info.md)
- [Demoboard integration](docs/INTEGRATION.md)
- [Analog AFE (SPICE)](analog/README.md)

## Pinout

| Pin | Signal |
|---|---|
| `uo[7:0]` | `adc[7:0]` |
| `uio[3:0]` | `adc[11:8]` |
| `uio[4]` | `sample_en` |
| `ua[0]` | `vin_ecg` (silicon) |
| `ua[1]` | `vref` (silicon) |

Top module: `tt_um_davidbroughsmyth_ecg_sar12`

## Local RTL test

```sh
cd test
python3.13 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
make -B
```

## Analog SPICE bench

```sh
cd analog && ./run_tb.sh
```

## GDS / layout

CI expects `gds/<top>.gds` and `lef/<top>.lef` (Magic layout). RTL + ideal SPICE
are in-repo now; place the AFE and harden the digital SAR before the GDS workflow
will pass.

## What is Tiny Tapeout?

https://tinytapeout.com
