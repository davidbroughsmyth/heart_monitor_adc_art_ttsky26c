# drc_cell.tcl — accurate signoff DRC via GDS round-trip (cell from $env(CELL)).
# Building then re-reading the GDS clears Magic's incremental "check" tiles so
# drc reports real rule violations only.
set CELL $env(CELL)
load $CELL
gds write ${CELL}.gds
def read /dev/null
gds read ${CELL}.gds
load $CELL
select top cell
drc euclidean on
drc check
drc catchup
drc count total
quit -noprompt
