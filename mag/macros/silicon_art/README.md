# Silicon art (decorative, non-functional)

Pixel-style **cat faces**, **hearts**, and a bottom **“DBS”** signature on SKY130
`met4` (GDS layer 71/20), sized to fill the free pocket right of `sar_digital`.

| | |
|---|---|
| Cell | `silicon_art` — **185 × 130 µm** |
| Placement | `(140, 68)` via `mag/build_top_2x2.tcl` |
| Layers | art = met4.drawing; `prBoundary` 235/4 |
| Effect on SAR | none (floating metal, no pins / power) |

## Regenerate

```sh
python3 mag/macros/silicon_art/generate_art.py
# then: cd mag && make top
```

Preview: open `silicon_art.svg` in a browser.
