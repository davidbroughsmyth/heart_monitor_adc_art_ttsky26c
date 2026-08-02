# integrate.tcl — place sar_digital GDS as child of TT top
set TOP tt_um_davidbroughsmyth_ecg_sar12

gds readonly true
gds rescale false
gds read macros/sar_digital/sar_digital.gds
puts "Cells after gds read: [cellname list all]"

load $TOP
box 65um 75um 66um 76um
getcell sar_digital
puts "Instance created at 65,75"

# Power straps
box 3um 80um 70um 82um
paint met4
box 5um 90um 70um 92um
paint met4

# Signal straps
box 100um 60um 120um 62um
paint met2
box 118um 60um 120um 80um
paint met2
box 40um 70um 70um 72um
paint met2

select top cell
save $TOP
puts "Top cell children: [cellname list children]"

file mkdir ../gds
file mkdir ../lef
# Hierarchical GDS (include child geometry)
gds write ../gds/${TOP}.gds
lef write ../lef/${TOP}.lef -hide -pinonly
puts "DONE integrate"
quit -noprompt
