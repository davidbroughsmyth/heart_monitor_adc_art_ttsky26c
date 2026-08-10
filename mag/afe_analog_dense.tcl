# afe_analog_dense.tcl — S/H (~1 pF) + AZ comparator + 12-bit R-2R DAC
# Folded into two device rows. Intent: analog/sky130/sar_afe.spice.
#
# Layout rules (AZ LVS):
#   - APPEND new track names at end of POSA/NEGA (never insert mid-list).
#   - Place large MiMs FIRST, clear of later FET/res select windows.
#   - Every wRES needs one POS + one NEG end; use POS gnd_tap + met3 strap
#     (via2 only at endpoints) instead of vcm_d→gnd both-on-NEG.
#   - Keep new devices out of the DAC X span; put CM/AZ FETs east of DAC.
#   - Never strap rails with tall m1v across the track stack.
#
source afe_lib.tcl
set CELL afe_analog_dense
catch {cellname delete $CELL}
load $CELL

proc assign {nets y0 dir} { global TR; set y $y0; foreach n $nets { set TR($n) $y; set y [expr {$y+$dir}] } }
set PP 0.5
set YB 28.0

# HEAD nets first (stable Y); AZ nets APPENDED.
# az1/az2 = AZ-cap bottoms (SPICE comparator n1/n2; renamed vs DAC n1/n2).
set POSA {sample sample_b vhold nbias d1 d2 mid vdac \
          b0 b1 b2 b3 b4 b5 b0b b1b b2b b3b b4b b5b n0 n2 n4 snk1 snk3 snk5 \
          vcm_h gnd_tap vp az1}
set NEGA {gnd vdd vref vin tail cmp_out n1 n3 n5 snk0 snk2 snk4 \
          vcm_d vm az2}
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
proc wRES {R na nb gnet} {
  set cy [dict get $R cy]
  foreach n [list $na $nb] {
    set yy [T $n]; reg $n [dict get $R cx]
    if {$yy > $cy} { afe::rtop $R $yy } else { afe::rbot $R $yy }
  }
  reg $gnet [dict get $R gx]; afe::rguard $R [T $gnet]
}
proc nx {} { global X; set r $X; set X [expr {$X+3.5}]; return $r }

# ===== MiMs FIRST =====
# Chold ~1 pF
afe::cap 22 22 40.0 0.0
afe::via2 54.0 0.0
afe::pbox met3 51.0 -0.26 54.26 0.26
afe::via  54.0 0.0; afe::m1v 54.0 0.0 [T gnd]; afe::via 54.0 [T gnd]
reg gnd 54.0
afe::m4h 0.0 26.0 29.0
afe::via3 27.5 0.0; afe::via2 27.5 0.0; afe::via 27.5 0.0
afe::m1v 27.5 0.0 [T vhold]; afe::via 27.5 [T vhold]
reg vhold 27.5

# AZ caps mid-band: below Row-B NEGB (gndB@25 / vrefB@24) and above POSA (~17.5)
set AZCY 20.5
afe::cap 24 24 175.0 $AZCY
afe::via2 189.0 $AZCY
afe::pbox met3 163.0 [expr {$AZCY-0.26}] 189.26 [expr {$AZCY+0.26}]
afe::via 189.0 $AZCY; afe::m1v 189.0 $AZCY [T az1]; afe::via 189.0 [T az1]
reg az1 189.0
afe::m4h $AZCY 163.0 191.0
afe::via3 161.0 $AZCY; afe::via2 161.0 $AZCY; afe::via 161.0 $AZCY
afe::m1v 161.0 $AZCY [T vp]; afe::via 161.0 [T vp]
reg vp 161.0

afe::cap 10 10 210.0 $AZCY
afe::via2 218.0 $AZCY
afe::pbox met3 205.0 [expr {$AZCY-0.26}] 218.26 [expr {$AZCY+0.26}]
afe::via 218.0 $AZCY; afe::m1v 218.0 $AZCY [T az2]; afe::via 218.0 [T az2]
reg az2 218.0
afe::m4h $AZCY 205.0 220.0
afe::via3 220.5 $AZCY; afe::via2 220.5 $AZCY; afe::via 220.5 $AZCY
afe::m1v 220.5 $AZCY [T vm]; afe::via 220.5 [T vm]
reg vm 220.5

# ===== Row A: Sample/Hold =====
set X 3.5
wFET [afe::fet nfet 0.42 0.15 [nx] 0.0] gnd sample_b sample   gnd
wFET [afe::fet pfet 0.84 0.15 [nx] 0.0] vdd sample_b sample   vdd
wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] vin vhold   sample    gnd
wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vin vhold   sample_b  vdd

# ===== Asym CM divider EAST of DAC-A (~ends x≈264.5) =====
set X 266.0
wRES [afe::res 3.5 $X 0.0] vdd    vcm_h   gnd
set X 271.0
wRES [afe::res 0.90 $X 0.0] vcm_h  vcm_d   gnd
set X 276.0
wRES [afe::res 0.90 $X 0.0] vcm_d  gnd_tap gnd
set Xstrap 280.0
afe::via2 $Xstrap [T gnd_tap]
afe::via2 $Xstrap [T gnd]
set lo [expr {min([T gnd_tap],[T gnd])}]; set hi [expr {max([T gnd_tap],[T gnd])}]
afe::pbox met3 [expr {$Xstrap-0.15}] $lo [expr {$Xstrap+0.15}] $hi
reg gnd $Xstrap; reg gnd_tap $Xstrap

# ===== Row A: Comparator (gates on AZ tops vp/vm) =====
set X 60.0
wFET [afe::fet pfet 0.84 1.0  [nx] 0.0] vdd  nbias   nbias  vdd
wFET [afe::fet nfet 0.84 1.0  [nx] 0.0] gnd  nbias   nbias  gnd
wFET [afe::fet nfet 3.00 0.15 [nx] 0.0] gnd  tail    nbias  gnd
wFET [afe::fet nfet 2.00 0.15 [nx] 0.0] tail d1      vp     gnd
wFET [afe::fet nfet 2.00 0.15 [nx] 0.0] tail d2      vm     gnd
set Dp1 [afe::fet pfet 3.00 0.15 [nx] 0.0]
wS $Dp1 vdd; wD $Dp1 d1; afe::rgat_to_drn $Dp1; wB $Dp1 vdd
wFET [afe::fet pfet 3.00 0.15 [nx] 0.0] vdd  d2      d1     vdd
wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] gnd  mid     d2     gnd
wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vdd  mid     d2     vdd
wFET [afe::fet nfet 0.84 0.15 [nx] 0.0] gnd  cmp_out mid    gnd
wFET [afe::fet pfet 1.68 0.15 [nx] 0.0] vdd  cmp_out mid    vdd

# ===== Row A: DAC bits 0..5 =====
set X 100.0
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
wRES [afe::res 3.5 [nx] 0.0] n0 gnd gnd

# ===== Row B: DAC bits 6..11 =====
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
wRES [afe::res 1.75 [nx] $YB] n5b n6      gndB
wRES [afe::res 1.75 [nx] $YB] n6  n7      gndB
wRES [afe::res 1.75 [nx] $YB] n7  n8      gndB
wRES [afe::res 1.75 [nx] $YB] n8  n9      gndB
wRES [afe::res 1.75 [nx] $YB] n9  n10     gndB
wRES [afe::res 1.75 [nx] $YB] n10 dac_out gndB

# ===== AZ switches (pitch 3.0 — W=0.72 select still clear) =====
proc nxaz {} { global X; set r $X; set X [expr {$X+3.0}]; return $r }
set X 283.0
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

# ---- cross-row met3 jogs ----
set JOGS {{gnd gndB 300.0} {vdd vddB 302.5} {vref vrefB 305.0} \
          {n5 n5b 307.5} {dac_out vdac 310.0}}
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

afe::mkport met2 $VMN(vin)     [T vin]     vin_ecg
afe::mkport met2 $VMN(vref)    [T vref]    vref
afe::mkport met2 $VMN(gnd)     [T gnd]     gnd
afe::mkport met2 $VMN(vdd)     [T vdd]     vdd
afe::mkport met2 $VMN(sample)  [T sample]  sample
afe::mkport met2 $VMX(cmp_out) [T cmp_out] cmp_out
for {set i 0} {$i<12} {incr i} { afe::mkport met2 $VMN(b$i) [T b$i] b$i }

select top cell
puts "AFE_ANALOG_DENSE_BBOX [box values]"
foreach n [list vin vref gnd vdd sample cmp_out b0 b1 b2 b3 b4 b5 b6 b7 b8 b9 b10 b11] {
  puts "AFEPORT $n T=[T $n] VMN=$VMN($n) VMX=$VMX($n)"
}
save $CELL
quit -noprompt
