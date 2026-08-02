# SPDX-FileCopyrightText: © 2025 davidbroughsmyth
# SPDX-License-Identifier: Apache-2.0

"""cocotb tests for the ECG SAR12 companion ADC."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


def encode_vin_pins(code: int):
    """Map 12-bit code onto ui_in / uio_in[7:5] with <<1 packing."""
    code &= 0xFFE  # even codes only (LSB forced 0 by <<1 encode)
    packed = code >> 1
    ui = packed & 0xFF
    uio = ((packed >> 8) & 0x7) << 5
    return ui, uio


def read_adc_bus(dut):
    adc = (int(dut.uio_out.value) & 0xF) << 8 | (int(dut.uo_out.value) & 0xFF)
    sample_en = (int(dut.uio_out.value) >> 4) & 1
    oe = int(dut.uio_oe.value)
    return adc, sample_en, oe


async def reset_dut(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)


async def wait_sample_en(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        _, se, _ = read_adc_bus(dut)
        if se:
            return read_adc_bus(dut)
    raise TimeoutError("sample_en did not assert")


@cocotb.test()
async def test_bus_contract(dut):
    """uio_oe drives adc[11:8]+sample_en; conversion completes with sample_en."""
    await reset_dut(dut)
    ui, uio = encode_vin_pins(0x800)
    dut.ui_in.value = ui
    dut.uio_in.value = uio

    adc, se, oe = await wait_sample_en(dut)
    assert oe & 0x1F == 0x1F, f"expected oe[4:0]=1, got {oe:08b}"
    assert se == 1
    dut._log.info("bus contract ok adc=0x%03x", adc)


@cocotb.test()
async def test_sar_codes(dut):
    """Digitized codes track pin vin (even codes via <<1 packing)."""
    await reset_dut(dut)

    for target in (0x000, 0x200, 0x800, 0x898, 0xA00, 0xFFE):
        ui, uio = encode_vin_pins(target)
        dut.ui_in.value = ui
        dut.uio_in.value = uio
        # allow idle tracker to latch vin
        await ClockCycles(dut.clk, 10)
        adc, se, _ = await wait_sample_en(dut)
        # drain remaining sample_en stretch
        while se:
            await RisingEdge(dut.clk)
            adc2, se, _ = read_adc_bus(dut)
            if se:
                adc = adc2
        dut._log.info("vin=0x%03x -> adc=0x%03x", target, adc)
        assert adc == target, f"expected 0x{target:03x}, got 0x{adc:03x}"


@cocotb.test()
async def test_sample_rate_fast_sim(dut):
    """Under FAST_SIM, sample_en repeats about every 200 clocks + SAR latency."""
    await reset_dut(dut)
    ui, uio = encode_vin_pins(0x400)
    dut.ui_in.value = ui
    dut.uio_in.value = uio

    await wait_sample_en(dut)
    # count clocks to next sample_en rising after gap
    await RisingEdge(dut.clk)
    while read_adc_bus(dut)[1]:
        await RisingEdge(dut.clk)

    cycles = 0
    while True:
        await RisingEdge(dut.clk)
        cycles += 1
        if read_adc_bus(dut)[1]:
            break
        if cycles > 500:
            raise TimeoutError("second sample_en missing")

    dut._log.info("cycles between sample windows ~= %d", cycles)
    # DIV=200 plus ~12 bit trials + emit stretch
    assert 180 <= cycles <= 280, f"unexpected period {cycles}"
