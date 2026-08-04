# Magic / OpenLane helpers for heart_monitor_adc
TOP = tt_um_davidbroughsmyth_ecg_sar12
PDK_ROOT ?= $(HOME)/.volare/volare/sky130/versions/cd1748bb197f9b7af62a54507de6624e30363943
IMAGE ?= efabless/openlane:9dbd8b5ea2bd891bed4dcc97df5c7439083f0368-arm64v8
DOCKER = docker run --rm --platform linux/arm64 \
	-v $(CURDIR)/..:/work \
	-v $(PDK_ROOT):/build/pdk \
	-e PDK_ROOT=/build/pdk -e PDK=sky130A \
	-w /work/mag $(IMAGE)

.PHONY: start afe integrate update_gds top top-verify harden magic-shell

# ---- 2x2 connected flow (real dense AFE routed to the sar_digital macro) ----
# build_top_2x2.tcl is self-contained: imports the TT 2x2 template, places the
# dense AFE + sar_digital macro, routes the analog interface, writes gds/lef.
top:
	$(DOCKER) bash -lc 'magic -noconsole -dnull -rcfile /build/pdk/sky130A/libs.tech/magic/sky130A.magicrc build_top_2x2.tcl'

update_gds: top

# rebuild + hierarchical extract (EXTRACT=1) to dump top_hier.spice for a
# connectivity check of the AFE<->macro interface.
top-verify:
	$(DOCKER) bash -lc 'EXTRACT=1 magic -noconsole -dnull -rcfile /build/pdk/sky130A/libs.tech/magic/sky130A.magicrc build_top_2x2.tcl'

# ---- legacy metal-only 1x2 placeholder flow (kept for reference) ----
start:
	$(DOCKER) bash -lc 'magic -noconsole -dnull -rcfile /build/pdk/sky130A/libs.tech/magic/sky130A.magicrc magic_init_project.tcl'

afe:
	$(DOCKER) bash -lc 'magic -noconsole -dnull -rcfile /build/pdk/sky130A/libs.tech/magic/sky130A.magicrc layout_afe.tcl'

integrate:
	$(DOCKER) bash -lc 'magic -noconsole -dnull -rcfile /build/pdk/sky130A/libs.tech/magic/sky130A.magicrc integrate.tcl'

harden:
	docker run --rm --platform linux/arm64 \
		-v $(CURDIR)/..:/work \
		-v $(PDK_ROOT):/build/pdk \
		-e PDK_ROOT=/build/pdk -e PDK=sky130A \
		-w /openlane $(IMAGE) \
		bash -lc './flow.tcl -design /work/mag/openlane/sar_digital -tag harden -overwrite'

magic-shell:
	$(DOCKER) bash
