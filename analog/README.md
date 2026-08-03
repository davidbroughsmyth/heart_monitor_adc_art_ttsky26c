# Analog front-end (AFE) for ECG SAR12

Schematic-level models of the silicon path:

`ua[0] vin_ecg` → sample/hold → comparator  
`ua[1] vref` → 12-bit DAC → comparator → `cmp_out` → SAR FSM

## Status (best-effort first pass)

| Piece | Status |
|---|---|
| Ideal SPICE polarity bench | PASS (`./run_tb.sh`) |
| sky130 PDK SPICE (TG S/H + R-2R CDAC + OTA CMP) | PASS (`./run_tb_sky130.sh`, needs volare PDK) |
| Magic layout with real `sky130_fd_pr` gencells | First pass in `mag/layout_afe.tcl` |
| Pin straps to `sar_digital` | Crude met1/met2 in `mag/integrate.tcl` |
| Full-tile netgen LVS | **Not clean yet** — connectivity / resistor matching TBD |
| 12-bit INL / ECG metrology | **TBD** — not claimed |

**CI GDS builds** ≠ tapeout-ready AFE. Tiny Tapeout does **not** finish the AFE for you; further device sizing, matched CDAC, finished routing, and LVS are still on the designer.

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
