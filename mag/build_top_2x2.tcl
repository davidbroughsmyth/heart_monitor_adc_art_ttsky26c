# build_top_2x2.tcl — assemble the COMPLETE 2x2 analog tile top cell:
#   * import the TT 2x2 analog template (die + boundary pins)
#   * place the hardened sar_digital macro and the dense AFE, stacked so there
#     is a routing channel BELOW the macro (AFE<->macro interface) and ABOVE it
#     (digital I/O to the north boundary pins).
#   * route EVERYTHING:
#       - AFE<->macro: cmp_out, sample, dac_bits[0..11]  (14 nets, low channel)
#       - analog in : vin_ecg->ua[0], vref->ua[1]        (south pins)
#       - AFE power : gnd->VGND stripe, vdd->VDPWR stripe
#       - macro PDN : VPWR/VGND straps -> VDPWR/VGND stripes (top-margin bridges)
#       - digital IO: clk, rst_n, uo_out[0..7], uio_out[0..7], uio_oe[0..7]
#                     macro-north -> tile-north boundary pins (26 nets, top chan)
# Routing convention: pin(metX) -> via -> met3 vertical -> via3 -> met4 horizontal
#   (one distinct y per net) -> via3 -> met3 vertical -> via -> dest. met4
#   horizontals never share a y; met3 verticals are checked for x clashes so the
#   channels are short-free by construction (DRC + full-tile LVS verified).
source afe_lib.tcl
set TOP tt_um_davidbroughsmyth_ecg_sar12

# ---- import 2x2 template (creates die + boundary pins ua/ui/uo/clk...) ----
# Never `load $TOP` before the first save — that would pull the previous
# .mag and discard the DEF template.
def read tt_analog_2x2.def
cellname rename tt_um_template $TOP
save $TOP
load $TOP

# ---- power stripes (left edge), per TT analog spec (met4, >=1.2um, y5..220.76) ----
proc stripe {name x} {
  box ${x}um 5um [expr {$x+2}]um 220.76um
  paint met4
  label $name FreeSans 0.5 -met4
  port make
  port use [expr {$name eq "VGND" ? "ground" : "power"}]
  port class bidirectional
  port connections n s e w
}
stripe VDPWR 1.0
stripe VGND  4.0

# ---- routing helpers ----
proc m3v {x y0 y1} { set lo [expr {min($y0,$y1)}]; set hi [expr {max($y0,$y1)}]
  afe::pbox met3 [expr {$x-0.16}] $lo [expr {$x+0.16}] $hi }
proc m4v {x y0 y1} { set lo [expr {min($y0,$y1)}]; set hi [expr {max($y0,$y1)}]
  afe::pbox met4 [expr {$x-0.15}] $lo [expr {$x+0.15}] $hi }
# via2 landing on an AFE met2 track (PP=0.5µm). Magic cifoutput VIA2 uses
# `squares-grid` and only emits 0.2µm cuts inside the painted via∩metals
# region — a marker painted exactly 0.2×0.2 usually streams ZERO cuts.
# Keep via2/met3 pads large enough for a cut, but keep the PARENT met2 apron
# flush with the 0.16µm track (hy=0.08). A fat met2 apron (hy=0.18) scored
# met2.2 against neighboring AFE via2 met2 pads (a=0.26) on adjacent tracks:
#   gap = 0.5 - 0.18 - 0.26 = 0.06  (< 0.14). Flush apron → gap 0.16.
proc tapvia2 {x y} {
  afe::pbox met2 [expr {$x-0.36}] [expr {$y-0.08}] [expr {$x+0.36}] [expr {$y+0.08}]
  afe::pbox via2 [expr {$x-0.26}] [expr {$y-0.18}] [expr {$x+0.26}] [expr {$y+0.18}]
  afe::pbox met3 [expr {$x-0.26}] [expr {$y-0.26}] [expr {$x+0.26}] [expr {$y+0.26}]
}

# ---- place dense AFE off left PDN; AZ MiMs on Row B under ART.
# Magic getcell aligns the content BBOX LL (not the cell origin) to the cursor
# box. Ports sit at negative Y, so the origin ends up at AOX-cllx, AOY-clly.
# Route using the TRUE origin (aox/aoy), not the cursor AOX/AOY.
load afe_analog_dense
select top cell
set cb [box values]
set cllx [expr {[lindex $cb 0]/200.0}]
set clly [expr {[lindex $cb 1]/200.0}]
puts "AFE_CELL_BBOX_LL $cllx $clly"
load $TOP
set AOX 10.0
set AOY 17.0
box ${AOX}um ${AOY}um [expr {$AOX+1}]um [expr {$AOY+1}]um
getcell afe_analog_dense
select cell afe_analog_dense_0
set abox [box values]
# world_bbox_LL − child_bbox_LL = cell origin in parent
set aox [expr {[lindex $abox 0]/200.0 - $cllx}]
set aoy [expr {[lindex $abox 1]/200.0 - $clly}]
puts "AFE_ORIGIN aox=$aox aoy=$aoy (cursor=$AOX,$AOY bboxLL=[expr {[lindex $abox 0]/200.0}],[expr {[lindex $abox 1]/200.0}])"
select clear
# Checkpoint before GDS import: `load $TOP` after gds read reloads from disk.
save $TOP

# ---- place sar_digital. met4.2 needs pitch ≥0.82 with via3 pads (a=0.26).
#      DY=72 leaves channel for 14×0.82µm AFE↔macro met4; dig stays at 203.7+. ----
set DX 40.0 ; set DY 72.0
set MNY [expr {$DY+138.0}]     ;# macro north = 210
gds readonly true ; gds rescale false ; gds flatten false
gds read macros/sar_digital/sar_digital.gds
load $TOP
# Confirm AFE survived the save/load round-trip at the intended origin.
select cell afe_analog_dense_0
set abox [box values]
puts "AFE_AFTER_LOAD inst_bbox=[lrange $abox 0 3] (expect LL near 2000 3400)"
select clear
box ${DX}um ${DY}um [expr {$DX+1}]um [expr {$DY+1}]um
getcell sar_digital

# ===== AFE<->macro interface (met4 pitch 0.82 = dig, clears via3 pads) =====
array set PINX {cmp_out 2.99 sample 9.43}
for {set i 0} {$i<12} {incr i} { set PINX(b$i) [expr {15.87+6.44*$i}] }
proc sig {cx cy net ytr} {
  global DY DX PINX aox aoy
  set xt [expr {$aox+$cx}] ; set yt [expr {$aoy+$cy}]
  set xd [expr {$DX+$PINX($net)}]
  afe::pbox met2 [expr {$xd-0.14}] [expr {$DY-1.4}] [expr {$xd+0.14}] [expr {$DY+0.6}]
  afe::via2 $xd [expr {$DY-1.1}]
  m3v $xd [expr {$DY-1.1}] $ytr
  afe::via3 $xd $ytr
  afe::m4h $ytr $xd $xt
  afe::via3 $xt $ytr
  m3v $xt $ytr $yt
  tapvia2 $xt $yt
}
# Port x from AFEPORT after cmp air-gaps rebuild.
sig  140.92  -5.5  cmp_out  58.00
sig    4.50   3.0  sample   58.82
sig  149.45   7.0  b0       59.64
sig  177.45   7.5  b1       60.46
sig  205.45   8.0  b2       61.28
sig  233.45   8.5  b3       62.10
sig    2.95  29.0  b4       62.92
sig   27.45  29.5  b5       63.74
sig   51.95  30.0  b6       64.56
sig   76.45  30.5  b7       65.38
sig  100.95  31.0  b8       66.20
sig  125.45  31.5  b9       67.02
sig  149.95  32.0  b10      67.84
sig  174.45  32.5  b11      68.66

# ===== analog input pins: vin_ecg->ua[0]@152.26, vref->ua[1]@132.94 (south) =====
# m4v must OVERLAP ua pin met4 (y0..1.0) — abutting y=1.0 left ua floating in extract.
proc ana {cx cy ydn xpin} {
  global aox aoy
  set xt [expr {$aox+$cx}] ; set yt [expr {$aoy+$cy}]
  tapvia2 $xt $yt
  m3v $xt $yt $ydn
  afe::via3 $xt $ydn
  afe::m4h $ydn $xt $xpin
  m4v $xpin $ydn 0.15
  afe::pbox met4 [expr {$xpin-0.20}] 0.15 [expr {$xpin+0.20}] 0.85
}
# Tap X must match AFEPORT (met2 port pads west of vias) — filled after AFE rebuild.
# ana  PORTX  T    ydn  ua_x
ana   9.58  -4.5  3.8 152.26   ;# vin_ecg -> ua[0]
ana  22.45  -4.0  2.2 132.94   ;# vref   -> ua[1]

# ===== AFE power -> stripes (below the AFE) =====
# VDPWR stripe x=1..3, VGND stripe x=4..6. Overlap pads into stripe metal.
proc pwr {cx cy ydn xstripe} {
  global aox aoy
  set xt [expr {$aox+$cx}] ; set yt [expr {$aoy+$cy}]
  tapvia2 $xt $yt
  m3v $xt $yt $ydn
  afe::via3 $xt $ydn
  afe::m4h $ydn $xt $xstripe
  afe::pbox met4 [expr {$xstripe-0.5}] [expr {$ydn-0.20}] [expr {$xstripe+0.5}] [expr {$ydn+0.20}]
}
# Placeholders retargeted from AFEPORT after rebuild.
pwr  1.995 -3.0 6.0 5.0        ;# AFE gnd -> VGND
# vdd -> VDPWR: hop on met3 (VGND stripe is met4 — a met4 hop at y=5
# from x=2..vt crosses VGND and shorts VDPWR≡VGND). Land with via3 on VDPWR.
set vt [expr {$aox+5.495}]
tapvia2 $vt [expr {$aoy-3.5}]
m3v $vt [expr {$aoy-3.5}] 5.0
afe::pbox met3 [expr {min(2.0,$vt)-0.16}] 4.84 [expr {max(2.0,$vt)+0.16}] 5.16
afe::via3 2.0 5.0
afe::pbox met4 1.0 4.7 3.0 5.3
# ===== macro PDN -> stripes (DY=72 → STRAPTOP≈200.08) =====
# Bridges must sit ABOVE strap-top met3 (via3@200.5 stacked on STRAPTOP → met3.2)
# and BELOW dig met4 (203.7+): pad ±0.26 needs ≥0.3µm clear.
set STRAPTOP [expr {$DY+128.08}]
proc strapext {x y} { global STRAPTOP
  afe::pbox met4 [expr {$x-0.8}] [expr {$STRAPTOP-0.3}] [expr {$x+0.8}] $y }
proc m3h {y x0 x1} { set lo [expr {min($x0,$x1)}]; set hi [expr {max($x0,$x1)}]
  afe::pbox met3 $lo [expr {$y-0.16}] $hi [expr {$y+0.16}] }
foreach sx {61.84 86.84} { strapext $sx 201.2 ; afe::via3 $sx 201.2 }
m3h 201.2 2.0 86.84
afe::via3 2.0 201.2
foreach sx {74.34 99.34} { strapext $sx 202.4 ; afe::via3 $sx 202.4 }
m3h 202.4 5.0 99.34
afe::via3 5.0 202.4

# ===== digital I/O: unique-y north channel (shared-met4 east corridor shorts) =====
array set MPX {clk 4.83 rst_n 8.05}
set uoL   {11.27 14.49 17.71 20.93 24.15 27.37 30.59 33.81}
set uioL  {37.03 40.25 43.47 46.69 49.91 53.13 56.35 59.57}
set oeL   {62.79 66.01 69.23 72.45 75.67 78.89 82.11 85.33}
for {set i 0} {$i<8} {incr i} {
  set MPX(uo_out$i)  [lindex $uoL  $i]
  set MPX(uio_out$i) [lindex $uioL $i]
  set MPX(uio_oe$i)  [lindex $oeL  $i]
}
array set BPX {clk 143.98 rst_n 141.22}
set uoB  {94.30 91.54 88.78 86.02 83.26 80.50 77.74 74.98}
set uioB {72.22 69.46 66.70 63.94 61.18 58.42 55.66 52.90}
set oeB  {50.14 47.38 44.62 41.86 39.10 36.34 33.58 30.82}
for {set i 0} {$i<8} {incr i} {
  set BPX(uo_out$i)  [lindex $uoB  $i]
  set BPX(uio_out$i) [lindex $uioB $i]
  set BPX(uio_oe$i)  [lindex $oeB  $i]
}
# Dig tap ABOVE macro north (ytap=MNY+0.55). Keep via2 pad ≥0.36 for
# Magic squares-grid cut emission. met2-only-to-ytr shorts all dig ports.
proc dig {net ytr2} {
  global MPX BPX DX MNY
  set mpx [expr {$DX+$MPX($net)}]
  set bpx $BPX($net)
  set a 0.18
  set ytap [expr {$MNY + 0.55}]
  afe::pbox met2 [expr {$mpx-0.14}] [expr {$MNY-0.6}] [expr {$mpx+0.14}] [expr {$ytap+$a}]
  afe::pbox met2 [expr {$mpx-$a}] [expr {$ytap-$a}] [expr {$mpx+$a}] [expr {$ytap+$a}]
  afe::pbox via2 [expr {$mpx-$a}] [expr {$ytap-$a}] [expr {$mpx+$a}] [expr {$ytap+$a}]
  afe::pbox met3 [expr {$mpx-$a}] [expr {$ytap-$a}] [expr {$mpx+$a}] [expr {$ytap+$a}]
  m3v $mpx $ytap $ytr2
  afe::via3 $mpx $ytr2
  afe::m4h $ytr2 $mpx $bpx
  afe::via3 $bpx $ytr2
  m3v $bpx $ytr2 225.26
  afe::via3 $bpx 225.26
}
set NETS {clk rst_n uo_out0 uo_out1 uo_out2 uo_out7 uio_out0 uo_out6 uio_out1 uo_out5 \
          uio_out2 uo_out4 uio_out3 uo_out3 uio_out4 uio_out5 uio_out6 uio_out7 \
          uio_oe0 uio_oe1 uio_oe2 uio_oe3 uio_oe4 uio_oe5 uio_oe6 uio_oe7}
set i 0
foreach n $NETS { dig $n [expr {203.7 + 0.82*$i}] ; incr i }

# ---- decorative silicon art (95×70) NE pocket above Row-B AZ MiMs ----
set ART_X 210.0
set ART_Y 130.0
save $TOP
gds read macros/silicon_art/silicon_art.gds
load $TOP
box ${ART_X}um ${ART_Y}um [expr {$ART_X+1}]um [expr {$ART_Y+1}]um
getcell silicon_art
puts "ART_PLACED at ($ART_X,$ART_Y)"

# ---- save + export ----
select top cell
save $TOP
puts "TOP_BBOX [box values]"
file mkdir ../gds
file mkdir ../lef
gds write ../gds/${TOP}.gds
lef write ../lef/${TOP}.lef -hide -pinonly
puts "DONE build_top_2x2"

if {[info exists env(EXTRACT)]} {
  extract all
  ext2spice lvs
  ext2spice -o top_hier.spice
  puts "EXTRACTED top_hier.spice"
}
quit -noprompt
