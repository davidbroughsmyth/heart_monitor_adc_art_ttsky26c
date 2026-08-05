#!/usr/bin/env bash
# Fully-silicon mixed-signal cosim: hardened sar_digital gate netlist
# (cocotb/iverilog) + real sky130 AFE (ngspice). Needs volare sky130A, iverilog,
# ngspice, and the OpenLane harden run (mag/openlane/.../gl/sar_digital.v).
#
#   ./run_ms.sh                       # default codes (1024 2800)
#   MS_CODES="256 1024 2048 4095" ./run_ms.sh
set -euo pipefail
cd "$(dirname "$0")"

[ -f ../.venv/bin/activate ] && source ../.venv/bin/activate
export PDK_ROOT="${PDK_ROOT:-$HOME/.volare/volare/sky130/versions/cd1748bb197f9b7af62a54507de6624e30363943}"

NL="../../mag/openlane/sar_digital/runs/harden_met4/results/final/verilog/gl/sar_digital.v"
if [[ ! -f "$NL" ]]; then
  echo "Hardened gate netlist not found: $NL" >&2
  echo "Run the OpenLane harden first (cd mag && make harden)." >&2
  exit 1
fi

exec make "$@"
