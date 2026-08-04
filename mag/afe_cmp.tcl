# afe_cmp.tcl — connected comparator child, net-for-net vs analog/sky130/comparator.spice
#   ports: vhold vdac gnd vdd cmp_out   (nbias tail d1 d2 mid internal)
#   11 devices: bias diode pair, tail, diff pair, PMOS mirror, two inverters.
source afe_lib.tcl
set CELL afe_cmp
load $CELL

# met2 channel-track y-coordinates.
#   Gate nets MUST be on positive tracks (rgat risers only go up).
#   Internal drain nets that are also gates (d1 d2 mid nbias) => positive.
#   Pure source/bulk nets (gnd vdd tail cmp_out) => negative.
set T(d1)      3.0
set T(d2)      4.0
set T(mid)     5.0
set T(nbias)   6.0
set T(vhold)   7.0
set T(vdac)    8.0
set T(gnd)    -3.0
set T(vdd)    -4.0
set T(tail)   -5.0
set T(cmp_out) -6.0

# device row, pitch 3.5 (cx>=3.2 so per-device draw@origin is safe)
set Dbp   [afe::fet pfet 0.84 1.0   3.5 0.0]
set Dbn   [afe::fet nfet 0.84 1.0   7.0 0.0]
set Dtail [afe::fet nfet 3.00 0.15 10.5 0.0]
set Dn1   [afe::fet nfet 2.00 0.15 14.0 0.0]
set Dn2   [afe::fet nfet 2.00 0.15 17.5 0.0]
set Dp1   [afe::fet pfet 3.00 0.15 21.0 0.0]
set Dp2   [afe::fet pfet 3.00 0.15 24.5 0.0]
set Di0n  [afe::fet nfet 1.00 0.15 28.0 0.0]
set Di0p  [afe::fet pfet 2.00 0.15 31.5 0.0]
set Di1n  [afe::fet nfet 0.84 0.15 35.0 0.0]
set Di1p  [afe::fet pfet 1.68 0.15 38.5 0.0]

# Route one device off its own metal1 pads. Args are the SPICE nets for
# source, drain, gate, bulk (SPICE terminal order is drain gate source bulk).
proc route_dev {D ns nd ng nb} {
    global T
    afe::rsrc  $D $T($ns)
    afe::rdrn  $D $T($nd)
    afe::rgat  $D $T($ng)
    afe::rbulk $D $T($nb)
}
#          D      src    drn     gate   bulk
route_dev $Dbp   vdd    nbias   nbias  vdd
route_dev $Dbn   gnd    nbias   nbias  gnd
route_dev $Dtail gnd    tail    nbias  gnd
route_dev $Dn1   tail   d1      vhold  gnd
route_dev $Dn2   tail   d2      vdac   gnd
# Dp1 is diode-connected (gate=drain=d1): tie gate to the drain riser locally
# instead of a second via, which would clash with the drain via on met1/met2.
afe::rsrc  $Dp1 $T(vdd)
afe::rdrn  $Dp1 $T(d1)
afe::rgat_to_drn $Dp1
afe::rbulk $Dp1 $T(vdd)
route_dev $Dp2   vdd    d2      d1     vdd
route_dev $Di0n  gnd    mid     d2     gnd
route_dev $Di0p  vdd    mid     d2     vdd
route_dev $Di1n  gnd    cmp_out mid    gnd
route_dev $Di1p  vdd    cmp_out mid    vdd

# Channel tracks span the whole device row; different nets sit on distinct y so
# crossings are met1(riser) vs met2(track) with no via -> no short.
foreach n [array names T] { afe::m2h $T($n) 1.8 39.6 }

# external ports
afe::mkport met2  6.9 $T(vhold)   vhold
afe::mkport met2  7.9 $T(vdac)    vdac
afe::mkport met2  2.0 $T(gnd)     gnd
afe::mkport met2  2.0 $T(vdd)     vdd
afe::mkport met2 39.0 $T(cmp_out) cmp_out

save $CELL
puts "AFE_CMP_BBOX [box values]"
quit -noprompt
