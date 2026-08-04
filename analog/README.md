# Analog front-end (AFE) for ECG SAR12

Schematic-level models of the silicon path:

`ua[0] vin_ecg` → sample/hold → comparator  
`ua[1] vref` → 12-bit DAC → comparator → `cmp_out` → SAR FSM

## Status

| Piece | Status |
|---|---|
| Ideal SPICE polarity bench | PASS (`./run_tb.sh`) |
| sky130 PDK SPICE (TG S/H + **R-2R** DAC + OTA CMP) | PASS (`./run_tb_sky130.sh`, needs volare PDK) |
| Real-device Magic cells (`sky130_fd_pr` gencells) | **LVS-clean** — see table below |
| `afe_analog` (connected S/H + comparator + 12-bit R-2R DAC), single row | **netgen LVS vs `sar_afe.spice`: Circuits match uniquely** (~400×66 µm) |
| `afe_analog_folded` (same AFE, DAC folded into 2 rows) | **LVS vs `sar_afe.spice`: Circuits match uniquely** — **253×78 µm** |
| `afe_analog_dense` (same netlist, 0.5 µm track pitch + closer rows) | **LVS vs `sar_afe.spice`: Circuits match uniquely** — **253×44 µm** (placed on-die) |
| Signoff DRC (Magic, GDS round-trip) | Only benign `met1.6` gencell gate-pad tiles; **no real violations** |
| Macro pins | `sar_digital` re-hardened with analog pins on the **south edge** |
| Compact die-fit + routing to macro (**2×2**) | **Done** — `mag/build_top_2x2.tcl` places the dense AFE + macro and routes the full interface; DRC benign-only, connectivity extraction-verified |
| Full-tile netgen LVS (with std-cell netlist) | **Not done** |
| 12-bit INL / DNL / ECG metrology | **TBD** |

Per-block LVS (via `mag/verify_afe.sh`, all *Circuits match uniquely*):

| Magic cell | vs reference |
|---|---|
| `afe_sh` | `sample_hold.spice` |
| `afe_cmp` | `comparator.spice` |
| `afe_slice` | `dacslice.spice` (one R-2R bit) |
| `afe_dac` | `cdac_12b.spice` (full 12-bit, single row) |
| `afe_dac_folded` | `cdac_12b.spice` (12-bit, folded 2 rows, 186×75 µm) |
| `afe_analog` | `sar_afe.spice` (whole AFE, single row) |
| `afe_analog_folded` | `sar_afe.spice` (whole AFE, folded 2 rows, 253×78 µm) |
| `afe_analog_dense` | `sar_afe.spice` (whole AFE, dense fold, 253×44 µm — placed on-die) |

The **DAC is an R-2R ladder** (not a capacitive CDAC). `cdac_12b.spice` uses real
`sky130_fd_pr__res_xhigh_po_0p35` poly resistors (2R `l=3.34`, R `l=1.59`, guard →
`gnd`) so the extracted layout matches under netgen.

**CI GDS builds** now assemble the **2×2** connected tile (`cd mag && make top`):
the dense AFE `mag/afe_analog_dense` (253×44 µm) placed at the bottom, the
`sar_digital` macro at the top (kept as a hierarchical child — do **not** flatten),
and a met3/met4 channel wiring the full analog interface (`sample`,
`dac_bits[11:0]`, `cmp_out`, `vin_ecg`→`ua[0]`, `vref`→`ua[1]`, power). DRC is
benign-`met1.6`-only and connectivity is extraction-verified (`make top-verify`).

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
