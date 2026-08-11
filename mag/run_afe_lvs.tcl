puts "NETGEN_START"
set setup /build/pdk/sky130A/libs.tech/netgen/sky130A_setup.tcl
readnet spice /work/mag/afe_dense_ext.spice
readnet spice /tmp/sar_afe_flat.spice
lvs {/work/mag/afe_dense_ext.spice afe_analog_dense} {/tmp/sar_afe_flat.spice sar_afe} $setup /work/mag/afe_az_lvs.log
puts "NETGEN_DONE"
