#!/usr/bin/env bash
# Run ngspice AFE bench and check comparator polarity.
set -euo pipefail
cd "$(dirname "$0")"

OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

ngspice -b tb_afe.spice >"$OUT" 2>&1

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
print(f"cmp: code0={c0:.3f} fs={cfs:.3f} 2048={c2048:.3f} 3072={c3072:.3f}")
assert c0 > 0.9, "code0 should be HIGH"
assert cfs < 0.9, "code4095 should be LOW"
assert c2048 > 0.9, "code2048 should be HIGH vs vin~2800"
assert c3072 < 0.9, "code3072 should be LOW vs vin~2800"
print("analog AFE checks PASS")
PY
