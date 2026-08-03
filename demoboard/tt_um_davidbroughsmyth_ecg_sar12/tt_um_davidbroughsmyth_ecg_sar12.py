# SPDX-FileCopyrightText: © 2025 davidbroughsmyth
# SPDX-License-Identifier: Apache-2.0
"""
Hardware-in-the-loop tests for tt_um_davidbroughsmyth_ecg_sar12.

Patterned after TinyTapeout/tt-micropython-firmware examples (factory_test).
Black-box I/O only: drive digital vin proxy, read adc bus + sample_en.
"""

import gc

from ttboard.demoboard import DemoBoard
from ttboard.mode import RPMode
from microcotb.clock import Clock
from microcotb.triggers import RisingEdge, ClockCycles
import microcotb as cocotb

gc.collect()
cocotb.set_runner_scope(__name__)

PROJECT = "tt_um_davidbroughsmyth_ecg_sar12"

# ASIC drives uio[4:0]; Pico drives uio[7:5] vin MSBs + ui_in
UIO_OE_PICO = 0b11100000


def encode_vin_pins(code: int):
    """Map 12-bit even code onto ui_in / uio_in[7:5] (<<1 packing)."""
    code &= 0xFFE
    packed = code >> 1
    ui = packed & 0xFF
    uio = ((packed >> 8) & 0x7) << 5
    return ui, uio


def read_adc_bus(dut):
    uio = int(dut.uio_out.value)
    uo = int(dut.uo_out.value)
    adc = ((uio & 0xF) << 8) | (uo & 0xFF)
    sample_en = (uio >> 4) & 1
    return adc, sample_en


async def reset_dut(dut):
    cocotb.start_soon(Clock(dut.clk, 2, units="us").start())
    dut.ena.value = 1
    dut.uio_oe_pico.value = UIO_OE_PICO
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)


async def wait_sample_en(dut, max_cycles=250000):
    """Wait for sample_en (production divider needs up to ~1e5 clocks)."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        adc, se = read_adc_bus(dut)
        if se:
            return adc, se
    raise TimeoutError("sample_en did not assert")


@cocotb.test()
async def test_bus_and_midscale(dut):
    """After reset, mid-scale vin yields sample_en and adc near 0x800."""
    dut._log.info("ADC HIL: bus + midscale")
    await reset_dut(dut)
    ui, uio = encode_vin_pins(0x800)
    dut.ui_in.value = ui
    dut.uio_in.value = uio
    await ClockCycles(dut.clk, 20)

    adc, se = await wait_sample_en(dut)
    assert se == 1, "sample_en should be high"
    # drain pulse while capturing last code
    last = adc
    for _ in range(8):
        await RisingEdge(dut.clk)
        adc, se = read_adc_bus(dut)
        if se:
            last = adc
    dut._log.info("adc=0x%03x", last)
    assert last == 0x800, f"expected 0x800, got 0x{last:03x}"


@cocotb.test()
async def test_sar_code_sweep(dut):
    """A few even codes track the digital vin proxy."""
    dut._log.info("ADC HIL: code sweep")
    await reset_dut(dut)

    for target in (0x000, 0x200, 0x800, 0xA00, 0xFFE):
        ui, uio = encode_vin_pins(target)
        dut.ui_in.value = ui
        dut.uio_in.value = uio
        await ClockCycles(dut.clk, 20)
        adc, se = await wait_sample_en(dut)
        last = adc
        while se:
            await RisingEdge(dut.clk)
            adc, se = read_adc_bus(dut)
            if se:
                last = adc
        dut._log.info("vin=0x%03x -> adc=0x%03x", target, last)
        assert last == target, f"expected 0x{target:03x}, got 0x{last:03x}"


def _enable_project(tt: DemoBoard):
    if tt.shuttle.has(PROJECT):
        getattr(tt.shuttle, PROJECT).enable()
        return
    found = tt.shuttle.find("ecg_sar")
    if not found:
        found = tt.shuttle.find("sar12")
    if not found:
        raise RuntimeError(f"{PROJECT} not on this shuttle — try shuttle.find()")
    found[0].enable()


def main():
    import ttboard.cocotb.dut
    from microcotb.time.value import TimeValue

    class DUT(ttboard.cocotb.dut.DUT):
        def __init__(self):
            super().__init__("ecg_sar12")
            self.tt = DemoBoard.get()
            self.add_slice_attribute("adc_lo", self.tt.uo_out, 7, 0)
            self.add_slice_attribute("adc_hi", self.tt.uio_out, 3, 0)
            self.add_bit_attribute("sample_en", self.tt.uio_out, 4)

    tt = DemoBoard.get()
    if tt.mode != RPMode.ASIC_RP_CONTROL:
        tt.mode = RPMode.ASIC_RP_CONTROL

    _enable_project(tt)
    tt.uio_oe_pico.value = UIO_OE_PICO
    TimeValue.ReBaseStringUnits = True

    runner = cocotb.get_runner(__name__)
    dut = DUT()
    dut._log.info("enabled %s — running HIL", PROJECT)
    runner.test(dut)
    return runner


if __name__ == "__main__":
    main()
