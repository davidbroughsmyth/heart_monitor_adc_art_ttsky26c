#!/usr/bin/env python3
"""Generate decorative SKY130 silicon art (met4) for the free pocket right of sar_digital.

Large cat faces + hearts fill the pocket; "DBS" signature along the bottom.

Drawn as solid axis-aligned met4 rectangles (no pixel gaps / no diagonal kisses)
so Magic met4.2 (≥ 0.3 µm spacing) and width rules stay clean. Rects in each
icon/letter are boolean-OR'd into continuous polygons.

Output: mag/macros/silicon_art/silicon_art.{gds,lef,svg}
"""
from __future__ import annotations
from pathlib import Path
import gdstk

CELL = "silicon_art"
OUT = Path(__file__).resolve().parent

ART_LAYER, ART_DT = 71, 20
BOUND_LAYER, BOUND_DT = 235, 4
WIDTH, HEIGHT = 185.0, 130.0
GRID = 0.005  # sky130 manufacturing grid (µm)


def snap(v: float) -> float:
    return round(v / GRID) * GRID


def write_lef(path: Path, name: str, w: float, h: float) -> None:
    path.write_text(
        f"# LEF generated for {name}\n"
        "VERSION 5.8 ;\n"
        "NAMESCASESENSITIVE ON ;\n"
        'DIVIDERCHAR "/" ;\n'
        'BUSBITCHARS "[]" ;\n'
        "UNITS\n"
        "   DATABASE MICRONS 1000 ;\n"
        "END UNITS\n\n"
        f"MACRO {name}\n"
        "   CLASS BLOCK ;\n"
        f"   FOREIGN {name} 0 0 ;\n"
        f"   SIZE {w:.3f} BY {h:.3f} ;\n"
        "   SYMMETRY X Y ;\n"
        f"END {name}\n"
    )


def R(x0, y0, x1, y1):
    x0, y0, x1, y1 = snap(x0), snap(y0), snap(x1), snap(y1)
    if x1 <= x0 or y1 <= y0:
        raise ValueError(f"degenerate rect {(x0,y0,x1,y1)}")
    return gdstk.rectangle((x0, y0), (x1, y1), layer=ART_LAYER, datatype=ART_DT)


def merge_add(cell: gdstk.Cell, polys: list) -> None:
    if not polys:
        return
    for p in gdstk.boolean(polys, [], "or", layer=ART_LAYER, datatype=ART_DT):
        # Snap every vertex onto the manufacturing grid (boolean can introduce
        # off-grid points from fractional icon math).
        pts = [(snap(x), snap(y)) for x, y in p.points]
        cell.add(gdstk.Polygon(pts, layer=ART_LAYER, datatype=ART_DT))


def cat_face(ox: float, oy: float, s: float) -> list:
    """Cat head: pointed ears, tapered chin (not square), whiskers, eye holes."""
    # Stepped silhouette — wide cheeks, chin tapering to a soft point
    silhouette = [
        R(ox + 0.18 * s, oy + 0.58 * s, ox + 0.82 * s, oy + 0.78 * s),  # brow
        R(ox + 0.12 * s, oy + 0.38 * s, ox + 0.88 * s, oy + 0.62 * s),  # cheeks
        R(ox + 0.18 * s, oy + 0.26 * s, ox + 0.82 * s, oy + 0.40 * s),  # muzzle
        R(ox + 0.26 * s, oy + 0.14 * s, ox + 0.74 * s, oy + 0.28 * s),  # chin
        R(ox + 0.34 * s, oy + 0.06 * s, ox + 0.66 * s, oy + 0.16 * s),  # lower chin
        R(ox + 0.42 * s, oy + 0.00 * s, ox + 0.58 * s, oy + 0.08 * s),  # chin tip
    ]
    # Ears (edge-connected steps)
    ears = [
        R(ox + 0.14 * s, oy + 0.72 * s, ox + 0.34 * s, oy + 0.88 * s),
        R(ox + 0.18 * s, oy + 0.88 * s, ox + 0.30 * s, oy + 0.98 * s),
        R(ox + 0.66 * s, oy + 0.72 * s, ox + 0.86 * s, oy + 0.88 * s),
        R(ox + 0.70 * s, oy + 0.88 * s, ox + 0.82 * s, oy + 0.98 * s),
    ]
    body = gdstk.boolean(silhouette + ears, [], "or",
                         layer=ART_LAYER, datatype=ART_DT)
    # Eye holes
    eyes = [
        R(ox + 0.28 * s, oy + 0.48 * s, ox + 0.40 * s, oy + 0.60 * s),
        R(ox + 0.60 * s, oy + 0.48 * s, ox + 0.72 * s, oy + 0.60 * s),
    ]
    face = gdstk.boolean(body, eyes, "not", layer=ART_LAYER, datatype=ART_DT)

    # Nose
    nose = R(ox + 0.45 * s, oy + 0.34 * s, ox + 0.55 * s, oy + 0.42 * s)

    # Whiskers — 3 per side, attached to cheeks; length kept inside inter-icon gaps
    ww = max(1.2, 0.024 * s)          # whisker thickness (≥ met4 min)
    wlen = 0.16 * s                   # ~8 µm at s=50; neighbors leave ≥10 µm gaps
    left_x = ox + 0.12 * s
    right_x = ox + 0.88 * s
    wy = [oy + 0.36 * s, oy + 0.30 * s, oy + 0.24 * s]
    whiskers = []
    for y in wy:
        whiskers.append(R(left_x - wlen, y, left_x + 0.04 * s, y + ww))
        whiskers.append(R(right_x - 0.04 * s, y, right_x + wlen, y + ww))

    return list(gdstk.boolean(list(face) + [nose] + whiskers, [], "or",
                              layer=ART_LAYER, datatype=ART_DT))


def heart(ox: float, oy: float, s: float) -> list:
    """Classic heart from overlapping solid lobes + point."""
    lobes = [
        R(ox + 0.05 * s, oy + 0.45 * s, ox + 0.50 * s, oy + 0.85 * s),
        R(ox + 0.50 * s, oy + 0.45 * s, ox + 0.95 * s, oy + 0.85 * s),
        # round the tops a bit with inset steps (edge connected)
        R(ox + 0.12 * s, oy + 0.85 * s, ox + 0.43 * s, oy + 0.95 * s),
        R(ox + 0.57 * s, oy + 0.85 * s, ox + 0.88 * s, oy + 0.95 * s),
    ]
    # Body tapering to a point (stacked horizontals)
    body = [
        R(ox + 0.08 * s, oy + 0.30 * s, ox + 0.92 * s, oy + 0.50 * s),
        R(ox + 0.18 * s, oy + 0.18 * s, ox + 0.82 * s, oy + 0.32 * s),
        R(ox + 0.30 * s, oy + 0.08 * s, ox + 0.70 * s, oy + 0.20 * s),
        R(ox + 0.40 * s, oy + 0.00 * s, ox + 0.60 * s, oy + 0.10 * s),
    ]
    return list(gdstk.boolean(lobes + body, [], "or",
                              layer=ART_LAYER, datatype=ART_DT))


def letter_dbs(ox: float, oy: float, h: float) -> list:
    """Block 'DBS'. Stroke w≈0.22*h; counters ≥ 2 µm."""
    w = h * 0.72          # letter width
    t = h * 0.22          # stroke
    gap = h * 0.35        # between letters
    polys = []

    def D(x):
        # stem + top/bot + right side (hollow left by gap in middle-right is OK — use
        # thick C-ish closed D: full rectangle minus inner counter)
        outer = R(x, oy, x + w, oy + h)
        # counter inset on the right
        inner = R(x + t, oy + t, x + w - t, oy + h - t)
        return list(gdstk.boolean([outer], [inner], "not",
                                  layer=ART_LAYER, datatype=ART_DT))

    def B(x):
        outer = R(x, oy, x + w, oy + h)
        # two counters
        c1 = R(x + t, oy + h * 0.55, x + w - t, oy + h - t)
        c2 = R(x + t, oy + t, x + w - t, oy + h * 0.45)
        return list(gdstk.boolean([outer], [c1, c2], "not",
                                  layer=ART_LAYER, datatype=ART_DT))

    def S(x):
        # three horizontal bars + side stubs (no diagonal kissing)
        bars = [
            R(x, oy + h - t, x + w, oy + h),            # top
            R(x, oy + (h - t) / 2, x + w, oy + (h + t) / 2),  # mid
            R(x, oy, x + w, oy + t),                    # bot
            R(x, oy + (h - t) / 2, x + t, oy + h),      # upper-left
            R(x + w - t, oy, x + w, oy + (h + t) / 2),  # lower-right
        ]
        return list(gdstk.boolean(bars, [], "or",
                                  layer=ART_LAYER, datatype=ART_DT))

    polys += D(ox)
    polys += B(ox + w + gap)
    polys += S(ox + 2 * (w + gap))
    # underline
    total = 3 * w + 2 * gap
    polys.append(R(ox, oy - h * 0.18, ox + total, oy - h * 0.06))
    return list(gdstk.boolean(polys, [], "or", layer=ART_LAYER, datatype=ART_DT))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    lib = gdstk.Library()
    cell = lib.new_cell(CELL)
    cell.add(gdstk.rectangle(
        (0, 0), (WIDTH, HEIGHT),
        layer=BOUND_LAYER, datatype=BOUND_DT,
    ))

    # 2×3 icons (~48 µm) — slight shrink so cat whiskers clear neighbor hearts
    s = 48.0
    sig_h = 22.0
    usable_h = HEIGHT - sig_h - 6.0
    gap_y = snap((usable_h - 2 * s) / 3.0)
    gap_x = snap((WIDTH - 3 * s) / 4.0)
    top_y = snap(HEIGHT - 4.0 - s)
    mid_y = snap(4.0 + sig_h + gap_y)

    icons = [
        (0, 0, cat_face), (1, 0, heart), (2, 0, cat_face),
        (0, 1, heart), (1, 1, cat_face), (2, 1, heart),
    ]
    for col, row, fn in icons:
        ox = snap(gap_x + col * (s + gap_x))
        oy = top_y if row == 0 else mid_y
        merge_add(cell, fn(ox, oy, s))

    # DBS signature centered on the bottom band
    lh = 16.0
    total_sig = snap(2.86 * lh)
    sx = snap((WIDTH - total_sig) / 2.0)
    sy = 5.0
    merge_add(cell, letter_dbs(sx, sy, lh))

    lib.write_gds(OUT / f"{CELL}.gds")
    write_lef(OUT / f"{CELL}.lef", CELL, WIDTH, HEIGHT)
    cell.write_svg(str(OUT / f"{CELL}.svg"))
    n = sum(1 for p in cell.polygons if p.layer == ART_LAYER)
    print(f"wrote {OUT}/{CELL}.gds  ({WIDTH}x{HEIGHT} µm, {n} met4 polys)")


if __name__ == "__main__":
    main()
