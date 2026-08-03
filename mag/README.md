# Magic layout for heart_monitor_adc

Analog **custom_gds** tile: OpenLane-hardened `sar_digital` child + Magic AFE.

## Do not use the digital local-harden guide here

[Tiny Tapeout local hardening](https://tinytapeout.com/guides/local-hardening/) (`tt_tool.py` + LibreLane on the **top** module) is for digital projects.

This repo:

- Has **no** `tt/` / `tt_tool.py`
- Hardens only `sar_digital` with **OpenLane** Docker
- Assembles the 1×2 tile in Magic and commits `gds/` + `lef/`
- CI uses `tt-gds-action/custom_gds` (packs checked-in GDS; does not reharden)

Companion SNN may follow the digital guide; this ADC does not.

## Prerequisites

- Docker
- Local sky130A PDK via **volare** (default `PDK_ROOT` in Makefile)
- Image: `efabless/openlane:…-arm64v8` (`--platform linux/arm64`). On amd64 hosts, switch the image tag.

## Targets

```sh
make start       # TT DEF pins + VDPWR/VGND met4 stripes
make afe         # real-device AFE gencells (best-effort first pass)
make integrate   # place sar_digital + signal straps (no met4 power bridges)
make update_gds  # start + afe + integrate → ../gds ../lef
make harden      # OpenLane flow for sar_digital only
```

### After `make harden`

Copy results into the macro tree (Makefile does **not** do this automatically). Committed macro may come from tag `harden_met4`:

```sh
TAG=harden   # or harden_met4
cp openlane/sar_digital/runs/$TAG/results/final/gds/sar_digital.gds macros/sar_digital/
cp openlane/sar_digital/runs/$TAG/results/final/lef/sar_digital.lef macros/sar_digital/
cp openlane/sar_digital/runs/$TAG/results/final/verilog/gl/sar_digital.v macros/sar_digital/sar_digital.gl.v
make update_gds
```

Design sources for OpenLane live under `openlane/sar_digital/` (keep in sync with `../src/sar_digital.v`).

## Constraints

- **No user met5** — reserved for TT power grid ([analog specs](https://tinytapeout.com/specs/analog/))
- Digital child: `RT_MAX_LAYER=met4`
- Do not paint met4 horizontally across both `VDPWR` and `VGND` stripes

## AFE first-pass notes

`layout_afe.tcl` instantiates `sky130_fd_pr` nfet/pfet/MIM/m1-res via Magic device generators (S/H, comparator, compact R-2R). Routing to `sample` / `dac_bits` / `cmp_out` is approximate. Full netgen LVS and 12-bit matching are **not** done.

Outputs for CI: `../gds/tt_um_davidbroughsmyth_ecg_sar12.gds` and matching LEF.
