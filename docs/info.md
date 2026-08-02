<!---
Tiny Tapeout datasheet content for ecg_sar12
-->

## How it works

`tt_um_davidbroughsmyth_ecg_sar12` is a **12-bit successive-approximation (SAR) ADC**
companion for the [SNN heart monitor](https://github.com/davidbroughsmyth/snn_lif_neurons_ttsky26c).

1. A **rate divider** derives a convert strobe at **500 SPS** from the 50 MHz `clk`
   (`50e6 / 500 = 100000` cycles). Cocotb RTL tests use `FAST_SIM` (250 kSPS) only.
2. On each strobe the **SAR FSM** holds the input level and runs 12 MSB-first bit trials.
3. When complete, the 12-bit result is presented on the **same parallel bus** the SNN
   consumes, and **`sample_en` is pulsed** for several clocks.

| ADC output | SNN input |
|---|---|
| `uo[7:0]` = `adc[7:0]` | `ui_in[7:0]` |
| `uio[3:0]` = `adc[11:8]` | `uio_in[3:0]` |
| `uio[4]` = `sample_en` | `uio_in[4]` |

**Silicon analog inputs:** `ua[0]` = `vin_ecg`, `ua[1]` = `vref`. The SAR drives
`sample` / `dac_bits` into the AFE and consumes `cmp_out`. Ideal SPICE for that path
lives in [`analog/`](../analog/) (`sar_afe` = S/H + CDAC + comparator).

**Digital sim:** `ui_in` / `uio_in[7:5]` are a **sim-only** vin proxy
(`{uio_in[7:5], ui_in} << 1`, even codes 0…4094). Cocotb builds with
`-DDIGITAL_CMP_MODEL` and `analog_frontend_stub.v` so no SPICE is required; replace
the stub with the layout AFE for silicon.

Target ECG mapping (after external gain): baseline mid-low codes, R-peaks **≥ 2200**
so the SNN segmenter fires (`R_PEAK_THRESHOLD`).

## How to test

```sh
cd test
python3.13 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
make -B
```

Cocotb checks: `uio_oe` bus contract, SAR code tracking, and `sample_en` period under `FAST_SIM`.

```sh
cd analog && ./run_tb.sh   # ngspice AFE comparator polarity
```

## External hardware

- **ECG front-end PMOD** (instrumentation amp + ~0.5–40 Hz bandpass) into `ua[0]`.
- Wire this tile’s digital ADC bus to `tt_um_snn_lif_neuron` as in the table above;
  share `clk`, `rst_n`, and GND.
- Optional lab path: MCU + commercial 12-bit SAR (ADS7886 / MCP3201) driving the same
  bus before silicon analog is ready.

See [INTEGRATION.md](INTEGRATION.md) for demoboard wiring details.
