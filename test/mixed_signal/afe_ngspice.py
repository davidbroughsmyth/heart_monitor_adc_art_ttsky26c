"""Persistent helper: real sky130 AFE comparator decisions for lockstep co-sim.

Each ``set_vin`` / ``compare`` runs a *fresh continuous* ngspice deck
(track+AZ → hold → apply dac_code → meas). Restarting ``tran`` after
``alter`` recomputes OP and wipes Chold / AZ capacitors, so we avoid that.
"""
from __future__ import annotations
import os, re, subprocess, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ANALOG = HERE.parents[1] / "analog" / "sky130"
VDD = 1.8
VREF = 1.8
NBITS = 12
FULL = 1 << NBITS
VTH = VDD / 2.0
_CVAL = re.compile(r"cval\s*=\s*([0-9.eE+-]+)")


def pdk_lib() -> str:
    root = os.environ.get(
        "PDK_ROOT",
        str(Path.home() / ".volare/volare/sky130/versions/"
            "cd1748bb197f9b7af62a54507de6624e30363943"),
    )
    lib = Path(root) / "sky130A/libs.tech/ngspice/sky130.lib.spice"
    if not lib.is_file():
        raise FileNotFoundError(
            f"PDK ngspice library not found: {lib}\n"
            f"Set PDK_ROOT to your volare sky130 version path.")
    return str(lib)


def code_to_volts(code: int) -> float:
    return VREF * code / FULL


class AFE:
    def __init__(self, vin_code: int, settle: str = "1u"):
        self.settle = settle
        self.settle_s = self._parse_settle(settle)
        self.vin_code = vin_code
        self._cache: dict[int, int] = {}

    def close(self) -> None:
        pass

    def set_vin(self, vin_code: int) -> None:
        self.vin_code = vin_code
        self._cache.clear()

    def compare(self, dac_code: int) -> int:
        dac_code &= FULL - 1
        if dac_code in self._cache:
            return self._cache[dac_code]
        vin = code_to_volts(self.vin_code)
        t_tr = self.settle_s
        t_hold = self.settle_s
        t_bit = self.settle_s
        t_end = t_tr + t_hold + t_bit
        meas_at = t_end - 0.1 * self.settle_s
        sp = f"PWL(0 {VDD} {t_tr} {VDD} {t_tr + 0.05 * self.settle_s} 0)"
        bit_defs = []
        for i in range(NBITS):
            v = VDD if (dac_code >> i) & 1 else 0.0
            # after hold, apply the full trial code in one step
            bit_defs.append(
                f"Vb{i} b{i} 0 PWL(0 0 {t_tr + t_hold} 0 "
                f"{t_tr + t_hold + 0.05 * self.settle_s} {v})")
        deck = f""".title afe_one_shot
.option scale=1e-6
.lib "{pdk_lib()}" tt
.include sar_afe.spice
Vdd  vdd  0 DC {VDD}
Vref vref 0 DC {VREF}
Vin  vin_ecg 0 DC {vin:.6f}
Vsample sample 0 {sp}
{chr(10).join(bit_defs)}
Xa vin_ecg vref 0 vdd sample
+ b11 b10 b9 b8 b7 b6 b5 b4 b3 b2 b1 b0
+ cmp_out sar_afe
.control
tran 10n {t_end * 1.02}
meas tran cval FIND v(cmp_out) AT={meas_at}
echo CMPDONE
quit
.endc
.end
"""
        with tempfile.NamedTemporaryFile("w", dir=str(ANALOG), suffix=".spice",
                                         delete=False) as f:
            f.write(deck)
            path = f.name
        try:
            out = subprocess.run(
                ["ngspice", "-b", path], cwd=str(ANALOG),
                capture_output=True, text=True, timeout=300).stdout
        finally:
            os.unlink(path)
        m = _CVAL.search(out)
        if not m:
            raise RuntimeError(f"no cval in ngspice out:\n{out[-1500:]}")
        hi = int(float(m.group(1)) > VTH)
        self._cache[dac_code] = hi
        return hi

    @staticmethod
    def _parse_settle(settle: str) -> float:
        v = float(re.sub("[a-zA-Z]", "", settle))
        u = re.sub("[0-9.]", "", settle) or "u"
        return v * {"n": 1e-9, "u": 1e-6, "m": 1e-3, "s": 1.0}.get(u, 1e-6)
