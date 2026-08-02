# layout_afe.tcl — paint compact AFE into top Magic cell (batch)
# Topology: S/H + binary CDAC plates + inverter-chain comparator
# Devices are schematic-faithful placeholders on sky130 layers (not LVS-perfect FETs).

set TOP tt_um_davidbroughsmyth_ecg_sar12
load $TOP

# --- Sample/hold: TG proxy (n diffusion + poly gate) + MOM hold ---
# Hold cap: met2/met3 parallel plate near ua[0] (bottom-right area)
box 120um 20um 145um 35um
paint met2
box 122um 22um 143um 33um
paint met3
label vhold FreeSans 0.5 -met3
port make
port class bidirectional
port use signal

# Sample switch poly gate
box 115um 25um 119um 30um
paint poly
label sample FreeSans 0.4 -poly
port make
port class input
port use signal

# Diffusion island for switch (li1 contact region)
box 116um 26um 118um 29um
paint ndiff
box 116um 26um 118um 29um
paint li1

# --- CDAC: binary-weighted met1/met2 plates (codes b0..b11) ---
# Unit finger ~1.5um x 3um; place array starting x=20
set x0 20.0
set y0 40.0
set uh 3.0
set uw 1.5
set gap 0.5
set x $x0
for {set i 0} {$i < 12} {incr i} {
    set n [expr {1 << $i}]
    # Cap height scales with bit weight but clamp for area
    set fingers [expr {$n > 16 ? 16 : $n}]
    set h [expr {$fingers * ($uh + $gap)}]
    if {$h > 80} { set h 80 }
    box ${x}um ${y0}um [expr {$x+$uw}]um [expr {$y0+$h}]um
    paint met1
    box [expr {$x+0.2}]um [expr {$y0+0.2}]um [expr {$x+$uw-0.2}]um [expr {$y0+$h-0.2}]um
    paint met2
    label b$i FreeSans 0.3 -met1
    port make
    port class input
    port use signal
    set x [expr {$x + $uw + 1.0}]
}

# DAC top plate / output node
box 20um 125um 55um 130um
paint met3
label vdac FreeSans 0.5 -met3
port make
port class bidirectional
port use signal

# vref rail stub
box 20um 135um 55um 138um
paint met4
label vref_afe FreeSans 0.4 -met4

# --- Comparator: stacked inverter-ish poly/diff stages ---
set cx 70.0
set cy 50.0
for {set s 0} {$s < 4} {incr s} {
    set xx [expr {$cx + $s * 8}]
    # nfet region
    box ${xx}um ${cy}um [expr {$xx+3}]um [expr {$cy+4}]um
    paint ndiff
    box ${xx}um [expr {$cy+5}]um [expr {$xx+3}]um [expr {$cy+9}]um
    paint pdiff
    box [expr {$xx+0.5}]um ${cy}um [expr {$xx+2.5}]um [expr {$cy+9}]um
    paint poly
    box ${xx}um [expr {$cy+3.5}]um [expr {$xx+3}]um [expr {$cy+5.5}]um
    paint li1
}
# cmp_out pad near digital region
box 100um 55um 108um 60um
paint met1
label cmp_out FreeSans 0.5 -met1
port make
port class output
port use signal

# Tie unused ua[2..7] locally to VGND metal (avoid floating analog stubs in tile)
for {set u 2} {$u < 8} {incr u} {
    # small met4 jumper near bottom — actual pin already from DEF
}

# Digital region placeholder outline (LibreLane macro lands here)
box 70um 100um 155um 210um
paint met1
# hollow by overwriting? keep as keepout label only — erase fill
erase met1

box 70um 100um 155um 210um
label sar_digital_area FreeSans 1.0 -met4

save $TOP
file mkdir ../gds
file mkdir ../lef
gds write ../gds/${TOP}.gds
lef write ../lef/${TOP}.lef -hide -pinonly
puts "AFE layout painted; GDS/LEF updated"
quit -noprompt
