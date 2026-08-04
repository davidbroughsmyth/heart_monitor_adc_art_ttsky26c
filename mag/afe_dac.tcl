# afe_dac.tcl — full 12-bit R-2R DAC, net-for-net vs analog/sky130/cdac_12b.spice
#   ports: vref gnd vdd dac_out b0..b11   (b*b, snk*, n* internal)
#   96 devices: 12x(bit_drive + 2 TG) = 72 FETs + 24 xhigh poly resistors.
#
# Single device row (cy=0); one horizontal met2 track per net at a distinct y.
# Net polarity is assigned so every resistor bridges one +track (top pad, routed
# up) and one -track (bottom pad, routed down): ladder nodes alternate
# (n_even +, n_odd -, dac_out -) and snk_i alternates to match.
# Track spans are auto-computed from the actual via x's (no manual spans).
source afe_lib.tcl
set CELL afe_dac
load $CELL

# ---- net -> track-y assignment (positive first, then negative) ----
set POS {}
for {set i 0} {$i<12} {incr i} { lappend POS b$i }
for {set i 0} {$i<12} {incr i} { lappend POS b${i}b }
foreach i {0 2 4 6 8 10} { lappend POS n$i }
foreach i {1 3 5 7 9 11} { lappend POS snk$i }
set NEG {gnd vdd vref}
foreach i {1 3 5 7 9} { lappend NEG n$i }
lappend NEG dac_out
foreach i {0 2 4 6 8 10} { lappend NEG snk$i }

set y 3.0
foreach n $POS { set TR($n) $y; set y [expr {$y+1.0}] }
set y -3.0
foreach n $NEG { set TR($n) $y; set y [expr {$y-1.0}] }

proc T {n} { global TR; return $TR($n) }
proc reg {n x} { global VMN VMX
  if {![info exists VMN($n)] || $x < $VMN($n)} { set VMN($n) $x }
  if {![info exists VMX($n)] || $x > $VMX($n)} { set VMX($n) $x }
}

# routing wrappers: register the via x (for auto-span) then draw the riser.
proc wS {D n} { reg $n [dict get $D srx];  afe::rsrc  $D [T $n] }
proc wD {D n} { reg $n [dict get $D drx];  afe::rdrn  $D [T $n] }
proc wG {D n} { reg $n [dict get $D cx];   afe::rgat  $D [T $n] }
proc wB {D n} { reg $n [dict get $D tapx]; afe::rbulk $D [T $n] }
proc wFET {D ns nd ng nb} { wS $D $ns; wD $D $nd; wG $D $ng; wB $D $nb }

# resistor: na/nb one +track (top, up) one -track (bottom, down); guard -> gnd
proc wRES {R na nb} {
  foreach n [list $na $nb] {
    set yy [T $n]; reg $n [dict get $R cx]
    if {$yy > 0} { afe::rtop $R $yy } else { afe::rbot $R $yy }
  }
  reg gnd [dict get $R gx]; afe::rguard $R [T gnd]
}

# ---- place + route ----
set X 3.5
proc nx {} { global X; set r $X; set X [expr {$X+3.5}]; return $r }

for {set i 0} {$i<12} {incr i} {
  wFET [afe::fet nfet 0.42 0.15 [nx] 0.0] gnd  b${i}b b$i    gnd
  wFET [afe::fet pfet 0.84 0.15 [nx] 0.0] vdd  b${i}b b$i    vdd
  wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] vref snk$i b$i     gnd
  wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vref snk$i b${i}b  vdd
  wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] gnd  snk$i b${i}b  gnd
  wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] gnd  snk$i b$i     vdd
  set nodei [expr {$i<11 ? "n$i" : "dac_out"}]
  wRES [afe::res 3.5 [nx] 0.0] snk$i $nodei
  if {$i <= 10} {
    set nb [expr {$i<10 ? "n[expr {$i+1}]" : "dac_out"}]
    wRES [afe::res 1.75 [nx] 0.0] n$i $nb
  }
}
wRES [afe::res 3.5 [nx] 0.0] n0 gnd

# ---- draw one met2 track per net spanning all its vias ----
foreach n [array names TR] {
  if {[info exists VMN($n)]} {
    afe::m2h [T $n] [expr {$VMN($n)-0.2}] [expr {$VMX($n)+0.2}]
  }
}

# ---- ports ----
afe::mkport met2 $VMN(vref)    [T vref]    vref
afe::mkport met2 $VMN(gnd)     [T gnd]     gnd
afe::mkport met2 $VMN(vdd)     [T vdd]     vdd
afe::mkport met2 $VMX(dac_out) [T dac_out] dac_out
for {set i 0} {$i<12} {incr i} { afe::mkport met2 $VMN(b$i) [T b$i] b$i }

save $CELL
puts "AFE_DAC_BBOX [box values]"
quit -noprompt
