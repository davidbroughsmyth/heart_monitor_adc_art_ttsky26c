# SPDX-License-Identifier: Apache-2.0
set TOP_LEVEL_CELL     tt_um_davidbroughsmyth_ecg_sar12
set TEMPLATE_FILE      tt_analog_1x2.def
set POWER_STRIPE_WIDTH 2.0

set POWER_STRIPES {
    VDPWR 1.0
    VGND  4.0
}

def read $TEMPLATE_FILE
cellname rename tt_um_template $TOP_LEVEL_CELL

proc draw_power_stripe {name x} {
    global POWER_STRIPE_WIDTH
    set x2 [expr {$x + $POWER_STRIPE_WIDTH}]
    box ${x}um 5um ${x2}um 220.76um
    paint met4
    # label at center of stripe
    set xc [expr {($x + $x2) / 2.0}]
    box ${xc}um 112um ${xc}um 113um
    paint met4
    label $name FreeSans 0.5 -met4
    port make
    port use [expr {$name eq "VGND" ? "ground" : "power"}]
    port class bidirectional
    port connections n s e w
}

foreach {name x} $POWER_STRIPES {
    puts "Drawing power stripe $name at ${x}um"
    draw_power_stripe $name $x
}

save ${TOP_LEVEL_CELL}.mag
file mkdir ../gds
file mkdir ../lef
gds write ../gds/${TOP_LEVEL_CELL}.gds
lef write ../lef/${TOP_LEVEL_CELL}.lef -hide -pinonly
puts "WROTE gds/lef for $TOP_LEVEL_CELL"
quit -noprompt
