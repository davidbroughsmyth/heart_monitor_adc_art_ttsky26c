"""Persistent ngspice handle to the real sky130 AFE, for lockstep co-simulation.

One long-lived ``ngspice -p`` process holds the AFE (``sar_afe.spice`` = S/H +
R-2R CDAC + comparator, real ``sky130_fd_pr`` devices).  Model/setup cost (~9 s)
is paid once; each ``compare()`` is a fresh short transient (~0.3 s) that samples
the (DC) input, applies a 12-bit DAC code, and reads the analog comparator.

Used by the fully-silicon cosim (test_ms.py): the real hardened *gate* netlist of
``sar_digital`` runs in cocotb/iverilog and, whenever it presents a new
``dac_bits`` trial, this helper produces the real analog ``cmp_out`` decision.

The class is deliberately synchronous (each send/read completes with no await),
so it is safe to share across cocotb's cooperative single-threaded coroutines.
"""
from __future__ import annotations
import os, re, subprocess, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ANALOG = HERE.parents[1] / "analog" / "sky130"   # repo/analog/sky130
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
    def __init__(self, vin_code: int, settle: str = "4u"):
        self.settle = settle
        self.at = self._measure_at(settle)
        self.vin_code = vin_code
        self._cache: dict[int, int] = {}
        self._n = 0
        self._start()
        self.set_vin(vin_code)

    # ---- lifecycle -------------------------------------------------------
    def _start(self) -> None:
        lib = pdk_lib()
        bit_defs = "\n".join(f"Vb{i} b{i} 0 DC 0" for i in range(NBITS))
        base = f""".title afe_lockstep_base
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
.end
"""
        fd, self._base = tempfile.mkstemp(suffix=".spice", dir=str(ANALOG))
        with os.fdopen(fd, "w") as f:
            f.write(base)
        self.p = subprocess.Popen(
            ["ngspice", "-p"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, bufsize=1, cwd=str(ANALOG))
        self._send(f"source {self._base}")

    def close(self) -> None:
        try:
            self._send("quit")
            self.p.wait(timeout=5)
        except Exception:
            self.p.kill()
        finally:
            for stream in (self.p.stdin, self.p.stdout):
                try:
                    if stream:
                        stream.close()
                except OSError:
                    pass
            try:
                os.unlink(self._base)
            except OSError:
                pass

    # ---- api -------------------------------------------------------------
    def set_vin(self, vin_code: int) -> None:
        """Change the (DC) analog input; invalidates the comparator cache."""
        self.vin_code = vin_code
        self._cache.clear()
        self._send(f"alter Vin = {code_to_volts(vin_code):.6f}")

    def compare(self, dac_code: int) -> int:
        """Return 1 if the real comparator reads HIGH (vhold > vdac(code))."""
        dac_code &= FULL - 1
        if dac_code in self._cache:
            return self._cache[dac_code]
        for i in range(NBITS):
            self._send(f"alter Vb{i} = {VDD if (dac_code >> i) & 1 else 0}")
        self._n += 1
        mark = f"CMPDONE{self._n}"
        self._send(f"tran 20n {self.settle}")
        self._send(f"meas tran cval FIND v(cmp_out) AT={self.at}")
        self._send(f"echo {mark}")
        val = self._read_cval(mark)
        hi = int(val > VTH)
        self._cache[dac_code] = hi
        return hi

    # ---- plumbing --------------------------------------------------------
    def _send(self, cmd: str) -> None:
        assert self.p.stdin is not None
        self.p.stdin.write(cmd + "\n")
        self.p.stdin.flush()

    def _read_cval(self, mark: str) -> float:
        """Read until the echoed marker line, returning the last cval seen."""
        assert self.p.stdout is not None
        val = None
        while True:
            line = self.p.stdout.readline()
            if not line:
                raise RuntimeError(f"ngspice closed before marker {mark}")
            m = _CVAL.search(line)
            if m:
                val = float(m.group(1))
            # marker on its own (not the echoed command line "-> echo MARK")
            if mark in line and "->" not in line:
                if val is None:
                    raise RuntimeError(f"no cval before {mark}: {line!r}")
                return val

    @staticmethod
    def _measure_at(settle: str) -> str:
        v = float(re.sub("[a-zA-Z]", "", settle))
        u = re.sub("[0-9.]", "", settle) or "u"
        return f"{max(v - 0.4, v * 0.9):.3f}{u}"
