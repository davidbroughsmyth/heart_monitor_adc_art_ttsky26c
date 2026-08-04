# afe_slice.tcl — one R-2R bit slice, net-for-net vs analog/sky130/dacslice.spice
#   ports: bit vref gnd vdd node nout   (bitb snk internal)
#   6 FETs (bit_drive inverter + 2 TG) + 2 xhigh poly resistors (2R, R).
source afe_lib.tcl
set CELL afe_slice
load $CELL

# met2 channel-track y (gate/internal-drain nets positive; sources negative).
set T(bit)   3.0
set T(bitb)  4.0
set T(snk)   5.0
set T(nout)  6.0
set T(node) -7.0
set T(gnd)  -3.0
set T(vdd)  -4.0
set T(vref) -5.0

# FET row (pitch 3.5)
set Dbdn [afe::fet nfet 0.42 0.15  3.5 0.0]
set Dbdp [afe::fet pfet 0.84 0.15  7.0 0.0]
set Dtrn [afe::fet nfet 1.00 0.15 10.5 0.0]
set Dtrp [afe::fet pfet 2.00 0.15 14.0 0.0]
set Dtgn [afe::fet nfet 1.00 0.15 17.5 0.0]
set Dtgp [afe::fet pfet 2.00 0.15 21.0 0.0]

proc route_dev {D ns nd ng nb} {
    global T
    afe::rsrc  $D $T($ns)
    afe::rdrn  $D $T($nd)
    afe::rgat  $D $T($ng)
    afe::rbulk $D $T($nb)
}
#          D     src  drn  gate bulk
route_dev $Dbdn gnd  bitb bit  gnd
route_dev $Dbdp vdd  bitb bit  vdd
route_dev $Dtrn vref snk  bit  gnd
route_dev $Dtrp vref snk  bitb vdd
route_dev $Dtgn gnd  snk  bitb gnd
route_dev $Dtgp gnd  snk  bit  vdd

# Resistors: 2R (drawn 3.5) shunts snk->node; R (drawn 1.75) is node->nout.
# node is both resistors' BOTTOM pad (routed DOWN); snk/nout are TOP pads (UP).
set R2 [afe::res 3.5  25.5 0.0]
set R1 [afe::res 1.75 29.0 0.0]
afe::rtop   $R2 $T(snk)
afe::rbot   $R2 $T(node)
afe::rguard $R2 $T(gnd)
afe::rtop   $R1 $T(nout)
afe::rbot   $R1 $T(node)
afe::rguard $R1 $T(gnd)

# channel tracks span every via they carry (overlong is harmless: distinct y).
afe::m2h $T(bit)   3.3 21.2
afe::m2h $T(bitb)  3.7 17.7
afe::m2h $T(snk)  10.7 25.7
afe::m2h $T(nout) 28.6 29.4
afe::m2h $T(node) 25.3 29.2
afe::m2h $T(gnd)   2.4 28.4
afe::m2h $T(vdd)   5.9 20.2
afe::m2h $T(vref) 10.0 13.8

# ports
afe::mkport met2 10.5 $T(bit)  bit
afe::mkport met2 10.6 $T(vref) vref
afe::mkport met2  2.7 $T(gnd)  gnd
afe::mkport met2  6.8 $T(vdd)  vdd
afe::mkport met2 26.0 $T(node) node
afe::mkport met2 29.0 $T(nout) nout

save $CELL
puts "AFE_SLICE_BBOX [box values]"
quit -noprompt
