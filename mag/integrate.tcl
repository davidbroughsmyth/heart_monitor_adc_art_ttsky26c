# integrate.tcl — place sar_digital and strap AFE ↔ digital signal pins
# Do NOT paint met4 across VDPWR/VGND stripes (shorts power).
set TOP tt_um_davidbroughsmyth_ecg_sar12

gds readonly true
gds rescale false
gds read macros/sar_digital/sar_digital.gds
puts "Cells after gds read: [cellname list all]"

load $TOP
set DX 65
set DY 75
box ${DX}um ${DY}um [expr {$DX+1}]um [expr {$DY+1}]um
getcell sar_digital
puts "Instance created at $DX,$DY"

# sample @ local (35.51, 0) → abs (~100.5, 75)
box 100um 18um 102um 76um
paint met2
label sample_route FreeSans 0.3 -met2

# cmp_out @ local (86, 74.84) → abs (~151, 149.8)
box 65um 52um 150um 54um
paint met1
box 148um 52um 150um 150um
paint met1
label cmp_route FreeSans 0.3 -met1

# dac_bits stubs toward CDAC (met1/met2 only — no met4 power bridges)
box 148um 8um 150um 90um
paint met2
for {set i 0} {$i < 12} {incr i} {
    set y [expr {10 + $i * 3}]
    box 60um ${y}um 148um [expr {$y + 0.4}]um
    paint met1
}

select top cell
save $TOP
puts "Top cell children: [cellname list children]"

file mkdir ../gds
file mkdir ../lef
gds write ../gds/${TOP}.gds
lef write ../lef/${TOP}.lef -hide -pinonly
puts "DONE integrate"
quit -noprompt
