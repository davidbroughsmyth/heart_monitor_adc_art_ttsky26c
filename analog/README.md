# Analog front-end (AFE) for ECG SAR12

Schematic-level models of the silicon path:

`ua[0] vin_ecg` → sample/hold → comparator  
`ua[1] vref` → 12-bit DAC → comparator → `cmp_out` → SAR FSM

## Status (best-effort first pass)

| Piece | Status |
|---|---|
| Ideal SPICE polarity bench | PASS (`./run_tb.sh`) |
| sky130 PDK SPICE (TG S/H + R-2R CDAC + OTA CMP) | PASS (`./run_tb_sky130.sh`, needs volare PDK) |
| Magic layout for TT precheck | **Metal-only** placeholders in `mag/layout_afe.tcl` (CI-safe) |
| Real-device Mag gencells | Deferred — flat gencell paint broke LEF ORIGIN/SIZE and spilled outside the die |
| Pin straps to `sar_digital` | Hierarchical child + crude met straps in `mag/integrate.tcl` |
| Full-tile netgen LVS | **Not done** |
| 12-bit INL / ECG metrology | **TBD** |

**CI GDS builds** use hierarchical Mag (do **not** flatten). Tiny Tapeout does **not** finish the AFE for you; PDK devices must later land in a hierarchical child with FIXED_BBOX inside the 1×2 area.

## Files

| Path | Description |
|---|---|
| `sample_hold.spice` / `cdac_12b.spice` / `comparator.spice` / `sar_afe.spice` | Ideal (no PDK) |
| `tb_afe.spice` + `run_tb.sh` | Ideal polarity checks |
| `sky130/` | PDK netlist + `tb_afe_sky130.spice` |
| `run_tb_sky130.sh` | PDK bench (`PDK_ROOT` override supported) |

## Run

```sh
./run_tb.sh              # ideal — no PDK required
./run_tb_sky130.sh       # sky130 — needs volare sky130A
```

Default `PDK_ROOT` matches `mag/Makefile` volare hash.

## Layout

See [`mag/README.md`](../mag/README.md). Rebuild:

```sh
cd ../mag && make update_gds
```

RTL cocotb still uses `src/analog_frontend_stub.v` under `-DDIGITAL_CMP_MODEL`.
