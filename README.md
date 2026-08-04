![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg)

# heart_monitor_adc (Tiny Tapeout)

12-bit ~500 SPS **SAR ADC** companion for the SNN heart monitor
([snn_lif_neurons_ttsky26c](https://github.com/davidbroughsmyth/snn_lif_neurons_ttsky26c)).

Based on [ttsky-analog-template](https://github.com/TinyTapeout/ttsky-analog-template) (1×2, 2 analog pins).

- [Datasheet](docs/info.md) (Tiny Tapeout)
- [Component datasheet](docs/DATASHEET.md) (databook style)
- [Architecture](docs/ARCHITECTURE.md)
- [How a SAR ADC works](docs/HOW_A_SAR_WORKS.md) (primer)
- [User manual](docs/USER_MANUAL.md) (demoboard + HIL)
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
cd analog && ./run_tb.sh           # ideal
cd analog && ./run_tb_sky130.sh    # sky130 PDK (needs volare)
```

## GDS / layout

Checked-in Magic layout:

- `gds/tt_um_davidbroughsmyth_ecg_sar12.gds`
- `lef/tt_um_davidbroughsmyth_ecg_sar12.lef`

Rebuild (Docker + local volare sky130A PDK):

```sh
cd mag
make update_gds          # DEF + real-device AFE + place sar_digital
# optional: make harden  # OpenLane on mag/openlane/sar_digital (then copy macros — see mag/README.md)
```

See [mag/README.md](mag/README.md). Digital macro: `mag/macros/sar_digital/`.

**Status:** digital SAR is OpenLane-hardened (met4-max) and placed **hierarchically** in the 1×2
tile (do not flatten Mag). AFE layout for CI is metal-only placeholders; PDK SPICE first-pass is
in `analog/sky130/`. Real-device Mag gencells are deferred (they broke LEF origin / die boundary).
See [analog/README.md](analog/README.md) and [mag/README.md](mag/README.md).

## What is Tiny Tapeout?

https://tinytapeout.com
