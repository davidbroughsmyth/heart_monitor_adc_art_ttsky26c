# layout_afe.tcl — metal-only AFE placeholders (DRC-safe for TT precheck)
# Topology markers: S/H MOM, CDAC plates, CMP area.
# PDK schematic first-pass lives in analog/sky130/; real-device Mag gencells
# spilled outside the die and broke LEF ORIGIN/SIZE — deferred until placed
# in a hierarchical child with FIXED_BBOX.

set TOP tt_um_davidbroughsmyth_ecg_sar12
load $TOP

# Hold MOM (met2/met3) near ua[0]
box 120um 20um 145um 35um
paint met2
box 122um 22um 143um 33um
paint met3
label vhold FreeSans 0.5 -met3

# Sample strap (met2) — digital drives this later
box 110um 26um 120um 28um
paint met2
label sample FreeSans 0.4 -met2

# CDAC binary met1/met2 fingers
set x0 20.0
set y0 40.0
set uh 3.0
set uw 1.5
set gap 0.5
set x $x0
for {set i 0} {$i < 12} {incr i} {
    set n [expr {1 << $i}]
    set fingers [expr {$n > 16 ? 16 : $n}]
    set h [expr {$fingers * ($uh + $gap)}]
    if {$h > 80} { set h 80 }
    box ${x}um ${y0}um [expr {$x+$uw}]um [expr {$y0+$h}]um
    paint met1
    box [expr {$x+0.2}]um [expr {$y0+0.2}]um [expr {$x+$uw-0.2}]um [expr {$y0+$h-0.2}]um
    paint met2
    label b$i FreeSans 0.3 -met1
    set x [expr {$x + $uw + 1.0}]
}

# vdac / vref metal stubs
box 20um 125um 55um 130um
paint met3
label vdac FreeSans 0.5 -met3
box 20um 135um 55um 138um
paint met4
label vref_afe FreeSans 0.4 -met4

# Comparator area: met1/met2 stages (no poly/diff)
set cx 70.0
set cy 50.0
for {set s 0} {$s < 4} {incr s} {
    set xx [expr {$cx + $s * 8}]
    box ${xx}um ${cy}um [expr {$xx+3}]um [expr {$cy+4}]um
    paint met1
    box ${xx}um [expr {$cy+5}]um [expr {$xx+3}]um [expr {$cy+9}]um
    paint met2
    box [expr {$xx+0.5}]um [expr {$cy+3.5}]um [expr {$xx+2.5}]um [expr {$cy+5.5}]um
    paint met3
}
box 100um 55um 108um 60um
paint met1
label cmp_out FreeSans 0.5 -met1

# Digital keepout label (no fill)
box 70um 100um 155um 210um
label sar_digital_area FreeSans 1.0 -met4

# Wire ua[0]/1] pins into adjacent met4 (TT analog pin check)
# ua[0] @ 151.81–152.71, 0–1 → hold MOM
box 151.81um 0.50um 152.71um 30um
paint met4
box 145um 28um 152.71um 30um
paint met4
# ua[1] @ 132.49–133.39, 0–1 → vref rail
box 132.49um 0.50um 133.39um 138um
paint met4
box 55um 135um 133.39um 138um
paint met4

save $TOP
file mkdir ../gds
file mkdir ../lef
gds write ../gds/${TOP}.gds
lef write ../lef/${TOP}.lef -hide -pinonly
puts "AFE metal-only layout painted"
quit -noprompt
