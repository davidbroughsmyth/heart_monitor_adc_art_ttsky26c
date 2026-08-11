# afe_analog_dense.tcl — S/H (~1 pF) + AZ comparator + 12-bit R-2R DAC
# Folded for 2×2 DIEAREA:
#   Row A (cy=0)  = S/H + cmp + DAC 0..3 + CM + AZ FETs
#   Row B (cy=YB) = DAC 4..11 + AZ MiMs under NE ART pocket (east of DAC-B)
#
# Layout rules (AZ LVS):
#   - APPEND new track names at end of POSA/NEGA (never insert mid-list).
#   - Place large MiMs FIRST, clear of later FET/res select windows.
#   - Every wRES needs one POS + one NEG end; use POS gnd_tap + met3 strap.
#   - Keep CM/AZ X clear of DAC select windows; never tall-m1v rail straps.
#   - Never put AZ FETs on Row B under Row-A X columns (m1v punches → shorts).
#
source afe_lib.tcl
set CELL afe_analog_dense
catch {cellname delete $CELL}
load $CELL

proc assign {nets y0 dir} { global TR; set y $y0; foreach n $nets { set TR($n) $y; set y [expr {$y+$dir}] } }
set PP 0.5
set YB 26.0

set POSA {sample sample_b vhold nbias d1 d2 mid vdac \
          b0 b1 b2 b3 b0b b1b b2b b3b n0 n2 snk1 snk3 \
          vcm_h gnd_tap vp az1}
set NEGA {gnd vdd vref vin tail cmp_out n1 n3 snk0 snk2 \
          vcm_d vm az2}
set POSB {b4 b5 b6 b7 b8 b9 b10 b11 b4b b5b b6b b7b b8b b9b b10b b11b \
          n4 n6 n8 n10 snk5 snk7 snk9 snk11}
set NEGB {gndB vddB vrefB n3b n5 n7 n9 dac_out snk4 snk6 snk8 snk10}
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
proc wRES {R na nb gnet} {
  set cy [dict get $R cy]
  foreach n [list $na $nb] {
    set yy [T $n]; reg $n [dict get $R cx]
    if {$yy > $cy} { afe::rtop $R $yy } else { afe::rbot $R $yy }
  }
  reg $gnet [dict get $R gx]; afe::rguard $R [T $gnet]
}
proc nx {} { global X; set r $X; set X [expr {$X+3.5}]; return $r }
proc nxaz {} { global X; set r $X; set X [expr {$X+2.5}]; return $r }
proc nxgap {} { global X; set X [expr {$X+1.2}]; set r $X; set X [expr {$X+3.5}]; return $r }

# ===== MiMs FIRST =====
afe::cap 22 22 40.0 0.0
afe::via2 54.0 0.0
afe::pbox met3 51.0 -0.26 54.26 0.26
afe::via  54.0 0.0; afe::m1v 54.0 0.0 [T gnd]; afe::via 54.0 [T gnd]
reg gnd 54.0
afe::m4h 0.0 25.0 29.0
afe::via3 25.5 0.0; afe::via2 25.5 0.0; afe::via 25.5 0.0
afe::m1v 25.5 0.0 [T vhold]; afe::via 25.5 [T vhold]
reg vhold 25.5

# AZ MiMs on Row B under ART pocket (local X~200–295 @AOX=10).
# East of Row-B DAC (~227); Capm.SP.3 ≥2µm. Keeps Row-A free of far-east plates.
# C1 12×12 @248 → 242..254; C2 8×8 @260 → 256..264; via≈264.
afe::cap 12 12 248.0 $YB
afe::via2 258.0 $YB
afe::pbox met3 254.0 [expr {$YB-0.26}] 258.26 [expr {$YB+0.26}]
afe::via 258.0 $YB; afe::m1v 258.0 $YB [T az1]; afe::via 258.0 [T az1]
reg az1 258.0
afe::m4h $YB 236.0 241.0
afe::via3 237.0 $YB; afe::via2 237.0 $YB; afe::via 237.0 $YB
afe::m1v 237.0 $YB [T vp]; afe::via 237.0 [T vp]
reg vp 237.0

afe::cap 8 8 260.0 $YB
afe::via2 264.0 $YB
afe::pbox met3 262.0 [expr {$YB-0.26}] 264.26 [expr {$YB+0.26}]
afe::via 264.0 $YB; afe::m1v 264.0 $YB [T az2]; afe::via 264.0 [T az2]
reg az2 264.0
afe::m4h $YB 250.0 255.0
afe::via3 250.5 $YB; afe::via2 250.5 $YB; afe::via 250.5 $YB
afe::m1v 250.5 $YB [T vm]; afe::via 250.5 [T vm]
reg vm 250.5

# ===== Row A: Sample/Hold =====
set X 3.5
wFET [afe::fet nfet 0.42 0.15 [nx] 0.0] gnd sample_b sample   gnd
wFET [afe::fet pfet 0.84 0.15 [nx] 0.0] vdd sample_b sample   vdd
wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] vin vhold   sample    gnd
wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vin vhold   sample_b  vdd

# ===== Comparator: 6.5µm + Dp1 gaps (met1.2) =====
set X 62.0
proc nxcmp {} { global X; set r $X; set X [expr {$X+6.5}]; return $r }
wFET [afe::fet pfet 1.00 1.0  [nxcmp] 0.0] vdd  nbias   nbias  vdd
wFET [afe::fet nfet 1.00 1.0  [nxcmp] 0.0] gnd  nbias   nbias  gnd
wFET [afe::fet nfet 3.00 0.15 [nxcmp] 0.0] gnd  tail    nbias  gnd
set X [expr {$X + 2.5}]
wFET [afe::fet nfet 2.00 0.15 [nxcmp] 0.0] tail d1      vp     gnd
set X [expr {$X + 2.5}]
wFET [afe::fet nfet 2.00 0.15 [nxcmp] 0.0] tail d2      vm     gnd
set X [expr {$X + 4.0}]
set Dp1 [afe::fet pfet 3.00 0.15 [nxcmp] 0.0]
wS $Dp1 vdd; wD $Dp1 d1; afe::rgat_to_drn $Dp1; wB $Dp1 vdd
set X [expr {$X + 4.0}]
wFET [afe::fet pfet 3.00 0.15 [nxcmp] 0.0] vdd  d2      d1     vdd
wFET [afe::fet nfet 1.00 0.15 [nxcmp] 0.0] gnd  mid     d2     gnd
wFET [afe::fet pfet 2.00 0.15 [nxcmp] 0.0] vdd  mid     d2     vdd
wFET [afe::fet nfet 0.84 0.15 [nxcmp] 0.0] gnd  cmp_out mid    gnd
wFET [afe::fet pfet 1.68 0.15 [nxcmp] 0.0] vdd  cmp_out mid    vdd

# ===== DAC bits 0..3 (c97-style nx pitch — nxgap grew FEOL licon storm) =====
set X 150.0
for {set i 0} {$i<4} {incr i} {
  wFET [afe::fet nfet 0.42 0.15 [nx] 0.0] gnd  b${i}b b$i    gnd
  wFET [afe::fet pfet 0.84 0.15 [nx] 0.0] vdd  b${i}b b$i    vdd
  wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] vref snk$i b$i     gnd
  wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vref snk$i b${i}b  vdd
  wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] gnd  snk$i b${i}b  gnd
  wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] gnd  snk$i b$i     vdd
  wRES [afe::res 3.5 [nx] 0.0] snk$i n$i gnd
  if {$i <= 2} { wRES [afe::res 1.75 [nx] 0.0] n$i n[expr {$i+1}] gnd }
}
wRES [afe::res 3.5 [nx] 0.0] n0 gnd gnd

# ===== CM + AZ — c97 lengths (3.5 / 0.90 / 0.90); clear of DAC-A end~262 =====
# L=3.5 mid caused FEOL+40 (licon CON/SP @~267). Keep short mid/bot like c97.
set X 266.0
wRES [afe::res 3.5 $X 0.0] vdd    vcm_h   gnd
set X 271.0
wRES [afe::res 0.90 $X 0.0] vcm_h  vcm_d   gnd
set X 276.0
wRES [afe::res 0.90 $X 0.0] vcm_d  gnd_tap gnd
set Xstrap 279.0
afe::via2 $Xstrap [T gnd_tap]
afe::via2 $Xstrap [T gnd]
set lo [expr {min([T gnd_tap],[T gnd])}]; set hi [expr {max([T gnd_tap],[T gnd])}]
afe::pbox met3 [expr {$Xstrap-0.15}] $lo [expr {$Xstrap+0.15}] $hi
reg gnd $Xstrap; reg gnd_tap $Xstrap

# AZ pitch 2.5 → last cx≈300; plates now on Row B under ART (no Row-A plates).
set X 278.0
wFET [afe::fet nfet 0.36 0.15 [nxaz] 0.0] az1 vcm_h sample   gnd
wFET [afe::fet pfet 0.72 0.15 [nxaz] 0.0] az1 vcm_h sample_b vdd
wFET [afe::fet nfet 0.36 0.15 [nxaz] 0.0] az2 vcm_d sample   gnd
wFET [afe::fet pfet 0.72 0.15 [nxaz] 0.0] az2 vcm_d sample_b vdd
wFET [afe::fet nfet 0.36 0.15 [nxaz] 0.0] vp  vm    sample   gnd
wFET [afe::fet pfet 0.72 0.15 [nxaz] 0.0] vp  vm    sample_b vdd
wFET [afe::fet nfet 0.36 0.15 [nxaz] 0.0] az1 vhold sample_b gnd
wFET [afe::fet pfet 0.72 0.15 [nxaz] 0.0] az1 vhold sample   vdd
wFET [afe::fet nfet 0.36 0.15 [nxaz] 0.0] az2 vdac  sample_b gnd
wFET [afe::fet pfet 0.72 0.15 [nxaz] 0.0] az2 vdac  sample   vdd

# ===== Row B DAC 4..11 =====
set X 3.5
for {set i 4} {$i<12} {incr i} {
  wFET [afe::fet nfet 0.42 0.15 [nx] $YB] gndB  b${i}b b$i    gndB
  wFET [afe::fet pfet 0.84 0.15 [nx] $YB] vddB  b${i}b b$i    vddB
  wFET [afe::fet nfet 1.00 0.15 [nx] $YB] vrefB snk$i b$i     gndB
  wFET [afe::fet pfet 2.00 0.15 [nx] $YB] vrefB snk$i b${i}b  vddB
  wFET [afe::fet nfet 1.00 0.15 [nx] $YB] gndB  snk$i b${i}b  gndB
  wFET [afe::fet pfet 2.00 0.15 [nx] $YB] gndB  snk$i b$i     vddB
  set nodei [expr {$i<11 ? "n$i" : "dac_out"}]
  wRES [afe::res 3.5 [nx] $YB] snk$i $nodei gndB
}
wRES [afe::res 1.75 [nx] $YB] n3b n4      gndB
wRES [afe::res 1.75 [nx] $YB] n4  n5      gndB
wRES [afe::res 1.75 [nx] $YB] n5  n6      gndB
wRES [afe::res 1.75 [nx] $YB] n6  n7      gndB
wRES [afe::res 1.75 [nx] $YB] n7  n8      gndB
wRES [afe::res 1.75 [nx] $YB] n8  n9      gndB
wRES [afe::res 1.75 [nx] $YB] n9  n10     gndB
wRES [afe::res 1.75 [nx] $YB] n10 dac_out gndB

# Power jogs WEST (clear of Chold); ladder jogs east of AZ (~ends 300).
set JOGS {{gnd gndB 18.0} {vdd vddB 20.5} {vref vrefB 23.0} \
          {n3 n3b 302.0} {dac_out vdac 304.0}}
foreach j $JOGS { reg [lindex $j 0] [lindex $j 2]; reg [lindex $j 1] [lindex $j 2] }

foreach n [array names TR] {
  if {[info exists VMN($n)]} { afe::m2h [T $n] [expr {$VMN($n)-0.2}] [expr {$VMX($n)+0.2}] }
}
foreach j $JOGS {
  set na [lindex $j 0]; set nb [lindex $j 1]; set x [lindex $j 2]
  afe::via2 $x [T $na]; afe::via2 $x [T $nb]
  set lo [expr {min([T $na],[T $nb])}]; set hi [expr {max([T $na],[T $nb])}]
  afe::pbox met3 [expr {$x-0.15}] $lo [expr {$x+0.15}] $hi
}

# Hierarchy ports on met2 west of first via/jogs so parent met2 taps attach
# (port make otherwise lands on via1/via2 buried under the track via).
foreach n [array names TR] {
  if {[info exists VMN($n)]} {
    set VMN($n) [expr {$VMN($n) - 0.55}]
    afe::m2h [T $n] [expr {$VMN($n)-0.2}] [expr {$VMX($n)+0.2}]
  }
}
# cmp_out: port near VMX east (sig taps VMX); nudge off any via at VMX
set VMX(cmp_out) [expr {$VMX(cmp_out) + 0.55}]
afe::m2h [T cmp_out] [expr {$VMN(cmp_out)-0.2}] [expr {$VMX(cmp_out)+0.2}]

afe::mkport met2 $VMN(vin)     [T vin]     vin_ecg
afe::mkport met2 $VMN(vref)    [T vref]    vref
afe::mkport met2 $VMN(gnd)     [T gnd]     gnd
afe::mkport met2 $VMN(vdd)     [T vdd]     vdd
afe::mkport met2 $VMN(sample)  [T sample]  sample
afe::mkport met2 $VMX(cmp_out) [T cmp_out] cmp_out
for {set i 0} {$i<12} {incr i} { afe::mkport met2 $VMN(b$i) [T b$i] b$i }

select top cell
# Never leave FIXED_BBOX on this full layout cell — getcell would align the
# abstract bbox instead of the origin and parent taps would miss every port.
catch {property FIXED_BBOX {}}
puts "AFE_ANALOG_DENSE_BBOX [box values]"
foreach n [list vin vref gnd vdd sample cmp_out b0 b1 b2 b3 b4 b5 b6 b7 b8 b9 b10 b11] {
  puts "AFEPORT $n T=[T $n] VMN=$VMN($n) VMX=$VMX($n)"
}
save $CELL
# Guard: refuse a FIXED_BBOX on disk (breaks top routing by ~0.74×3.52µm).
set _fp [open ${CELL}.mag r]; set _m [read $_fp]; close $_fp
if {[string match "*FIXED_BBOX*" $_m]} {
  puts "ERROR: FIXED_BBOX still present after save — strip before top assembly"
}
quit -noprompt
