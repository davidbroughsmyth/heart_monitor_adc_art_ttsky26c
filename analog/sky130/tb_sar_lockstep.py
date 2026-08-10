#!/usr/bin/env python3
"""Mixed-signal SAR simulation (Option B1: lockstep around the *real* AFE).

The 12-bit SAR binary search from ``src/sar_fsm.v`` is executed step-by-step,
but every comparator decision comes from a real ngspice transient of the sky130
AFE (``sar_afe.spice``).  Track+AZ and hold must be one continuous timeaxis —
re-running ``tran`` after ``alter`` recomputes OP and wipes Chold / AZ caps.

So each vin code is one continuous PWL schedule:
  sample track → sample hold → MSB..LSB bit trials with measuring cmp_out.

Usage:
  PDK_ROOT=... python3 tb_sar_lockstep.py
  python3 tb_sar_lockstep.py 2800 1024 --settle 1u -v
"""
from __future__ import annotations
import argparse, os, re, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
VDD = 1.8
VREF = 1.8
NBITS = 12
FULL = 1 << NBITS
VTH = VDD / 2.0


def pdk_lib() -> str:
    root = os.environ.get(
        "PDK_ROOT",
        str(Path.home() / ".volare/volare/sky130/versions/"
            "cd1748bb197f9b7af62a54507de6624e30363943"),
    )
    lib = Path(root) / "sky130A/libs.tech/ngspice/sky130.lib.spice"
    if not lib.is_file():
        sys.exit(f"PDK ngspice library not found: {lib}\n"
                 f"Set PDK_ROOT to your volare sky130 version path.")
    return str(lib)


def code_to_volts(code: int) -> float:
    return VREF * code / FULL


def parse_settle(settle: str) -> float:
    val = float(re.sub("[a-zA-Z]", "", settle))
    unit = re.sub("[0-9.]", "", settle) or "u"
    mul = {"n": 1e-9, "u": 1e-6, "m": 1e-3, "s": 1.0}.get(unit, 1e-6)
    return val * mul


def run_one(lib: str, vin_code: int, settle_s: float, verbose: bool) -> tuple[int, dict]:
    """Run one continuous SAR conversion; return (adc_code, bit_keeps)."""
    vin = code_to_volts(vin_code)
    t_tr = settle_s
    t_hold = settle_s
    t_bit = settle_s
    # Build bit sources as piecewise: all low until their trial slot, then VDD,
    # then either stay or drop after decision — decided interactively below.
    # For a single continuous pass we need adaptive PWL: do SAR in Python by
    # restarting ONE conversion with predetermined keep decisions via recursive
    # PWL build OR use ngspice stop/alter carefully with PWL extension.
    #
    # Adaptive approach with continuous state: run a master tran in pieces by
    # appending to PWL files via `alter` of PWL sources *without* restarting OP.
    # Easier path: 12 sequential one-shot decks that share the keep so far and
    # replay track/hold + bits 11..k in one continuous PWL each time (proven).
    keeps: dict[int, str] = {}
    cmps: dict[int, float] = {}
    result = 0
    for bit in range(NBITS - 1, -1, -1):
        trial = result | (1 << bit)
        keeps_so_far = dict(keeps)
        adc, bits, bit_cmps = _run_prefix(
            lib, vin_code, vin, settle_s, t_tr, t_hold, t_bit,
            keeps_so_far, trial_bit=bit, trial_code=trial)
        keep = bits[bit]
        cmps[bit] = bit_cmps[bit]
        keeps[bit] = keep
        if keep == "1":
            result |= (1 << bit)
        if verbose:
            print(f"    code={vin_code:5d} bit={bit:2d} keep={keep} "
                  f"cmp={cmps[bit]:.3f} result={result}")
    return result, keeps


def _run_prefix(lib, vin_code, vin, settle_s, t_tr, t_hold, t_bit,
                keeps_so_far, trial_bit, trial_code):
    """Continuous PWL: track+AZ → hold → apply trial_code → measure cmp."""

    def pwl(pts):
        flat = " ".join(f"{tt} {vv}" for tt, vv in pts)
        return f"PWL({flat})"

    sp = [(0.0, VDD), (t_tr, VDD), (t_tr + 0.05 * settle_s, 0.0)]
    t_apply = t_tr + t_hold
    t_end = t_apply + t_bit
    meas_at = t_end - 0.1 * settle_s
    dt = 0.05 * settle_s

    bit_pwls = {}
    for b in range(NBITS):
        # Midscale (b11) during track+AZ+hold, then switch to trial_code
        daz = VDD if b == 11 else 0.0
        vtr = VDD if (trial_code >> b) & 1 else 0.0
        bit_pwls[b] = [
            (0.0, daz), (t_apply, daz), (t_apply + dt, vtr)]

    bit_defs = "\n".join(
        f"Vb{i} b{i} 0 {pwl(bit_pwls[i])}" for i in range(NBITS))
    deck = f""".title sar_lockstep_one
.option scale=1e-6
.lib "{lib}" tt
.include sar_afe.spice
Vdd  vdd  0 DC {VDD}
Vref vref 0 DC {VREF}
Vin  vin_ecg 0 DC {vin:.6f}
Vsample sample 0 {pwl(sp)}
{bit_defs}
Xa vin_ecg vref 0 vdd sample
+ b11 b10 b9 b8 b7 b6 b5 b4 b3 b2 b1 b0
+ cmp_out sar_afe
.control
tran 10n {t_end * 1.02}
meas tran cval FIND v(cmp_out) AT={meas_at}
echo BIT code={vin_code} bit={trial_bit} cmp=$&cval
quit
.endc
.end
"""
    with tempfile.NamedTemporaryFile("w", dir=HERE, suffix=".spice",
                                     delete=False) as f:
        f.write(deck)
        path = f.name
    try:
        out = subprocess.run(["ngspice", "-b", path], cwd=HERE,
                             capture_output=True, text=True, timeout=600).stdout
    finally:
        os.unlink(path)
    m = re.search(
        rf"BIT code={vin_code} bit={trial_bit} cmp=([0-9.eE+-]+)", out)
    if not m:
        sys.exit("ngspice produced no BIT line.\n"
                 f"---- output tail ----\n{out[-2000:]}")
    cmpv = float(m.group(1))
    keep = "1" if cmpv >= VTH else "0"
    bits = dict(keeps_so_far)
    bits[trial_bit] = keep
    cmps = {trial_bit: cmpv}
    adc = sum(1 << b for b, k in bits.items() if k == "1")
    return adc, bits, cmps


def run(lib: str, codes: list[int], settle: str, verbose: bool):
    settle_s = parse_settle(settle)
    results = {}
    bits_all = {}
    for c in codes:
        adc, keeps = run_one(lib, c, settle_s, verbose)
        results[c] = adc
        bits_all[c] = keeps
    return results, bits_all


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("codes", nargs="*", type=int,
                    help="vin codes to convert (default: representative sweep)")
    ap.add_argument("--settle", default="1u",
                    help="per-phase settle (default 1u; aligns with ~SETTLE_CYCLES)")
    ap.add_argument("-v", "--verbose", action="store_true",
                    help="print the MSB->LSB bit-decision trace")
    args = ap.parse_args()

    lib = pdk_lib()
    codes = sorted(args.codes or
                   [0, 1, 256, 1024, 2047, 2048, 2800, 3072, 4000, 4095])
    print(f"# Mixed-signal SAR (B1 lockstep, real sky130 AFE), settle={args.settle}")
    results, bits = run(lib, codes, args.settle, args.verbose)

    print(f"# {'vin':>5} {'adc':>5} {'raw_err':>8}   result")
    adc = [results[c] for c in codes]
    for c, a in zip(codes, adc):
        if args.verbose:
            trace = "".join(bits.get(c, {}).get(b, "?") for b in range(11, -1, -1))
            print(f"    code={c:5d} bits(MSB->LSB)={trace}")
        print(f"  {c:5d} {a:5d} {a - c:+8d}   0x{a:03x}")

    monotonic = all(adc[i] <= adc[i + 1] for i in range(len(adc) - 1))
    lo, hi = codes[0], codes[-1]
    span_in, span_out = hi - lo, adc[-1] - adc[0]
    gain = span_out / span_in if span_in else float("nan")
    offset = adc[0] - gain * lo
    inl = max(abs(a - (gain * c + offset)) for c, a in zip(codes, adc)) \
        if span_in else 0.0
    MAX_LSB = 8.0
    accuracy = (abs(offset) <= MAX_LSB) and (inl <= MAX_LSB)
    ok = monotonic and accuracy
    print(f"# transfer: monotonic={'yes' if monotonic else 'NO'}  "
          f"endpoint-gain={gain:.3f}  offset={offset:+.0f} LSB "
          f"(~{offset * VREF / FULL * 1e3:+.0f} mV)  "
          f"endpoint-INL(max)={inl:.0f} LSB")
    print(f"# gates: |offset|≤{MAX_LSB:.0f} LSB and endpoint |INL|≤{MAX_LSB:.0f} LSB "
          f"({'PASS' if accuracy else 'FAIL'}); "
          f"SETTLE_CYCLES=8 in sar_fsm (~160 ns @ 50 MHz)")
    print(f"# functional (monotonic SAR + accuracy through real AFE): "
          f"{'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
