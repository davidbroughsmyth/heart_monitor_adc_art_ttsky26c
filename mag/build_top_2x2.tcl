# build_top_2x2.tcl — assemble the 2x2 analog tile top cell:
#   * import the TT 2x2 analog template (die + boundary pins)
#   * place the hardened sar_digital macro (top) and the dense AFE (bottom)
#   * route the analog interface: 14 signals (cmp_out, sample, dac_bits[0..11]
#     <-> AFE cmp_out/sample/b0..b11), vin_ecg->ua[0], vref->ua[1], and power.
# Routing convention in the channel between the two blocks:
#   digital pin (met2, south edge) -> via2 -> met3 vertical -> via3 ->
#   met4 horizontal (one distinct y per net) -> via3 -> met3 vertical -> via2
#   -> AFE net's met2 track. met4 horizontals never share y; met3 verticals
#   never share x (checked), so the channel is short-free.
source afe_lib.tcl
set TOP tt_um_davidbroughsmyth_ecg_sar12

# ---- import 2x2 template (creates die + boundary pins ua/ui/uo/uio/clk...) ----
def read tt_analog_2x2.def
cellname rename tt_um_template $TOP
load $TOP

# ---- power stripes (left edge), match the existing 1x2 convention ----
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

# ---- extra routing helpers ----
proc m3v {x y0 y1} { set lo [expr {min($y0,$y1)}]; set hi [expr {max($y0,$y1)}]
  afe::pbox met3 [expr {$x-0.16}] $lo [expr {$x+0.16}] $hi }
# via2 landing on an AFE met2 track (0.46um pitch): met2 pad WIDE in x / NARROW
# in y (0.28) so it never approaches the adjacent track; met3 pad full 0.52.
proc tapvia2 {x y} {
  afe::pbox met2 [expr {$x-0.30}] [expr {$y-0.14}] [expr {$x+0.30}] [expr {$y+0.14}]
  afe::pbox via2 [expr {$x-0.10}] [expr {$y-0.10}] [expr {$x+0.10}] [expr {$y+0.10}]
  afe::pbox met3 [expr {$x-0.26}] [expr {$y-0.26}] [expr {$x+0.26}] [expr {$y+0.26}]
}
proc m4v {x y0 y1} { set lo [expr {min($y0,$y1)}]; set hi [expr {max($y0,$y1)}]
  afe::pbox met4 [expr {$x-0.15}] $lo [expr {$x+0.15}] $hi }

# ---- place the dense AFE, then read its ACTUAL origin from the instance bbox ----
# (getcell's placement is not a simple box-LL align because the cell origin sits
# inside its negative-extent bbox, so we measure it rather than assume it.)
# box chosen so the measured child origin (aoy ~= box_y + 3.5) puts the AFE band
# clear of the power routes below (ydn <= 12) and the signal channel above (ytr >= 67)
box 40um 24um 41um 25um
getcell afe_analog_dense
select cell afe_analog_dense_0
set bb [box values]          ;# instance bbox (internal units) in top coords
set aox [expr {[lindex $bb 0]/200.0 + 1.005}]   ;# child (0,0) x in top coords
set aoy [expr {[lindex $bb 1]/200.0 + 8.65}]    ;# child (0,0) y in top coords
puts "AFE_ORIGIN aox=$aox aoy=$aoy"
select clear
# ---- place sar_digital macro, lower-left at (DX,DY) ----
set DX 40.0 ; set DY 85.0
gds readonly true ; gds rescale false ; gds flatten false
gds read macros/sar_digital/sar_digital.gds
load $TOP
box ${DX}um ${DY}um [expr {$DX+1}]um [expr {$DY+1}]um
getcell sar_digital

# digital south-pin x offsets (macro coords): cmp_out, sample, dac_bits[0..11]
array set PINX {cmp_out 2.85 sample 9.29}
for {set i 0} {$i<12} {incr i} { set PINX(b$i) [expr {15.73+6.44*$i}] }

# ===== signal routing: AFE net tap given in CHILD coords {cx cy}, digital pin
#       by name, met4 channel track ytr. tap_abs = (aox+cx, aoy+cy). =====
proc sig {cx cy net ytr} {
  global DY DX PINX aox aoy
  set xt [expr {$aox+$cx}] ; set yt [expr {$aoy+$cy}]
  set xd [expr {$DX+$PINX($net)}]
  # stub the digital pin (met2) down just below the macro, then go to met3
  afe::pbox met2 [expr {$xd-0.14}] [expr {$DY-1.4}] [expr {$xd+0.14}] [expr {$DY+0.6}]
  afe::via2 $xd [expr {$DY-1.1}]
  m3v $xd [expr {$DY-1.1}] $ytr
  afe::via3 $xd $ytr
  afe::m4h $ytr $xd $xt
  afe::via3 $xt $ytr
  m3v $xt $ytr $yt
  tapvia2 $xt $yt
}
# tap = mid-track point of each AFE net (child coords, within its VMN..VMX span)
# net           cx     cy    digitalpin  ytr
sig  58.5  -5.5  cmp_out 67.0
sig   7.0   3.0  sample  68.2
sig  70.5   7.0  b0      69.4
sig 105.0   7.5  b1      70.6
sig 132.0   8.0  b2      71.8
sig 160.0   8.5  b3      73.0
sig 188.0   9.0  b4      74.2
sig 216.0   9.5  b5      75.4
sig  12.5  27.0  b6      76.6
sig  31.5  27.5  b7      77.8
sig  57.5  28.0  b8      79.0
sig  83.0  28.5  b9      80.2
sig 110.0  29.0  b10     81.4
sig 134.0  29.5  b11     82.6

# ===== analog input pins: vin_ecg->ua[0]@152.26, vref->ua[1]@132.94 =====
proc ana {cx cy ydn xpin} {
  global aox aoy
  set xt [expr {$aox+$cx}] ; set yt [expr {$aoy+$cy}]
  tapvia2 $xt $yt
  m3v $xt $yt $ydn
  afe::via3 $xt $ydn
  afe::m4h $ydn $xt $xpin
  m4v $xpin $ydn 0.5   ;# down to the south ua pin (met4)
}
ana 12.0 -4.5  8.0 152.26   ;# vin_ecg -> ua[0]
ana 75.0 -4.0  6.0 132.94   ;# vref   -> ua[1]

# ===== AFE power to the stripes (met4 horizontal reaches the stripe) =====
proc pwr {cx cy ydn xstripe} {
  global aox aoy
  set xt [expr {$aox+$cx}] ; set yt [expr {$aoy+$cy}]
  tapvia2 $xt $yt
  m3v $xt $yt $ydn
  afe::via3 $xt $ydn
  afe::m4h $ydn $xt $xstripe
}
pwr 60.0 -3.0 10.0 5.0   ;# AFE gnd -> VGND stripe (x4..6)
# vdd -> VDPWR: the VDPWR stripe (x1..3) sits LEFT of the VGND stripe (x4..6),
# so a met4 run would cross (short) VGND. Hop under VGND on met3 instead.
set vt [expr {$aox+65}]
tapvia2 $vt [expr {$aoy-3.5}]
m3v $vt [expr {$aoy-3.5}] 12.0
afe::via3 $vt 12.0
afe::m4h 12.0 7.0 $vt              ;# met4 from tap to x7 (right of VGND stripe)
afe::via3 7.0 12.0                 ;# met4->met3 at x7
afe::pbox met3 1.3 11.84 7.16 12.16 ;# met3 hops under VGND (x7 -> x1.3)
afe::via3 2.0 12.0                 ;# met3->met4 onto VDPWR stripe (x1..3)
# NOTE: sar_digital VGND/VPWR pins are delivered by the TT tile power grid
# (labeled met4 straps in the macro); AFE gnd/vdd tie to the same VGND/VDPWR
# tile nets via the stripes above, so all power is common.

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
