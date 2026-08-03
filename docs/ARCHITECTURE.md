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

Rebuild: `cd mag && make update_gds`. See [`mag/README.md`](../mag/README.md).

## ECG code mapping

After external gain, aim for baseline mid-scale codes and R-peaks **≥ 2200** so the
SNN segmenter (`R_PEAK_THRESHOLD`) fires. Full demoboard wiring:
[INTEGRATION.md](INTEGRATION.md).
