# Analog front-end (AFE) for ECG SAR12

Schematic-level models of the silicon path:

`ua[0] vin_ecg` → sample/hold → comparator  
`ua[1] vref` → 12-bit DAC → comparator → `cmp_out` → SAR FSM

## Status

| Piece | Status |
|---|---|
| Ideal SPICE polarity bench | PASS (`./run_tb.sh`) |
| sky130 PDK SPICE (TG S/H + **R-2R** DAC + OTA CMP) | PASS (`./run_tb_sky130.sh`, needs volare PDK) |
| **Mixed-signal SAR (B1 lockstep, real AFE)** | Monotonic in ECG band; see **Accuracy (sim)** below (`./run_sar_lockstep.sh`) |
| **Fully-silicon lockstep (real gate netlist + real AFE)** | Same AFE interface; re-run after macro copy (`test/mixed_signal/run_ms.sh`) |
| Real-device Magic cells (`sky130_fd_pr` gencells) | **LVS-clean** — see table below |
| `afe_analog` (connected S/H + comparator + 12-bit R-2R DAC), single row | **netgen LVS vs `sar_afe.spice`: Circuits match uniquely** (~400×66 µm) |
| `afe_analog_folded` (same AFE, DAC folded into 2 rows) | **LVS vs `sar_afe.spice`: Circuits match uniquely** — **253×78 µm** |
| `afe_analog_dense` (1 pF Chold, AZ cmp, compact R-2R) | **Extract port-clean** (~312×51 µm); netgen vs SPICE not unique yet (compact ladder / CM `l` proxy vs unit-R SPICE) |
| Signoff DRC (Magic, GDS round-trip) | Aim benign `met1.6` only; confirm after `make top` |
| Macro pins | `sar_digital` re-hardened (midscale-during-AZ FSM); south analog pins; `SETTLE_CYCLES=8` |
| Compact die-fit + routing to macro (**2×2**) | **Done** — east dig corridor, raised macro, shrunk `silicon_art` (95×70) |
| Full-tile netgen LVS (with std-cell netlist) | **Not done** |
| Shuttle silicon characterization | **Still required** |

### Accuracy (sim) — B1 lockstep @ 1.5 µs settle (tt, sky130)

| Regime | Codes (approx) | Result |
|---|---|---|
| Endpoint fit (ECG-relevant set) | 0…4095 sparse | **offset ≈ 0…+3 LSB**; endpoint **INL ≈ 14…20 LSB** (fails hard ≤8 LSB gate) |
| Mid / ECG band | ~248…2200 (baseline≈2048, R-peak target≥2200) | raw err roughly **±13…14 LSB** |
| High FS | ≳3321 | **rails to 4095** (cmp tops boost >VDD after AZ); **deferred** — outside intended mid-biased ECG window |

Comparator (SPICE): bottom-plate AZ while `sample=1`, asymmetric AZ CM (~0.16 V + ~6.4 mV δ), MiM C1/C2 = **24/10**, FSM holds **`dac_bits=12'h800`** during track+AZ. DAC: unit R with **extracted `l≈9.08`**, TG **W=8/16**. Chold ≈**1 pF** (`22×22` MiM).

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
| `afe_analog_dense` | `sar_afe.spice` (whole AFE, dense fold — 1 pF Chold + AZ + unit R-2R) |

The **DAC is an R-2R ladder** (not a capacitive CDAC). `cdac_12b.spice` uses unit
`sky130_fd_pr__res_xhigh_po_0p35` poly resistors (true **2R = two series R units**,
drawn ≈`l=10` → extracted `l≈9.08`, guard → `gnd`) plus wide TGs (**W=8/16**) so Ron ≪ R.
The comparator is **autozeroed during track** (`sample=1`); Chold is ≈**1 pF**
MiM (`22×22`).

**CI GDS builds** assemble the **2×2** connected tile (`cd mag && make top`):
the dense AFE placed low (with east overshoot), `sar_digital` raised (~y=82)
kept as a hierarchical child — do **not** flatten — dig I/O escapes via an
**east corridor** then north to boundary pins, and shrunk decorative
`silicon_art` (95×70 µm) in the NE pocket. DRC is benign-`met1.6`-only and
connectivity is extraction-verified (`make top-verify`).
## Files

| Path | Description |
|---|---|
| `sample_hold.spice` / `cdac_12b.spice` / `comparator.spice` / `sar_afe.spice` | Ideal (no PDK) |
| `tb_afe.spice` + `run_tb.sh` | Ideal polarity checks |
| `sky130/` | PDK netlist + `tb_afe_sky130.spice` |
| `run_tb_sky130.sh` | PDK bench (`PDK_ROOT` override supported) |
| `sky130/tb_sar_lockstep.py` + `run_sar_lockstep.sh` | Mixed-signal SAR (B1 lockstep, real AFE) |

## Run

```sh
./run_tb.sh              # ideal — no PDK required
./run_tb_sky130.sh       # sky130 — needs volare sky130A
./run_sar_lockstep.sh    # mixed-signal SAR lockstep (sky130, needs volare)
./run_sar_lockstep.sh 2800 1024 -v   # specific codes + bit-trace
```

Default `PDK_ROOT` matches `mag/Makefile` volare hash.

### Mixed-signal SAR (Option B1 — Python lockstep around the real AFE)

`tb_sar_lockstep.py` runs the 12-bit SAR binary search from `src/sar_fsm.v` in
Python, but **every comparator decision comes from a real ngspice transient of
the sky130 AFE** (`sar_afe.spice`): for each trial code it samples the DC input
on the S/H, lets the DAC settle, and reads the analog `v(cmp_out)`. The whole
sweep runs in one ngspice process (model setup paid once, then ~0.3 s/`tran`).

It reports the measured transfer plus endpoint gain/offset/INL. The historical
hard gate was **monotonic** + **`|offset|`/`|INL| ≤ 8 LSB`**; current sky130 AZ
meets ~**0 LSB offset** in the ECG mid-band but **~14–20 LSB** endpoint INL, with
high-FS railing deferred for mid-biased ECG use. Shuttle silicon still needs
characterization.
### Fully-silicon lockstep (real gate netlist + real AFE)

`test/mixed_signal/` takes B1 one step further: instead of the Python FSM, the
**hardened gate-level netlist** of `sar_digital` (`sky130_fd_sc_hd` cells) runs in
cocotb/iverilog and its `dac_bits`/`cmp_out` interface is wired to the same real
AFE in ngspice. Both halves are real silicon; results match B1 code-for-code.
See [`test/mixed_signal/README.md`](../test/mixed_signal/README.md).

## Layout

See [`mag/README.md`](../mag/README.md). Rebuild:

```sh
cd ../mag && make update_gds
```

RTL cocotb still uses `src/analog_frontend_stub.v` under `-DDIGITAL_CMP_MODEL`.
