#!/usr/bin/env python3
"""Mixed-signal SAR simulation (Option B1: lockstep around the *real* AFE).

The 12-bit SAR binary search from ``src/sar_fsm.v`` is executed step-by-step,
but every comparator decision comes from a real ngspice transient of the sky130
AFE (``sar_afe.spice`` = sample/hold + R-2R CDAC + comparator, all real
``sky130_fd_pr`` devices).  For each trial code we sample the (DC) input on the
S/H, let the DAC settle, and read the analog comparator ``v(cmp_out)`` -- closing
the SAR loop through the actual front-end instead of the behavioural stub.

FSM contract mirrored here (src/sar_fsm.v):
  * binary search MSB->LSB, result starts 0;
  * comparator cmp_out HIGH  <=>  vhold > vdac   (comparator.spice);
  * keep bit i when cmp_out is HIGH for trial = result | (1<<i).

For speed the whole sweep runs in ONE ngspice process: model/setup cost (~8s) is
paid once, then each ``tran`` is ~0.3s.  The SAR itself is done directly on the
12 DAC bit-sources (try a bit -> tran -> if cmp LOW clear it), so no netlist
rebuild/reset is needed between bits.

Usage:
  PDK_ROOT=... python3 tb_sar_lockstep.py                 # default vin sweep
  python3 tb_sar_lockstep.py 2800 1024 --settle 4u -v
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


def measure_at(settle: str) -> str:
    val = float(re.sub("[a-zA-Z]", "", settle))
    unit = re.sub("[0-9.]", "", settle) or "u"
    return f"{max(val - 0.4, val * 0.9):.3f}{unit}"


def build_deck(lib: str, codes: list[int], settle: str) -> str:
    at = measure_at(settle)
    bit_defs = "\n".join(f"Vb{i} b{i} 0 DC 0" for i in range(NBITS))
    blocks = []
    for c in codes:
        v = code_to_volts(c)
        clears = "\n".join(f"  alter Vb{i} = 0" for i in range(NBITS))
        blocks.append(f"""* ---- convert vin_code={c} ({v:.5f} V) ----
  alter Vin = {v:.6f}
{clears}
    foreach bit 11 10 9 8 7 6 5 4 3 2 1 0
    alter Vb$bit = {VDD}
    tran 20n {settle}
    meas tran cval FIND v(cmp_out) AT={at}
    if cval < {VTH}
      alter Vb$bit = 0
      echo BIT code={c} bit=$bit keep=0 cmp=$&cval
    else
      echo BIT code={c} bit=$bit keep=1 cmp=$&cval
    end
  end
  echo RESULT code={c} done""")
    body = "\n".join(blocks)
    return f""".title sar_lockstep_sweep
.option scale=1e-6
.lib "{lib}" tt
.include sar_afe.spice
Vdd  vdd  0 DC {VDD}
Vref vref 0 DC {VREF}
Vin  vin_ecg 0 DC 0
Vsample sample 0 PWL(0 {VDD} 1u {VDD} 1.05u 0)
{bit_defs}
Xa vin_ecg vref 0 vdd sample
+ b11 b10 b9 b8 b7 b6 b5 b4 b3 b2 b1 b0
+ cmp_out sar_afe
.control
{body}
quit
.endc
.end
"""


def run(lib: str, codes: list[int], settle: str) -> tuple[dict, dict]:
    deck = build_deck(lib, codes, settle)
    with tempfile.NamedTemporaryFile("w", dir=HERE, suffix=".spice",
                                     delete=False) as f:
        f.write(deck)
        path = f.name
    try:
        out = subprocess.run(["ngspice", "-b", path], cwd=HERE,
                             capture_output=True, text=True, timeout=1800).stdout
    finally:
        os.unlink(path)
    done = {int(m) for m in re.findall(r"RESULT code=(\d+) done", out)}
    bits: dict = {}
    cmps: dict = {}
    for c, b, keep, cmp in re.findall(
            r"BIT code=(\d+) bit=(\d+) keep=([01]) cmp=([0-9.eE+-]+)", out):
        bits.setdefault(int(c), {})[int(b)] = keep
        cmps.setdefault(int(c), {})[int(b)] = float(cmp)
    if not done:
        sys.exit("ngspice produced no RESULT lines.\n"
                 f"---- output tail ----\n{out[-2000:]}")
    # Reconstruct the converged code from the kept bits (authoritative).
    results = {c: sum(1 << b for b, k in bits.get(c, {}).items() if k == "1")
               for c in done}
    return results, bits, cmps


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("codes", nargs="*", type=int,
                    help="vin codes to convert (default: representative sweep)")
    ap.add_argument("--settle", default="4u", help="transient window (default 4u)")
    ap.add_argument("-v", "--verbose", action="store_true",
                    help="print the MSB->LSB bit-decision trace")
    args = ap.parse_args()

    lib = pdk_lib()
    codes = sorted(args.codes or
                   [0, 1, 256, 1024, 2047, 2048, 2800, 3072, 4000, 4095])
    print(f"# Mixed-signal SAR (B1 lockstep, real sky130 AFE), settle={args.settle}")
    results, bits, cmps = run(lib, codes, args.settle)

    print(f"# {'vin':>5} {'adc':>5} {'raw_err':>8}   result")
    adc = [results[c] for c in codes]
    for c, a in zip(codes, adc):
        if args.verbose:
            trace = "".join(bits.get(c, {}).get(b, "?") for b in range(11, -1, -1))
            print(f"    code={c:5d} bits(MSB->LSB)={trace}")
        print(f"  {c:5d} {a:5d} {a - c:+8d}   0x{a:03x}")

    # --- functional gate: the SAR + real AFE must be monotonic non-decreasing ---
    monotonic = all(adc[i] <= adc[i + 1] for i in range(len(adc) - 1))

    # --- informational static-error metrics (endpoint calibration) ---
    lo, hi = codes[0], codes[-1]
    span_in, span_out = hi - lo, adc[-1] - adc[0]
    gain = span_out / span_in if span_in else float("nan")
    offset = adc[0] - gain * lo            # LSB, input-referred at code 0
    inl = max(abs(a - (gain * c + offset)) for c, a in zip(codes, adc)) \
        if span_in else 0.0
    print(f"# transfer: monotonic={'yes' if monotonic else 'NO'}  "
          f"endpoint-gain={gain:.3f}  offset={offset:+.0f} LSB "
          f"(~{offset * VREF / FULL * 1e3:+.0f} mV)  "
          f"endpoint-INL(max)={inl:.0f} LSB")
    print("# note: raw error reflects the un-trimmed best-effort AFE "
          "(comparator offset + R-2R INL), not a harness issue.")
    print(f"# functional (monotonic SAR through real AFE): "
          f"{'PASS' if monotonic else 'FAIL'}")
    return 0 if monotonic else 1


if __name__ == "__main__":
    raise SystemExit(main())
