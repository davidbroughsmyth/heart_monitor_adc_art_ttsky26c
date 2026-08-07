# afe_lib.tcl — helpers for building connected sky130 analog child cells.
# Devices are drawn with real sky130_fd_pr Magic gencells (single finger).
# Routing convention (channel style, short-free by construction):
#   * bulk nets: shared by abutting/merging device guard rings + a met2 tie.
#   * signal terminals: li -> mcon -> met1 (vertical) -> via1 -> met2 track.
#   * one horizontal met2 track per net at a distinct y, so met1 verticals can
#     cross other nets' met2 tracks without shorting (no via at the crossing).
# All coordinates are in microns.

namespace eval afe {
    variable UM 200 ;# internal units per micron (magscale 1 2, sky130 5nm grid)
}

# Paint a rectangle of a layer given micron corners.
proc afe::pbox {layer x0 y0 x1 y1} {
    box ${x0}um ${y0}um ${x1}um ${y1}um
    paint $layer
}

# Place a labeled port marker on a layer at a point (small pad already painted).
proc afe::mkport {layer x y name} {
    box ${x}um ${y}um ${x}um ${y}um
    label $name center $layer
    port make
}

proc afe::lbl {layer x y name} {
    box ${x}um ${y}um ${x}um ${y}um
    label $name center $layer
}

# Draw a single-finger fet centered at (cx,cy). type is nfet or pfet.
# Returns a dict of terminal points: s {x y} d {x y} g {x y} nt {x y}
#   (nt = a point on the guard/tap ring = the bulk terminal).
proc afe::fet {type w l cx cy} {
    set dev sky130_fd_pr__${type}_01v8
    # gencell _draw always centers at the origin and ignores the box, so draw
    # at origin then translate the freshly-drawn geometry to (cx,cy).
    box 0 0 0 0
    set p [dict merge [sky130::${dev}_defaults] [list w $w l $l nf 1]]
    sky130::${dev}_draw $p
    box -1.6um -3.2um 1.6um 3.2um
    select area
    # Move VERTICALLY first (to the empty x=0 column), THEN horizontally. Doing
    # e-then-n would park the device at the intermediate point (cx,0); in a
    # multi-row layout another row's device already sits there, so the tiles
    # merge and the second move drags the neighbour's markers away (dropping its
    # nmos/pmos recognition -> device disappears). x=0 is always empty, so
    # n-then-e never overlaps anything.
    if {$cy != 0} { move n ${cy}um }
    if {$cx != 0} { move e ${cx}um }
    select clear
    # single-finger terminal offsets (see measured geometry):
    #   S/D li columns at +/- sdx; gate li pad above the diff; tap ring outside.
    set sdx 0.22
    if {$l >= 0.5} { set sdx [expr {$l/2.0 + 0.145}] }
    set half [expr {$w/2.0}]
    set halfx [expr {1.055 + ($l-0.15)*0.5}]
    set gy [expr {$cy + $half + 0.28}]
    set ny [expr {$cy + $half + 1.02}] ;# on the tap ring
    # The gencell also drops a poly-gate contact met1 pad on the BOTTOM end of
    # the gate (same gate net, tied through poly). We only route the TOP gate
    # pad, so the bottom one is left as an isolated 0.29x0.23um met1 shape ->
    # met1 min-area (MR_met1.AR.1 / met1.6) which TT precheck rejects. Grow it
    # DOWNWARD only (keep the 0.29um width and the original top edge so no new
    # met1 spacing to the S/D pads above or the packed neighbours) to
    # 0.29x0.30 = 0.087um^2 (>=0.083). Same net as the gate, so no short.
    afe::pbox met1 [expr {$cx-0.145}] [expr {$cy-$half-0.46}] \
                   [expr {$cx+0.145}] [expr {$cy-$half-0.16}]
    # Riser x's: source/drain just outside their contact so met1 clears the
    # gate met1 pad; gate riser at cx; tap access on the left guard rail.
    return [list \
        s   [list [expr {$cx-$sdx}] $cy] \
        d   [list [expr {$cx+$sdx}] $cy] \
        g   [list $cx $gy] \
        nt  [list $cx $ny] \
        cx  $cx  cy $cy \
        srx [expr {$cx-$sdx-0.15}] \
        drx [expr {$cx+$sdx+0.15}] \
        gy  $gy \
        tapx [expr {$cx-($halfx-0.1)}]]
}

# Draw a MiM cap (cap_mim_m3_1) centered at (cx,cy). Bottom plate = met3,
# top plate = met4/capm. Returns {bot {x y} top {x y}} access points.
proc afe::cap {w l cx cy} {
    box 0 0 0 0
    set p [dict merge [sky130::sky130_fd_pr__cap_mim_m3_1_defaults] [list w $w l $l]]
    sky130::sky130_fd_pr__cap_mim_m3_1_draw $p
    set hw [expr {$w/2.0 + 1.0}]
    box -${hw}um -${hw}um ${hw}um ${hw}um
    select area
    if {$cy != 0} { move n ${cy}um } ;# n-then-e (see afe::fet note)
    if {$cx != 0} { move e ${cx}um }
    select clear
    return [list bot [list $cx $cy] top [list $cx $cy]]
}

# li->met1 stud at (x,y). The li is kept NARROW in x (0.17, = one diff-contact
# column) so it never bridges to the poly gate; it is taller in y to give the
# mcon its li enclosure. met1 can be wider (it floats above poly/diff).
proc afe::stud {x y} {
    afe::pbox li  [expr {$x-0.085}] [expr {$y-0.20}] [expr {$x+0.085}] [expr {$y+0.20}]
    afe::pbox mcon [expr {$x-0.085}] [expr {$y-0.085}] [expr {$x+0.085}] [expr {$y+0.085}]
    afe::pbox met1 [expr {$x-0.17}] [expr {$y-0.17}] [expr {$x+0.17}] [expr {$y+0.17}]
}

# vertical met1 wire between two y at x (width 0.16)
proc afe::m1v {x y0 y1} {
    set lo [expr {min($y0,$y1)}]; set hi [expr {max($y0,$y1)}]
    afe::pbox met1 [expr {$x-0.08}] $lo [expr {$x+0.08}] $hi
}
# horizontal met1 jog
proc afe::m1h {y x0 x1} {
    set lo [expr {min($x0,$x1)}]; set hi [expr {max($x0,$x1)}]
    afe::pbox met1 $lo [expr {$y-0.08}] $hi [expr {$y+0.08}]
}
# horizontal met2 track (width 0.16)
proc afe::m2h {y x0 x1} {
    set lo [expr {min($x0,$x1)}]; set hi [expr {max($x0,$x1)}]
    afe::pbox met2 $lo [expr {$y-0.08}] $hi [expr {$y+0.08}]
}
proc afe::m2v {x y0 y1} {
    set lo [expr {min($y0,$y1)}]; set hi [expr {max($y0,$y1)}]
    afe::pbox met2 [expr {$x-0.08}] $lo [expr {$x+0.08}] $hi
}
# via1 stud met1<->met2 at (x,y)
# IMPORTANT: Magic cifoutput VIA1 uses `squares-grid 55 150 170` — it only emits
# 0.15µm cuts inside the painted via region where both metals exist. Painting a
# 0.17×0.17 marker (±0.085) streams ZERO cuts (same bug as via2/via3). Paint
# via1 over the full metal pad so >=1 cut is generated.
proc afe::via {x y} {
    set a 0.15 ;# met1 0.30x0.30 (>=0.083 area), keeps clearance to neighbours
    afe::pbox met1 [expr {$x-$a}] [expr {$y-$a}] [expr {$x+$a}] [expr {$y+$a}]
    afe::pbox via1 [expr {$x-$a}] [expr {$y-$a}] [expr {$x+$a}] [expr {$y+$a}]
    afe::pbox met2 [expr {$x-$a}] [expr {$y-$a}] [expr {$x+$a}] [expr {$y+$a}]
}
# via2 met2<->met3 ; via3 met3<->met4 (bigger cut 0.2, enclosure 0.185)
# IMPORTANT: Magic cifoutput uses `squares-grid` for VIA2/VIA3 — it only emits
# 0.2µm cut squares *inside* the painted via region where both metals exist.
# Painting a single 0.2×0.2 via marker is too small / off-grid and streams
# ZERO cuts (metals look stacked with no via in GDS/KLayout). Paint via over
# the full metal pad so >=1 cut is generated.
proc afe::via2 {x y} {
    set a 0.26 ;# met3 min area 0.24um^2 -> 0.52x0.52
    afe::pbox met2 [expr {$x-$a}] [expr {$y-$a}] [expr {$x+$a}] [expr {$y+$a}]
    afe::pbox via2 [expr {$x-$a}] [expr {$y-$a}] [expr {$x+$a}] [expr {$y+$a}]
    afe::pbox met3 [expr {$x-$a}] [expr {$y-$a}] [expr {$x+$a}] [expr {$y+$a}]
}
proc afe::via3 {x y} {
    set a 0.26
    afe::pbox met3 [expr {$x-$a}] [expr {$y-$a}] [expr {$x+$a}] [expr {$y+$a}]
    afe::pbox via3 [expr {$x-$a}] [expr {$y-$a}] [expr {$x+$a}] [expr {$y+$a}]
    afe::pbox met4 [expr {$x-$a}] [expr {$y-$a}] [expr {$x+$a}] [expr {$y+$a}]
}
proc afe::m4h {y x0 x1} {
    set lo [expr {min($x0,$x1)}]; set hi [expr {max($x0,$x1)}]
    afe::pbox met4 $lo [expr {$y-0.15}] $hi [expr {$y+0.15}] ;# met4 min width 0.3
}

# Draw an xhigh poly resistor (0.35um wide, rho=2000) of drawn length l at
# (cx,cy). It is a tall vertical device: two poly-end met1 pads on the x=cx
# axis (top at +tvy, bottom at -tvy) plus an li/psub guard ring (3rd terminal).
# Route the top pad UP and the bottom pad DOWN so the two ends never share a
# met1 riser (which would short them). tvy ~ drawn_l/2 + 0.995 (measured).
proc afe::res {l cx cy} {
    box 0 0 0 0
    set p [dict merge [sky130::sky130_fd_pr__res_xhigh_po_0p35_defaults] [list l $l]]
    sky130::sky130_fd_pr__res_xhigh_po_0p35_draw $p
    box -1um -5um 1um 5um
    select area
    if {$cy != 0} { move n ${cy}um } ;# n-then-e (see afe::fet note)
    if {$cx != 0} { move e ${cx}um }
    select clear
    set tvy [expr {$l/2.0 + 0.995}]
    return [list cx $cx cy $cy tvy $tvy gx [expr {$cx-0.74}]]
}
# Riser from a resistor terminal at (x,y0) to a met2 track (same sign, |track|>|y0|).
proc afe::rterm {x y0 ytrack} {
    afe::m1v $x $y0 $ytrack
    afe::via $x $ytrack
}
proc afe::rtop {R ytrack} { afe::rterm [dict get $R cx] [expr {[dict get $R cy]+[dict get $R tvy]}] $ytrack }
proc afe::rbot {R ytrack} { afe::rterm [dict get $R cx] [expr {[dict get $R cy]-[dict get $R tvy]}] $ytrack }
# Tie the resistor guard ring (li) to a track: mcon/met1 stud on the left rail
# then a met1 riser (clear of the terminal pads at x=cx).
proc afe::rguard {R ytrack} {
    set gx [dict get $R gx]; set cy [dict get $R cy]
    afe::stud $gx $cy
    afe::m1v  $gx $cy $ytrack
    afe::via  $gx $ytrack
}

# The sky130 gencells draw with full_metal, so source/drain/gate are already
# on metal1 pads. We route by running a met1 riser from the pad to the net's
# met2 track (via1 at the track). Riser x is chosen per terminal to overlap its
# own pad while clearing the neighbouring pads:
#   source pad ~ x in [cx-0.335, cx-0.105]  -> riser at cx-0.30
#   gate   pad ~ x in [cx-0.145, cx+0.145]  -> riser at cx
#   drain  pad ~ x in [cx+0.105, cx+0.335]  -> riser at cx+0.30
# The met1 riser starts inside the pad (y=+/-0.4) and crosses other nets' met2
# tracks harmlessly (a via1 is placed only at the destination track).
# Riser from a device pad (centered at ycen) to a met2 track, in either
# direction. Starts 'ov' past the pad centre on the far side of the track so it
# always overlaps the pad. cy-aware so a second device row (ycen != 0) routes
# correctly; for ycen=0 this reproduces the original behaviour.
proc afe::riserc {x ycen ytrack {ov 0.4}} {
    if {$ytrack > $ycen} {
        afe::m1v $x [expr {$ycen-$ov}] $ytrack
    } else {
        afe::m1v $x [expr {$ycen+$ov}] $ytrack
    }
    afe::via $x $ytrack
}
proc afe::riser {x ytrack {ystart 0.4}} { afe::riserc $x 0.0 $ytrack $ystart }
# Dict-based routing (use the per-device riser coords from afe::fet).
proc afe::rsrc {D ytrack} { afe::riserc [dict get $D srx] [dict get $D cy] $ytrack }
proc afe::rdrn {D ytrack} { afe::riserc [dict get $D drx] [dict get $D cy] $ytrack }
# Gate riser starts at the gate pad (gy) and only goes UP, so it never runs
# alongside the source/drain met1 pads (which would violate met1 spacing).
proc afe::rgat {D ytrack} {
    afe::m1v [dict get $D cx] [dict get $D gy] $ytrack
    afe::via [dict get $D cx] $ytrack
}
# Diode tie (gate net == drain net): route the drain to the track normally,
# then tie the gate pad to the drain riser with a short met1 jog at gy. This
# avoids a second via next to the drain via (which would clash on met1/met2
# for short-L devices where the gate and drain risers are only ~0.37um apart).
proc afe::rgat_to_drn {D} {
    afe::m1h [dict get $D gy] [dict get $D cx] [dict get $D drx]
}
# Bulk tie: the guard ring has no metal1, so add our own li/mcon/met1 at the
# left tap rail (well clear of the terminal pads) then riser to the track.
proc afe::rbulk {D ytrack} {
    set x [dict get $D tapx]
    afe::stud $x [dict get $D cy]
    afe::m1v  $x [dict get $D cy] $ytrack
    afe::via  $x $ytrack
}
