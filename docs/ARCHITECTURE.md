# Architecture — heart_monitor_adc

Mixed-signal **12-bit SAR ADC** for Tiny Tapeout (`tt_um_davidbroughsmyth_ecg_sar12`),
companion to [snn_lif_neurons_ttsky26c](https://github.com/davidbroughsmyth/snn_lif_neurons_ttsky26c).

Datasheet: [info.md](info.md) · Component sheet: [DATASHEET.md](DATASHEET.md) · User manual: [USER_MANUAL.md](USER_MANUAL.md) · Integration: [INTEGRATION.md](INTEGRATION.md)

## System context

```mermaid
flowchart LR
  ecg[ECG_front_end] --> ua0[ua0_vin_ecg]
  vref[Vref] --> ua1[ua1_vref]
  ua0 --> adc[ADC_tile]
  ua1 --> adc
  adc -->|adc_bus_sample_en| snn[SNN_tile]
  clk[clk_50MHz] --> adc
  clk --> snn
```

External instrumentation amp / bandpass drives `ua[0]`. The ADC tile digitizes at
~500 SPS and presents a parallel 12-bit sample plus `sample_en` for the SNN.

## Mixed-signal block diagram

```mermaid
flowchart TB
  subgraph pads [Tiny_Tapeout_pads]
    ua0[ua0_vin_ecg]
    ua1[ua1_vref]
    ui[ui_vin_sim]
    uo[uo_adc_lo]
    uio[uio_adc_hi_sample_en]
  end

  subgraph afe [AFE]
    sh[SampleHold]
    cdac[CDAC_12b]
    cmp[Comparator]
  end

  subgraph dig [Digital]
    rate[rate_divider]
    sar[sar_fsm]
  end

  ua0 --> sh
  ua1 --> cdac
  sh --> cmp
  cdac --> cmp
  cmp -->|cmp_out| sar
  sar -->|sample| sh
  sar -->|dac_bits| cdac
  rate -->|convert_strobe| sar
  sar --> uo
  sar --> uio
  ui -.->|sim_only| sar
```

| Block | Role | Sources |
|---|---|---|
| `rate_divider` | 50 MHz → 500 Hz convert strobe | [`src/rate_divider.v`](../src/rate_divider.v) |
| `sar_fsm` | Track/hold control, 12 MSB-first trials, emit bus | [`src/sar_fsm.v`](../src/sar_fsm.v) |
| AFE | S/H + binary CDAC + comparator | [`analog/sar_afe.spice`](../analog/sar_afe.spice), [`mag/`](../mag/) |
| Stub | Behavioral CMP for cocotb | [`src/analog_frontend_stub.v`](../src/analog_frontend_stub.v) |

## Logical circuit (AFE + SAR digital)

Element-level view of the silicon path: AFE nets feed `sar_digital`
([`src/sar_digital.v`](../src/sar_digital.v) = `rate_divider` + `sar_fsm`).

```mermaid
flowchart TB
  subgraph afeDetail [AFE]
    vin[ua0_vin_ecg] --> tg[TG_sample]
    tg --> vhold[vhold]
    chold[Chold] --- vhold
    vref[ua1_vref] --> dac[DAC_12b]
    bits[dac_bits_11_0] --> dac
    dac --> vdac[vdac]
    vhold --> cmp[Comparator]
    vdac --> cmp
    cmp --> cmpOut[cmp_out]
  end

  subgraph digDetail [SAR_digital]
    clk[clk_50MHz] --> rate[rate_divider]
    rate --> strobe[convert_strobe]
    strobe --> fsm[sar_fsm]
    cmpOut --> fsm
    fsm --> sample[sample]
    fsm --> bits
    fsm --> adcOut[adc_out_12]
    fsm --> sampleEn[sample_en]
    fsm --> busy[busy]
  end

  sample --> tg
  adcOut --> pack[uo_uio_pack]
  sampleEn --> pack
  pack --> uoPads[uo_adc_7_0]
  pack --> uioPads[uio_adc_11_8_sample_en]
```

**AFE elements** ([`analog/sar_afe.spice`](../analog/sar_afe.spice), [`analog/sky130/`](../analog/sky130/)):

- **TG + Chold** — `sample=1` tracks `vin_ecg` onto `vhold`; `sample=0` holds.
- **DAC_12b** — `vref` + `dac_bits[11:0]` → trial voltage `vdac`. Ideal SPICE is a capacitive CDAC; sky130 first-pass SPICE uses an R-2R ladder + TG switches.
- **Comparator** — `cmp_out=1` when `vhold >= vdac`.

**SAR digital elements:**

- **`rate_divider`** — `clk` → `convert_strobe` at 500 SPS (100000 cycles @ 50 MHz).
- **`sar_fsm`** — on strobe: hold, walk bits 11→0, emit `adc_out` and pulse `sample_en` (see [SAR convert sequence](#sar-convert-sequence)).
- **Pad packing** — `uo[7:0]=adc[7:0]`; `uio[3:0]=adc[11:8]`; `uio[4]=sample_en`; `uio_oe=0b00011111`.

## SAR convert sequence

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> Sample: convert_strobe
  Sample --> BitTrial: sample_low_dac_MSB
  BitTrial --> BitTrial: next_bit
  BitTrial --> Emit: bit0_done
  Emit --> Idle: sample_en_done
```

1. **Idle** — `sample=1` (track); wait for `convert_strobe`.
2. **Sample** — `sample=0` (hold); prime `dac_bits` with MSB trial.
3. **BitTrial** — for bits 11…0: settle DAC, sample `cmp_out` (`vin_hold >= dac`), update result.
4. **Emit** — drive `adc_out`, pulse `sample_en` for 4 clocks, return to track.

Production: one convert every `50e6/500 = 100000` clocks. SAR latency is ~12–20 clocks,
so most of the period is idle.

## Sim vs silicon

```mermaid
flowchart TB
  subgraph rtl_sim [RTL_cocotb]
    pins[ui_uio_vin_proxy]
    stub[analog_frontend_stub]
    fsm1[sar_fsm_DIGITAL_CMP_MODEL]
    pins --> stub
    stub -->|cmp_out| fsm1
  end

  subgraph silicon [Silicon_path]
    ua[ua0_ua1]
    magAfe[Magic_AFE]
    hard[sar_digital_OpenLane]
    ua --> magAfe
    magAfe -->|cmp_out| hard
    hard -->|sample_dac_bits| magAfe
  end
```

| Path | Vin | Comparator |
|---|---|---|
| Cocotb | `{uio_in[7:5], ui_in} << 1` | `-DDIGITAL_CMP_MODEL` / stub |
| Silicon | `ua[0]` / `ua[1]` | Layout AFE → `cmp_out` |

Hardened digital macro: [`mag/macros/sar_digital/`](../mag/macros/sar_digital/)
(`src/sar_digital.v` wraps FSM + rate divider, no stub).

## Layout floorplan (1×2)

Approximate regions inside `tt_analog_1x2` (~161 × 226 µm):

```mermaid
flowchart TB
  subgraph tile [tt_um_1x2]
    pwr[VDPWR_VGND_met4_stripes]
    afeR[AFE_S_H_CDAC_CMP_metal]
    digR[sar_digital_90x140]
  end
  pwr --- afeR
  afeR --- digR
```

- Left: vertical `VDPWR` / `VGND` met4 stripes from DEF init.
- Lower / mid: AFE metal topology (`layout_afe.tcl`); `ua[0]`/`ua[1]` strapped in.
- Upper: OpenLane `sar_digital` child (met4-max, no met5).
- AFE: best-effort `sky130_fd_pr` gencells (not LVS-complete).

Rebuild: `cd mag && make update_gds`. See [`mag/README.md`](../mag/README.md)
(analog custom_gds — not digital `tt_tool` local-harden).

## ECG code mapping

After external gain, aim for baseline mid-scale codes and R-peaks **≥ 2200** so the
SNN segmenter (`R_PEAK_THRESHOLD`) fires. Full demoboard wiring:
[INTEGRATION.md](INTEGRATION.md).
