![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg)

# heart_monitor_adc (Tiny Tapeout)

12-bit ~500 SPS **SAR ADC** companion for the SNN heart monitor
([snn_lif_neurons_ttsky26c](https://github.com/davidbroughsmyth/snn_lif_neurons_ttsky26c)).

Based on [ttsky-analog-template](https://github.com/TinyTapeout/ttsky-analog-template) (1×2, 2 analog pins).

- [Datasheet](docs/info.md) (Tiny Tapeout)
- [Component datasheet](docs/DATASHEET.md) (databook style)
- [Architecture](docs/ARCHITECTURE.md)
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

Checked-in Magic layout:

- `gds/tt_um_davidbroughsmyth_ecg_sar12.gds`
- `lef/tt_um_davidbroughsmyth_ecg_sar12.lef`

Rebuild (Docker + local volare sky130A PDK):

```sh
cd mag
make update_gds          # DEF init + AFE paint + place sar_digital
# optional: make harden  # re-run OpenLane on src/sar_digital.v
```

See [mag/](mag/) for `magic_init_project.tcl`, `layout_afe.tcl`, `integrate.tcl`.
Digital macro artifacts: `mag/macros/sar_digital/`.

**Status:** digital SAR is OpenLane-hardened (DRC-clean macro) and placed in the 1×2
tile; AFE is a compact Mag paint of S/H + CDAC plates + inverter-chain CMP
matching `analog/` topology — refine devices and full pin routing before tapeout LVS.

## What is Tiny Tapeout?

https://tinytapeout.com
