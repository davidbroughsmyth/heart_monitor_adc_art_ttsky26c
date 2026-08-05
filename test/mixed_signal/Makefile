# Fully-silicon mixed-signal cosim: hardened sar_digital gate netlist (cocotb/
# iverilog) + real sky130 AFE (ngspice, via afe_ngspice.py). Needs volare sky130A.
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

PDK_ROOT ?= $(HOME)/.volare/volare/sky130/versions/cd1748bb197f9b7af62a54507de6624e30363943
export PDK_ROOT

REPO = $(PWD)/../..
NL   = $(REPO)/mag/openlane/sar_digital/runs/harden_met4/results/final/verilog/gl/sar_digital.v

SIM_BUILD = sim_build/ms
COMPILE_ARGS += -DFUNCTIONAL -DUSE_POWER_PINS -DUNIT_DELAY=\#1

VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
VERILOG_SOURCES += $(NL)
VERILOG_SOURCES += $(PWD)/tb_ms.v

TOPLEVEL = tb_ms
COCOTB_TEST_MODULES = test_ms

include $(shell cocotb-config --makefiles)/Makefile.sim
