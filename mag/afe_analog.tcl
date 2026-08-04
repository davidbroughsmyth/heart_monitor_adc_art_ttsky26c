# afe_analog.tcl — connected AFE (S/H + comparator + 12-bit R-2R DAC) as ONE
# flat cell, net-for-net vs analog/sky130/sar_afe.spice.
#   top ports: vin_ecg vref gnd vdd sample b0..b11 cmp_out
# Reuses the proven channel-route helpers with a single merged track map.
# dac_out (a -track, per the DAC's alternating-node scheme) is bridged to the
# comparator's vdac (+gate track) with one met3 jog. Oversized by design (the
# one-track-per-net scheme trades area for guaranteed short-freedom).
source afe_lib.tcl
set CELL afe_analog
load $CELL

# ---- merged net -> track-y assignment ----
set POS {sample sample_b vhold vdac nbias d1 d2 mid}
for {set i 0} {$i<12} {incr i} { lappend POS b$i }
for {set i 0} {$i<12} {incr i} { lappend POS b${i}b }
foreach i {0 2 4 6 8 10} { lappend POS n$i }
foreach i {1 3 5 7 9 11} { lappend POS snk$i }
set NEG {gnd vdd vin vref tail cmp_out}
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
proc wS {D n} { reg $n [dict get $D srx];  afe::rsrc  $D [T $n] }
proc wD {D n} { reg $n [dict get $D drx];  afe::rdrn  $D [T $n] }
proc wG {D n} { reg $n [dict get $D cx];   afe::rgat  $D [T $n] }
proc wB {D n} { reg $n [dict get $D tapx]; afe::rbulk $D [T $n] }
proc wFET {D ns nd ng nb} { wS $D $ns; wD $D $nd; wG $D $ng; wB $D $nb }
proc wRES {R na nb} {
  foreach n [list $na $nb] {
    set yy [T $n]; reg $n [dict get $R cx]
    if {$yy > 0} { afe::rtop $R $yy } else { afe::rbot $R $yy }
  }
  reg gnd [dict get $R gx]; afe::rguard $R [T gnd]
}

set X 3.5
proc nx {} { global X; set r $X; set X [expr {$X+3.5}]; return $r }

# ===== Sample/Hold =====
wFET [afe::fet nfet 0.42 0.15 [nx] 0.0] gnd sample_b sample   gnd
wFET [afe::fet pfet 0.84 0.15 [nx] 0.0] vdd sample_b sample   vdd
wFET [afe::fet nfet 1.00 0.15 [nx] 0.0] vin vhold   sample    gnd
wFET [afe::fet pfet 2.00 0.15 [nx] 0.0] vin vhold   sample_b  vdd
# hold cap (2x2 MIM): top plate met4 -> vhold, bottom plate met3 -> gnd
set X 20.0
afe::cap 2 2 20.0 0.0
afe::via2 20.5 0.0; afe::via 20.5 0.0; afe::m1v 20.5 0.0 [T gnd];   afe::via 20.5 [T gnd]
reg gnd 20.5
afe::m4h 0.0 17.4 18.5
afe::via3 17.5 0.0; afe::via2 17.5 0.0; afe::via 17.5 0.0; afe::m1v 17.5 0.0 [T vhold]; afe::via 17.5 [T vhold]
reg vhold 17.5

# ===== Comparator =====
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

# ===== 12-bit R-2R DAC =====
set X 66.0
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

# ---- dac_out(-track) <-> vdac(+gate track) met3 jog at a clear x ----
set XJ 63.0
reg vdac $XJ ; reg dac_out $XJ

# ---- draw one met2 track per net spanning its vias ----
foreach n [array names TR] {
  if {[info exists VMN($n)]} {
    afe::m2h [T $n] [expr {$VMN($n)-0.2}] [expr {$VMX($n)+0.2}]
  }
}
# the jog: via2 up onto met3 at both tracks, met3 vertical between them
afe::via2 $XJ [T vdac]
afe::via2 $XJ [T dac_out]
afe::pbox met3 [expr {$XJ-0.15}] [T dac_out] [expr {$XJ+0.15}] [T vdac]

# ---- ports (match sar_afe.spice top pins) ----
afe::mkport met2 $VMN(vin)     [T vin]     vin_ecg
afe::mkport met2 $VMN(vref)    [T vref]    vref
afe::mkport met2 $VMN(gnd)     [T gnd]     gnd
afe::mkport met2 $VMN(vdd)     [T vdd]     vdd
afe::mkport met2 $VMN(sample)  [T sample]  sample
afe::mkport met2 $VMX(cmp_out) [T cmp_out] cmp_out
for {set i 0} {$i<12} {incr i} { afe::mkport met2 $VMN(b$i) [T b$i] b$i }

save $CELL
puts "AFE_ANALOG_BBOX [box values]"
quit -noprompt
