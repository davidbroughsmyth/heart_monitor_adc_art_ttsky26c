"""Fully-silicon mixed-signal lockstep cosim.

The real hardened *gate-level netlist* of ``sar_digital`` (sky130_fd_sc_hd cells)
runs in cocotb/iverilog.  Each time its SAR presents a new ``dac_bits`` trial we
produce the comparator decision from the real sky130 AFE in ngspice
(``afe_ngspice.AFE``) and drive it back on ``cmp_out`` -- a true cycle-accurate
lockstep of synthesized silicon logic + the real analog front-end.

For every input we check that the silicon-logic result (``uo_out``/``uio_out``)
matches an independent binary-search reference driven by the *same* AFE.  That
proves the hardened gates implement the SAR correctly against the real analog
comparator (not a behavioural stub).

Env:
  MS_CODES   whitespace-separated vin codes (default "1024 2800")
  PDK_ROOT   volare sky130 path (afe_ngspice + Makefile)
"""
import os
import cocotb
from cocotb.triggers import Timer

from afe_ngspice import AFE


def _int(sig):
    try:
        return int(sig.value)
    except Exception:      # unresolved x/z (e.g. during reset)
        return None


def ref_sar(afe: AFE) -> int:
    """Ideal 12-bit binary search using the SAME real AFE comparator."""
    result = 0
    for bit in range(11, -1, -1):
        if afe.compare(result | (1 << bit)):
            result |= (1 << bit)
    return result


async def capture_conversion(dut) -> int:
    """Wait for sample_en (uio_out[4]) and return the 12-bit adc_out."""
    while True:
        await dut.uio_out.value_change
        uio = _int(dut.uio_out)
        if uio is None:
            continue
        if (uio >> 4) & 1:                       # sample_en asserted
            uo = _int(dut.uo_out)
            return ((uio & 0xF) << 8) | (uo & 0xFF)


@cocotb.test()
async def fully_silicon_lockstep(dut):
    codes = [int(c) for c in os.environ.get("MS_CODES", "1024 2800").split()]
    afe = AFE(codes[0])

    stop = {"flag": False}

    async def serve():
        """Drive cmp_out from the real AFE on every new dac_bits trial."""
        last = None
        while not stop["flag"]:
            await dut.dac_bits.value_change
            code = _int(dut.dac_bits)
            if code is None or code == last:
                continue
            dut.cmp_out.value = afe.compare(code)
            last = code

    try:
        # Reset (synchronous inside the netlist): hold rst_n low a few cycles.
        dut.rst_n.value = 0
        dut.cmp_out.value = 0
        await Timer(200, "ns")
        dut.rst_n.value = 1

        cocotb.start_soon(serve())
        c0 = _int(dut.dac_bits)
        if c0 is not None:
            dut.cmp_out.value = afe.compare(c0)

        cocotb.log.info("fully-silicon SAR: real gate netlist + real sky130 AFE")
        cocotb.log.info(f"{'vin':>5} {'adc(gl)':>8} {'ref':>5} {'raw_err':>8}  match")
        fails = 0
        prev = None
        for i, code in enumerate(codes):
            if i > 0:
                afe.set_vin(code)                 # next conversion uses new vin
            adc = await capture_conversion(dut)   # real silicon logic result
            ref = ref_sar(afe)                    # same-AFE binary-search reference
            ok = (adc == ref)
            fails += not ok
            monotonic = "" if prev is None else (" mono" if adc >= prev else " NON-MONO")
            prev = adc
            cocotb.log.info(
                f"{code:5d} {adc:8d} {ref:5d} {adc - code:+8d}  "
                f"{'OK' if ok else 'MISMATCH'}{monotonic}")
            assert ok, (f"gate-netlist adc={adc} != reference {ref} "
                        f"for vin_code={code} (same real AFE)")
    finally:
        stop["flag"] = True
        afe.close()

    cocotb.log.info(
        "PASS: hardened gate netlist + real sky130 AFE agree with the "
        "same-AFE SAR reference on every input.")
