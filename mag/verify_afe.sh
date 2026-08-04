#!/usr/bin/env bash
# verify_afe.sh CELL REF_SPICE REF_SUBCKT
# Build (run BUILD_TCL first if given via env), extract, DRC, netgen LVS.
set -euo pipefail
CELL="$1"; REF="$2"; SUB="$3"
PDK=/build/pdk/sky130A
RC=$PDK/libs.tech/magic/sky130A.magicrc
NGSETUP=$PDK/libs.tech/netgen/sky130A_setup.tcl

echo "=== build $CELL (fresh) ==="
rm -f "${CELL}.mag" "${CELL}.ext" "${CELL}.ext.spice" "${CELL}.lvs.out"
magic -noconsole -dnull -rcfile "$RC" "${BUILD_TCL:-afe_${CELL#afe_}.tcl}" 2>&1 | grep -Ei "BBOX|error|abort" || true

echo "=== extract $CELL ==="
CELL="$CELL" magic -noconsole -dnull -rcfile "$RC" extract_cell.tcl 2>&1 | grep -Ei "EXTRACT_DONE|error" || true
echo "=== signoff DRC $CELL (GDS round-trip) ==="
CELL="$CELL" magic -noconsole -dnull -rcfile "$RC" drc_cell.tcl 2>&1 | grep -Ei "errors found|error tiles" || true

echo "=== netgen LVS $CELL vs $REF ($SUB) ==="
netgen -batch lvs "${CELL}.ext.spice ${CELL}" "$REF $SUB" "$NGSETUP" "${CELL}.lvs.out" 2>&1 | tail -5 || true
echo "--- LVS summary ---"
grep -E "Circuits match|do not match|uncmatched|Netlists|net.*mismatch|property|Final result" "${CELL}.lvs.out" | tail -20 || true
