# Magic layout for heart_monitor_adc

## Prerequisites

- Docker
- Local sky130A PDK via volare (default path in Makefile `PDK_ROOT`)
- Image: `efabless/openlane:...-arm64v8` (includes Magic)

## Targets

```sh
make start       # TT DEF pins + power stripes
make afe         # paint S/H + CDAC + CMP
make integrate   # place OpenLane sar_digital child
make update_gds  # start + afe + integrate → ../gds ../lef
make harden      # OpenLane flow for sar_digital
```

Outputs for CI: `../gds/tt_um_davidbroughsmyth_ecg_sar12.gds` and matching LEF.
