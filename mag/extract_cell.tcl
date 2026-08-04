# extract_cell.tcl — DRC count + extract to <CELL>.ext.spice (cell from $env(CELL))
set CELL $env(CELL)
load $CELL
select top cell
drc euclidean on
drc check
drc catchup
set cnt [drc list count total]
puts "DRC_COUNT $cnt"
extract do local
extract all
ext2spice lvs
ext2spice -o ${CELL}.ext.spice
puts "EXTRACT_DONE ${CELL}.ext.spice"
quit -noprompt
