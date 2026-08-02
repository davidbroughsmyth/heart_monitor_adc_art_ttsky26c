set ::env(DESIGN_NAME) sar_digital
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/src/*.v]
set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "20"
set ::env(FP_SIZING) absolute
# Leave room on left for power stripes + AFE on bottom/right of 1x2 tile
set ::env(DIE_AREA) "0 0 90 140"
set ::env(PLACE_DENSITY) 0.45
set ::env(FP_CORE_UTIL) 40
set ::env(FP_PDN_VPITCH) 25
set ::env(FP_PDN_HPITCH) 25
set ::env(RT_MAX_LAYER) met4
set ::env(SYNTH_PARAMETERS) ""
