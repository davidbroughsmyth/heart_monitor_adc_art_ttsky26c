# afe_dac_folded.tcl — 12-bit R-2R DAC folded into TWO device rows, so the cell
# is ~170 x ~80 um (fits a tile column) instead of the 338um-wide single row.
# Net-for-net vs analog/sky130/cdac_12b.spice.
#
#   Row A (bits 0..5)  at cy=0    : private tracks in a band around y=0
#   Row B (bits 6..11) at cy=44   : private tracks in a band around y=44
# Each half is self-contained with its own rails (gndA/vddA/vrefA, gndB/...);
# the 4 cross-row nets (gnd, vdd, vref, and the ladder link n5) are merged with
# vertical met3 jogs at the right edge. Polarity within a half alternates
# relative to that half's cy so every resistor bridges one up-track/one
# down-track (routable with the simple rtop/rbot scheme).
source afe_lib.tcl
set CELL afe_dac_folded
load $CELL

# ---- track-y assignment (two banded groups) ----
proc assign {nets y0 dir} { global TR; set y $y0; foreach n $nets { set TR($n) $y; set y [expr {$y+$dir}] } }
set YB 44.0

set POS_A {b0 b1 b2 b3 b4 b5 b0b b1b b2b b3b b4b b5b n0 n2 n4 snk1 snk3 snk5}
set NEG_A {gndA vddA vrefA n1 n3 n5 snk0 snk2 snk4}
set POS_B {b6 b7 b8 b9 b10 b11 b6b b7b b8b b9b b10b b11b n6 n8 n10 snk7 snk9 snk11}
set NEG_B {gndB vddB vrefB n7 n9 dac_out n5b snk6 snk8 snk10}
assign $POS_A  3.0  1.0
assign $NEG_A -3.0 -1.0
assign $POS_B [expr {$YB+3.0}]  1.0
assign $NEG_B [expr {$YB-3.0}] -1.0

proc T {n} { global TR; return $TR($n) }
proc reg {n x} { global VMN VMX
  if {![info exists VMN($n)] || $x < $VMN($n)} { set VMN($n) $x }
  if {![info exists VMX($n)] || $x > $VMX($n)} { set VMX($n) $x }
}
proc wS {D n} { reg $n [dict get $D srx];  afe::rsrc  $D [T $n] }
proc wD {D n} { reg $n [dict get $D drx];  afe::rdrn  $D [T $n] }
proc wG {D n} { reg $n [dict get $D cx];   afe::rgat  $D [T $n] }
proc wB {D n} { reg $n [dict get $D tapx]; afe::rbulk $D [T $n] }
proc wFET {D ns nd ng nb} { wS $D $ns; wD $D $nd; wG $D $ng; wB $D $nb }
# resistor: na/nb one up-track one down-track RELATIVE to the resistor's cy;
# guard tied to the half's gnd net.
proc wRES {R na nb gnet} {
  set cy [dict get $R cy]
  foreach n [list $na $nb] {
    set yy [T $n]; reg $n [dict get $R cx]
    if {$yy > $cy} { afe::rtop $R $yy } else { afe::rbot $R $yy }
  }
  reg $gnet [dict get $R gx]; afe::rguard $R [T $gnet]
}

set X 3.5
proc nx {} { global X; set r $X; set X [expr {$X+3.5}]; return $r }

# ===== Row A: bits 0..5 (cy=0) =====
for {set i 0} {$i<6} {incr i} {
  wFET [afe::fet nfet 0.42 0.15 [nx] 0.0] gndA  b${i}b b$i    gndA
  wFET [afe::fet pfet 0.84 0.15 [nx] 0.0] vddA  b${i}b b$i    vddA
  wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] vrefA snk$i b$i     gndA
  wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vrefA snk$i b${i}b  vddA
  wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] gndA  snk$i b${i}b  gndA
  wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] gndA  snk$i b$i     vddA
  wRES [afe::res 3.5 [nx] 0.0] snk$i n$i gndA
  if {$i <= 4} { wRES [afe::res 1.75 [nx] 0.0] n$i n[expr {$i+1}] gndA }
}
wRES [afe::res 3.5 [nx] 0.0] n0 gndA gndA   ;# terminator n0 -- gnd

# ===== Row B: bits 6..11 (cy=YB) =====
set X 3.5
for {set i 6} {$i<12} {incr i} {
  wFET [afe::fet nfet 0.42 0.15 [nx] $YB] gndB  b${i}b b$i    gndB
  wFET [afe::fet pfet 0.84 0.15 [nx] $YB] vddB  b${i}b b$i    vddB
  wFET [afe::fet nfet 1.00 0.15 [nx] $YB] vrefB snk$i b$i     gndB
  wFET [afe::fet pfet 2.00 0.15 [nx] $YB] vrefB snk$i b${i}b  vddB
  wFET [afe::fet nfet 1.00 0.15 [nx] $YB] gndB  snk$i b${i}b  gndB
  wFET [afe::fet pfet 2.00 0.15 [nx] $YB] gndB  snk$i b$i     vddB
  set nodei [expr {$i<11 ? "n$i" : "dac_out"}]
  wRES [afe::res 3.5 [nx] $YB] snk$i $nodei gndB
}
# series arms for row B: R5(n5b-n6) R6..R9 R10(n10-dac_out)
wRES [afe::res 1.75 [nx] $YB] n5b n6      gndB
wRES [afe::res 1.75 [nx] $YB] n6  n7      gndB
wRES [afe::res 1.75 [nx] $YB] n7  n8      gndB
wRES [afe::res 1.75 [nx] $YB] n8  n9      gndB
wRES [afe::res 1.75 [nx] $YB] n9  n10     gndB
wRES [afe::res 1.75 [nx] $YB] n10 dac_out gndB

# ---- cross-row met3 jogs (merge the halves) ----
set JOGS {{gndA gndB 176.0} {vddA vddB 179.0} {vrefA vrefB 182.0} {n5 n5b 185.0}}
foreach j $JOGS { reg [lindex $j 0] [lindex $j 2]; reg [lindex $j 1] [lindex $j 2] }

# ---- draw one met2 track per net spanning its vias ----
foreach n [array names TR] {
  if {[info exists VMN($n)]} { afe::m2h [T $n] [expr {$VMN($n)-0.2}] [expr {$VMX($n)+0.2}] }
}
# ---- draw the jogs: via2 onto met3 at both tracks + met3 vertical ----
foreach j $JOGS {
  set na [lindex $j 0]; set nb [lindex $j 1]; set x [lindex $j 2]
  afe::via2 $x [T $na]; afe::via2 $x [T $nb]
  set lo [expr {min([T $na],[T $nb])}]; set hi [expr {max([T $na],[T $nb])}]
  afe::pbox met3 [expr {$x-0.15}] $lo [expr {$x+0.15}] $hi
}

# ---- ports ----
afe::mkport met2 $VMN(vrefA)   [T vrefA]   vref
afe::mkport met2 $VMN(gndA)    [T gndA]    gnd
afe::mkport met2 $VMN(vddA)    [T vddA]    vdd
afe::mkport met2 $VMX(dac_out) [T dac_out] dac_out
for {set i 0} {$i<12} {incr i} { afe::mkport met2 $VMN(b$i) [T b$i] b$i }

save $CELL
puts "AFE_DAC_FOLDED_BBOX [box values]"
quit -noprompt
