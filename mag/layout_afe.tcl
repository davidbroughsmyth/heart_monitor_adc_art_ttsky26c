# layout_afe.tcl — best-effort real-device AFE (sky130_fd_pr via Magic gencells)
# Places S/H, comparator, and a compact R-2R CDAC in the keepout below/left
# of sar_digital. No user met5.

set TOP tt_um_davidbroughsmyth_ecg_sar12
load $TOP

proc afe_nfet {x_um y_um {w 1.0} {l 0.15}} {
    box ${x_um}um ${y_um}um ${x_um}um ${y_um}um
    set params [sky130::sky130_fd_pr__nfet_01v8_defaults]
    dict set params w $w
    dict set params l $l
    dict set params guard 0
    dict set params glc 0
    dict set params grc 0
    dict set params gtc 0
    dict set params gbc 0
    sky130::sky130_fd_pr__nfet_01v8_draw $params
}

proc afe_pfet {x_um y_um {w 2.0} {l 0.15}} {
    box ${x_um}um ${y_um}um ${x_um}um ${y_um}um
    set params [sky130::sky130_fd_pr__pfet_01v8_defaults]
    dict set params w $w
    dict set params l $l
    dict set params guard 0
    dict set params glc 0
    dict set params grc 0
    dict set params gtc 0
    dict set params gbc 0
    sky130::sky130_fd_pr__pfet_01v8_draw $params
}

proc afe_mim {x_um y_um {w 2.0} {l 2.0}} {
    box ${x_um}um ${y_um}um ${x_um}um ${y_um}um
    set params [sky130::sky130_fd_pr__cap_mim_m3_1_defaults]
    dict set params w $w
    dict set params l $l
    sky130::sky130_fd_pr__cap_mim_m3_1_draw $params
}

proc afe_res_m1 {x_um y_um {w 0.5} {l 20.0}} {
    box ${x_um}um ${y_um}um ${x_um}um ${y_um}um
    set params [sky130::sky130_fd_pr__res_generic_m1_defaults]
    dict set params w $w
    dict set params l $l
    dict set params guard 0
    sky130::sky130_fd_pr__res_generic_m1_draw $params
}

# ---------------------------------------------------------------------------
# Sample/hold near ua[0] (bottom)
# ---------------------------------------------------------------------------
afe_nfet 120 18 1.0 0.15
label sample FreeSans 0.35 -li
afe_pfet 125 18 2.0 0.15
afe_mim 135 22 2.0 2.0
label vhold FreeSans 0.4 -met3
# local invert for sample_b
afe_nfet 115 18 0.42 0.15
afe_pfet 115 22 0.84 0.15
label sample_b FreeSans 0.3 -li

# ua[0] strap into hold region
box 151.81um 0.50um 152.71um 25um
paint met4
box 140um 22um 152.71um 24um
paint met4
label vin_ecg FreeSans 0.35 -met4

# ---------------------------------------------------------------------------
# Comparator (left-mid)
# ---------------------------------------------------------------------------
afe_pfet 25 55 0.84 1.0
afe_nfet 25 50 0.84 1.0
label nbias FreeSans 0.3 -li
afe_nfet 35 52 3.0 0.15
afe_nfet 42 55 2.0 0.15
afe_nfet 42 48 2.0 0.15
afe_pfet 50 55 3.0 0.15
afe_pfet 50 48 3.0 0.15
afe_nfet 58 52 1.0 0.15
afe_pfet 58 56 2.0 0.15
afe_nfet 65 52 0.84 0.15
afe_pfet 65 56 1.68 0.15
label cmp_out FreeSans 0.4 -li
label vdac FreeSans 0.35 -met2

# ---------------------------------------------------------------------------
# Compact R-2R CDAC (bottom-left): 12 series R + bit 2R stubs + switch FETs
# Values are structural (first-pass); electrical match to SPICE is approximate.
# ---------------------------------------------------------------------------
set x0 12.0
set y0 8.0
for {set i 0} {$i < 12} {incr i} {
    set x [expr {$x0 + $i * 4.0}]
    afe_res_m1 $x $y0 0.5 12.0
    afe_res_m1 $x [expr {$y0 + 8}] 0.5 12.0
    afe_nfet $x [expr {$y0 + 16}] 1.0 0.15
    afe_pfet $x [expr {$y0 + 20}] 2.0 0.15
    afe_nfet [expr {$x + 1.5}] [expr {$y0 + 16}] 1.0 0.15
    afe_pfet [expr {$x + 1.5}] [expr {$y0 + 20}] 2.0 0.15
    label b$i FreeSans 0.25 -li
}
label dac_ladder FreeSans 0.4 -met1

# ua[1] / vref strap
box 132.49um 0.50um 133.39um 40um
paint met4
box 60um 30um 133.39um 32um
paint met4
label vref FreeSans 0.35 -met4

# Digital keepout marker (sar_digital placed by integrate.tcl)
box 65um 75um 155um 215um
label sar_digital_area FreeSans 1.0 -met4

# Rough local interconnect stubs (finished in integrate.tcl)
box 65um 55um 100um 57um
paint met2
box 100um 18um 120um 20um
paint met2
box 58um 52um 100um 53um
paint li

save $TOP
puts "AFE real-device paint done"
quit -noprompt
