#!/usr/bin/env bash
# Mixed-signal SAR sim (Option B1): Python SAR lockstep around the *real* sky130
# AFE in ngspice (S/H + R-2R CDAC + comparator). Needs volare sky130A + ngspice.
set -euo pipefail
cd "$(dirname "$0")/sky130"

PDK_ROOT="${PDK_ROOT:-$HOME/.volare/volare/sky130/versions/cd1748bb197f9b7af62a54507de6624e30363943}"
export PDK_ROOT
if [[ ! -f "$PDK_ROOT/sky130A/libs.tech/ngspice/sky130.lib.spice" ]]; then
  echo "PDK library not found under PDK_ROOT=$PDK_ROOT" >&2
  echo "Set PDK_ROOT to your volare sky130 version path." >&2
  exit 1
fi

exec python3 tb_sar_lockstep.py "$@"
