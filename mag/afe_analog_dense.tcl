# afe_analog_folded.tcl — connected AFE (S/H + comparator + 12-bit R-2R DAC)
# folded into TWO device rows so the cell is ~230 x ~80um (fits a 2-tile-wide
# column) instead of the ~400um single-row afe_analog. Net-for-net vs
# analog/sky130/sar_afe.spice.
#
#   Row A (cy=0)  : Sample/Hold + comparator + DAC bits 0..5, private +/- bands
#   Row B (cy=44) : DAC bits 6..11, private +/- bands around cy=44
# Shared rails (gnd/vdd/vref), the ladder link (n5<->n5b) and the DAC output
# feedback (dac_out->vdac comparator input) are merged with vertical met3 jogs
# at the right edge. Polarity within each half alternates relative to that
# half's cy so every ladder resistor bridges one up-track / one down-track.
source afe_lib.tcl
set CELL afe_analog_dense
load $CELL

proc assign {nets y0 dir} { global TR; set y $y0; foreach n $nets { set TR($n) $y; set y [expr {$y+$dir}] } }
# DENSE: tighten the met2 track pitch (PP) and pull the two device rows together
# so the whole cell is short enough to stack under the digital macro in a 2x2.
# The FIRST track stays at +/-3.0um (clears the tallest device/resistor); only
# the incremental spacing tightens. Topology/netlist identical to afe_analog_folded.
set PP 0.5
set YB 24.0

# ---- Row A bands (cy=0): S/H + comparator nets, then DAC-A nets ----
set POSA {sample sample_b vhold nbias d1 d2 mid vdac \
          b0 b1 b2 b3 b4 b5 b0b b1b b2b b3b b4b b5b n0 n2 n4 snk1 snk3 snk5}
set NEGA {gnd vdd vref vin tail cmp_out n1 n3 n5 snk0 snk2 snk4}
# ---- Row B bands (cy=44): DAC-B nets ----
set POSB {b6 b7 b8 b9 b10 b11 b6b b7b b8b b9b b10b b11b n6 n8 n10 snk7 snk9 snk11}
set NEGB {gndB vddB vrefB n7 n9 dac_out n5b snk6 snk8 snk10}
assign $POSA  3.0  $PP
assign $NEGA -3.0 [expr {-$PP}]
assign $POSB [expr {$YB+3.0}]  $PP
assign $NEGB [expr {$YB-3.0}] [expr {-$PP}]

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
# resistor na/nb: one up-track one down-track relative to the resistor's cy.
proc wRES {R na nb gnet} {
  set cy [dict get $R cy]
  foreach n [list $na $nb] {
    set yy [T $n]; reg $n [dict get $R cx]
    if {$yy > $cy} { afe::rtop $R $yy } else { afe::rbot $R $yy }
  }
  reg $gnet [dict get $R gx]; afe::rguard $R [T $gnet]
}
proc nx {} { global X; set r $X; set X [expr {$X+3.5}]; return $r }

# ===== Row A: Sample/Hold =====
set X 3.5
wFET [afe::fet nfet 0.42 0.15 [nx] 0.0] gnd sample_b sample   gnd
wFET [afe::fet pfet 0.84 0.15 [nx] 0.0] vdd sample_b sample   vdd
wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] vin vhold   sample    gnd
wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vin vhold   sample_b  vdd
# hold cap (2x2 MIM): top plate met4 -> vhold, bottom plate met3 -> gnd
afe::cap 2 2 20.0 0.0
afe::via2 20.5 0.0; afe::via 20.5 0.0; afe::m1v 20.5 0.0 [T gnd];   afe::via 20.5 [T gnd]
reg gnd 20.5
afe::m4h 0.0 17.4 18.5
afe::via3 17.5 0.0; afe::via2 17.5 0.0; afe::via 17.5 0.0; afe::m1v 17.5 0.0 [T vhold]; afe::via 17.5 [T vhold]
reg vhold 17.5

# ===== Row A: Comparator =====
set X 26.0
wFET [afe::fet pfet 0.84 1.0  [nx] 0.0] vdd  nbias   nbias  vdd
wFET [afe::fet nfet 0.84 1.0  [nx] 0.0] gnd  nbias   nbias  gnd
wFET [afe::fet nfet 3.00 0.15 [nx] 0.0] gnd  tail    nbias  gnd
wFET [afe::fet nfet 2.00 0.15 [nx] 0.0] tail d1      vhold  gnd
wFET [afe::fet nfet 2.00 0.15 [nx] 0.0] tail d2      vdac   gnd
set Dp1 [afe::fet pfet 3.00 0.15 [nx] 0.0]
wS $Dp1 vdd; wD $Dp1 d1; afe::rgat_to_drn $Dp1; wB $Dp1 vdd
wFET [afe::fet pfet 3.00 0.15 [nx] 0.0] vdd  d2      d1     vdd
wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] gnd  mid     d2     gnd
wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vdd  mid     d2     vdd
wFET [afe::fet nfet 0.84 0.15 [nx] 0.0] gnd  cmp_out mid    gnd
wFET [afe::fet pfet 1.68 0.15 [nx] 0.0] vdd  cmp_out mid    vdd

# ===== Row A: DAC bits 0..5 (cy=0) =====
set X 68.0
for {set i 0} {$i<6} {incr i} {
  wFET [afe::fet nfet 0.42 0.15 [nx] 0.0] gnd  b${i}b b$i    gnd
  wFET [afe::fet pfet 0.84 0.15 [nx] 0.0] vdd  b${i}b b$i    vdd
  wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] vref snk$i b$i     gnd
  wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vref snk$i b${i}b  vdd
  wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] gnd  snk$i b${i}b  gnd
  wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] gnd  snk$i b$i     vdd
  wRES [afe::res 3.5 [nx] 0.0] snk$i n$i gnd
  if {$i <= 4} { wRES [afe::res 1.75 [nx] 0.0] n$i n[expr {$i+1}] gnd }
}
wRES [afe::res 3.5 [nx] 0.0] n0 gnd gnd   ;# terminator n0 -- gnd

# ===== Row B: DAC bits 6..11 (cy=YB) =====
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

# ---- cross-row met3 jogs (merge halves + ladder link + DAC feedback) ----
set JOGS {{gnd gndB 240.0} {vdd vddB 243.0} {vref vrefB 246.0} \
          {n5 n5b 249.0} {dac_out vdac 252.0}}
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

# ---- ports (match sar_afe.spice top pins) ----
afe::mkport met2 $VMN(vin)     [T vin]     vin_ecg
afe::mkport met2 $VMN(vref)    [T vref]    vref
afe::mkport met2 $VMN(gnd)     [T gnd]     gnd
afe::mkport met2 $VMN(vdd)     [T vdd]     vdd
afe::mkport met2 $VMN(sample)  [T sample]  sample
afe::mkport met2 $VMX(cmp_out) [T cmp_out] cmp_out
for {set i 0} {$i<12} {incr i} { afe::mkport met2 $VMN(b$i) [T b$i] b$i }

save $CELL
puts "AFE_ANALOG_FOLDED_BBOX [box values]"
# ---- dump port/track coords for the top-level router ----
foreach n [list vin vref gnd vdd sample cmp_out b0 b1 b2 b3 b4 b5 b6 b7 b8 b9 b10 b11] {
  puts "AFEPORT $n T=[T $n] VMN=$VMN($n) VMX=$VMX($n)"
}
quit -noprompt
