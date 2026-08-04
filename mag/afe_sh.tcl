# afe_sh.tcl — connected Sample/Hold child, net-for-net vs analog/sky130/sample_hold.spice
#   ports: vin sample gnd vdd vhold   (sample_b internal)
#   devices: Xinv_pd(nfet .42) Xinv_pu(pfet .84) Xtn(nfet 1.0) Xtp(pfet 2.0) Xchold(cap 2x2)
source afe_lib.tcl
set CELL afe_sh
load $CELL

# net met2 track y-coordinates (clear of device bodies |y|<2.1)
set T(vhold)   -5.0
set T(vin)     -4.0
set T(gnd)     -3.0
set T(sample)   3.0
set T(sample_b) 4.0
set T(vdd)      5.0

# devices in one row (pitch 3.5; every cx>=3.2 so per-device draw@origin is safe)
set Dpd [afe::fet nfet 0.42 0.15  3.5 0.0]
set Dtn [afe::fet nfet 1.00 0.15  7.0 0.0]
set Dpu [afe::fet pfet 0.84 0.15 10.5 0.0]
set Dtp [afe::fet pfet 2.00 0.15 14.0 0.0]
set Dc  [afe::cap 2 2 20.0 0.0]

proc pt {d k i} { lindex [dict get $d $k] $i }

# Route one device off its own metal1 pads. Gate nets must be on positive tracks.
proc route_dev {D ns nd ng nb} {
    global T
    afe::rsrc $D $T($ns)
    afe::rdrn $D $T($nd)
    afe::rgat $D $T($ng)
    afe::rbulk $D $T($nb)
}
route_dev $Dpd gnd sample_b sample gnd
route_dev $Dtn vin vhold    sample gnd
route_dev $Dpu vdd sample_b sample vdd
route_dev $Dtp vin vhold    sample_b vdd

# met2 tracks span all their via x-positions (gnd/vhold extended to the cap)
afe::m2h $T(gnd)      2.5 20.6
afe::m2h $T(vin)      6.6 13.8
afe::m2h $T(vhold)   -1.0 17.6
afe::m2h $T(sample)   3.4 10.6
afe::m2h $T(sample_b) 3.7 14.1
afe::m2h $T(vdd)      9.5 13.3

# hold cap Xchold: bottom plate (met3) -> gnd ; top plate (met4) -> vhold.
# bottom plate: via2 on the met3 plate, met1 riser down to the gnd track.
afe::via2 20.5 0.0
afe::via  20.5 0.0
afe::m1v  20.5 0.0 $T(gnd)
afe::via  20.5 $T(gnd)
# top plate: extend the met4 top-plate frame left (clear of the met3 plate),
# then via3->met3 island->via2->met1 riser down to the vhold track.
afe::m4h  0.0 17.4 18.5
afe::via3 17.5 0.0
afe::via2 17.5 0.0
afe::via  17.5 0.0
afe::m1v  17.5 0.0 $T(vhold)
afe::via  17.5 $T(vhold)

# ports
afe::mkport met2  5.1 $T(sample) sample
afe::mkport met2  6.8 $T(vin)    vin
afe::mkport met2  7.3 $T(vhold)  vhold
afe::mkport met2  2.7 $T(gnd)    gnd
afe::mkport met2  9.7 $T(vdd)    vdd

save $CELL
puts "AFE_SH_BBOX [box values]"
quit -noprompt
