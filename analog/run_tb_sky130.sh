#!/usr/bin/env bash
# Run sky130 PDK AFE polarity bench (requires volare sky130A + ngspice).
set -euo pipefail
cd "$(dirname "$0")/sky130"

PDK_ROOT="${PDK_ROOT:-$HOME/.volare/volare/sky130/versions/cd1748bb197f9b7af62a54507de6624e30363943}"
LIB="$PDK_ROOT/sky130A/libs.tech/ngspice/sky130.lib.spice"
if [[ ! -f "$LIB" ]]; then
  echo "PDK library not found: $LIB" >&2
  echo "Set PDK_ROOT to your volare sky130 version path." >&2
  exit 1
fi

DECK=$(mktemp)
OUT=$(mktemp)
trap 'rm -f "$DECK" "$OUT"' EXIT

{
  echo ".option scale=1e-6"
  echo ".lib \"$LIB\" tt"
  grep -v '^\.option scale' tb_afe_sky130.spice
} >"$DECK"

ngspice -b "$DECK" >"$OUT" 2>&1

grep -q 'MEASURE_CODE0 cmp=' "$OUT"
grep -q 'MEASURE_CODE4095 cmp=' "$OUT"
grep -q 'MEASURE_CODE2048 cmp=' "$OUT"
grep -q 'MEASURE_CODE3072 cmp=' "$OUT"
grep -q 'AFE_TB_DONE' "$OUT"

python3 - "$OUT" <<'PY'
import re, sys
text = open(sys.argv[1]).read()

def grab(tag):
    m = re.search(rf"MEASURE_{tag} cmp=([0-9.eE+-]+)", text)
    if not m:
        raise SystemExit(f"missing {tag}")
    return float(m.group(1))

c0 = grab("CODE0")
cfs = grab("CODE4095")
c2048 = grab("CODE2048")
c3072 = grab("CODE3072")
print(f"sky130 cmp: code0={c0:.3f} fs={cfs:.3f} 2048={c2048:.3f} 3072={c3072:.3f}")
assert c0 > 0.9, "code0 should be HIGH"
assert cfs < 0.9, "code4095 should be LOW"
assert c2048 > 0.9, "code2048 should be HIGH vs vin~2800"
assert c3072 < 0.9, "code3072 should be LOW vs vin~2800"
print("analog sky130 AFE checks PASS")
PY
