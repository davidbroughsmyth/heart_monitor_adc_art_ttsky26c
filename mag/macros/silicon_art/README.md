# Silicon art (decorative, non-functional)

**Cat faces**, **hearts**, and a bottom **“DBS”** signature on SKY130 `met4`
(GDS layer 71/20), filling the free pocket right of `sar_digital`.

| | |
|---|---|
| Cell | `silicon_art` — **185 × 130 µm** |
| Placement | `(140, 68)` via `mag/build_top_2x2.tcl` |
| Layers | art = met4.drawing; `prBoundary` 235/4 |
| Effect on SAR | none (floating metal, no pins / power) |

### Cat motif

- Tapered chin (not square)
- Whiskers (3 per side)
- Eyes + **cute inverted-triangle nose** as holes
- **U-style** mouth arcs (taller inside stems, shorter outside)

Hearts alternate with cats in a 2×3 grid; `DBS` is centered under an underline.

## Regenerate

```sh
python3 mag/macros/silicon_art/generate_art.py
# then: cd mag && make top
```

Vertices are snapped to the 0.005 µm manufacturing grid (TT offgrid DRC).
Preview: open `silicon_art.svg` in a browser (hole fills in SVG thumbnails can look
solid; GDS has the punched noses/mouths).
