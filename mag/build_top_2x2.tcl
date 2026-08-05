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

# ---- import 2x2 template (creates die + boundary pins ua/ui/uo/uio/clk...) ----
def read tt_analog_2x2.def
cellname rename tt_um_template $TOP
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
# via2 landing on an AFE met2 track (0.46um pitch): met2 pad WIDE in x / NARROW
# in y (0.28) so it never approaches the adjacent track; met3 pad full 0.52.
proc tapvia2 {x y} {
  afe::pbox met2 [expr {$x-0.30}] [expr {$y-0.14}] [expr {$x+0.30}] [expr {$y+0.14}]
  afe::pbox via2 [expr {$x-0.10}] [expr {$y-0.10}] [expr {$x+0.10}] [expr {$y+0.10}]
  afe::pbox met3 [expr {$x-0.26}] [expr {$y-0.26}] [expr {$x+0.26}] [expr {$y+0.26}]
}

# ---- place the dense AFE (low), read its ACTUAL origin from the instance bbox ----
box 40um 13um 41um 14um
getcell afe_analog_dense
select cell afe_analog_dense_0
set bb [box values]
set aox [expr {[lindex $bb 0]/200.0 + 1.005}]
set aoy [expr {[lindex $bb 1]/200.0 + 8.65}]
puts "AFE_ORIGIN aox=$aox aoy=$aoy"
select clear

# ---- place sar_digital macro at (DX,DY); leaves a top channel y(DY+140)..225 ----
set DX 40.0 ; set DY 65.0
set MNY [expr {$DY+138.0}]     ;# macro north signal-pin row (local y138)
gds readonly true ; gds rescale false ; gds flatten false
gds read macros/sar_digital/sar_digital.gds
load $TOP
box ${DX}um ${DY}um [expr {$DX+1}]um [expr {$DY+1}]um
getcell sar_digital

# ===== AFE<->macro interface (low channel, ytr in 53..64) =====
# macro SOUTH pin x offsets (macro-local) = pin RECT CENTRES from sar_digital.lef
# (each pin is a 0.28um met2 tab; centre = left_edge + 0.14 so the via2 lands
# centred on the pin, not on its left edge).
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
#    cx     cy    net     ytr
sig  58.5  -5.5  cmp_out 53.00
sig   7.0   3.0  sample  53.77
sig  70.5   7.0  b0      54.54
sig 105.0   7.5  b1      55.31
sig 132.0   8.0  b2      56.08
sig 160.0   8.5  b3      56.85
sig 188.0   9.0  b4      57.62
sig 216.0   9.5  b5      58.39
sig  12.5  27.0  b6      59.16
sig  31.5  27.5  b7      59.93
sig  57.5  28.0  b8      60.70
sig  83.0  28.5  b9      61.47
sig 110.0  29.0  b10     62.24
sig 134.0  29.5  b11     63.01

# ===== analog input pins: vin_ecg->ua[0]@152.26, vref->ua[1]@132.94 (south) =====
proc ana {cx cy ydn xpin} {
  global aox aoy
  set xt [expr {$aox+$cx}] ; set yt [expr {$aoy+$cy}]
  tapvia2 $xt $yt
  m3v $xt $yt $ydn
  afe::via3 $xt $ydn
  afe::m4h $ydn $xt $xpin
  m4v $xpin $ydn 0.5
  afe::pbox met4 [expr {$xpin-0.16}] [expr {$ydn-0.16}] [expr {$xpin+0.16}] [expr {$ydn+0.16}]
}
ana 12.0 -4.5  3.7 152.26   ;# vin_ecg -> ua[0]
ana 75.0 -4.0  2.5 132.94   ;# vref   -> ua[1]

# ===== AFE power -> stripes (below the AFE) =====
proc pwr {cx cy ydn xstripe} {
  global aox aoy
  set xt [expr {$aox+$cx}] ; set yt [expr {$aoy+$cy}]
  tapvia2 $xt $yt
  m3v $xt $yt $ydn
  afe::via3 $xt $ydn
  afe::m4h $ydn $xt $xstripe
}
pwr 60.0 -3.0 6.0 5.0        ;# AFE gnd -> VGND stripe (x4..6)
# vdd -> VDPWR: VDPWR stripe (x1..3) is LEFT of VGND (x4..6); hop under VGND on met3.
set vt [expr {$aox+65}]
tapvia2 $vt [expr {$aoy-3.5}]
m3v $vt [expr {$aoy-3.5}] 5.0
afe::via3 $vt 5.0
afe::m4h 5.0 7.0 $vt
afe::via3 7.0 5.0
afe::pbox met3 1.3 4.84 7.16 5.16
afe::via3 2.0 5.0

# ===== macro PDN -> stripes (top-margin met3 bridges; margin y194..206 is clear
#       of macro met3/met4). Extend each strap up into the margin, bridge on met3
#       across the tile (crosses the OTHER rail's met4 straps harmlessly), and
#       via3 onto the target left stripe. =====
# macro strap centres (top coords): VPWR x=61.84,86.84 ; VGND x=74.34,99.34
set STRAPTOP [expr {$DY+128.08}]   ;# 194.08
proc strapext {x y} { global STRAPTOP
  afe::pbox met4 [expr {$x-0.8}] [expr {$STRAPTOP-0.3}] [expr {$x+0.8}] $y }
proc m3h {y x0 x1} { set lo [expr {min($x0,$x1)}]; set hi [expr {max($x0,$x1)}]
  afe::pbox met3 $lo [expr {$y-0.16}] $hi [expr {$y+0.16}] }
# VPWR bridge at y=197 -> VDPWR stripe (x1..3)
foreach sx {61.84 86.84} { strapext $sx 197.0 ; afe::via3 $sx 197.0 }
m3h 197.0 2.0 86.84
afe::via3 2.0 197.0          ;# met3 -> met4 onto VDPWR stripe
# VGND bridge at y=199 -> VGND stripe (x4..6)
foreach sx {74.34 99.34} { strapext $sx 199.0 ; afe::via3 $sx 199.0 }
m3h 199.0 5.0 99.34
afe::via3 5.0 199.0          ;# met3 -> met4 onto VGND stripe

# ===== digital I/O: macro NORTH pins (met2, y=MNY) -> tile NORTH boundary pins
#       (met4, y=225.26) through the top channel (ytr2 in 205..224). =====
# macro north pin x (macro-local) per net:
array set MPX {clk 4.83 rst_n 8.05}
set uoL   {11.27 14.49 17.71 20.93 24.15 27.37 30.59 33.81}
set uioL  {37.03 40.25 43.47 46.69 49.91 53.13 56.35 59.57}
set oeL   {62.79 66.01 69.23 72.45 75.67 78.89 82.11 85.33}
for {set i 0} {$i<8} {incr i} {
  set MPX(uo_out$i)  [lindex $uoL  $i]
  set MPX(uio_out$i) [lindex $uioL $i]
  set MPX(uio_oe$i)  [lindex $oeL  $i]
}
# tile north boundary pin x per net (from the template DEF):
array set BPX {clk 143.98 rst_n 141.22}
set uoB  {94.30 91.54 88.78 86.02 83.26 80.50 77.74 74.98}
set uioB {72.22 69.46 66.70 63.94 61.18 58.42 55.66 52.90}
set oeB  {50.14 47.38 44.62 41.86 39.10 36.34 33.58 30.82}
for {set i 0} {$i<8} {incr i} {
  set BPX(uo_out$i)  [lindex $uoB  $i]
  set BPX(uio_out$i) [lindex $uioB $i]
  set BPX(uio_oe$i)  [lindex $oeB  $i]
}
proc dig {net ytr2} {
  global MPX BPX DX MNY
  set mpx [expr {$DX+$MPX($net)}]
  set bpx $BPX($net)
  # macro north pin (met2) -> met3 riser up to the track -> met4
  afe::pbox met2 [expr {$mpx-0.14}] [expr {$MNY-0.6}] [expr {$mpx+0.14}] [expr {$MNY+0.6}]
  afe::via2 $mpx $MNY
  # macro-side riser painted 0.52 wide so it fully subsumes the via2 (at the pin)
  # and via3 (at the track) met3 pads -- otherwise the lowest net (clk, track only
  # ~0.7um above its pin) leaves a sub-0.3 notch between the two pads (m3.2).
  afe::pbox met3 [expr {$mpx-0.26}] [expr {$MNY-0.26}] [expr {$mpx+0.26}] [expr {$ytr2+0.26}]
  afe::via3 $mpx $ytr2
  afe::m4h $ytr2 $mpx $bpx
  # -> met3 riser up to the boundary pin (met4)
  afe::via3 $bpx $ytr2
  m3v $bpx $ytr2 225.26
  afe::via3 $bpx 225.26
}
# track order from a left-edge solve of the vertical-conflict graph (macro-side
# riser of A near boundary-side riser of B  =>  A must get a lower track). The
# graph is acyclic, so this ordering makes every riser pair y-disjoint; pitch
# 0.84 keeps stacked via3 pads (0.52) clear (MR_via3/m3.2).
set NETS {clk rst_n uo_out0 uo_out1 uo_out2 uo_out7 uio_out0 uo_out6 uio_out1 uo_out5 \
          uio_out2 uo_out4 uio_out3 uo_out3 uio_out4 uio_out5 uio_out6 uio_out7 \
          uio_oe0 uio_oe1 uio_oe2 uio_oe3 uio_oe4 uio_oe5 uio_oe6 uio_oe7}
set i 0
foreach n $NETS { dig $n [expr {203.7 + 0.82*$i}] ; incr i }

# ---- decorative silicon art (non-functional met4) in the free pocket right of
#      the macro: cats + hearts + "DBS" signature. 185x130 µm at (140, 68) —
#      clears macro (x<=130), top dig channel (y>=205), and AFE band (y<=60).
#      Floating metal only; no ports / no power. ----
set ART_X 140.0
set ART_Y 68.0
gds read macros/silicon_art/silicon_art.gds
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
