#!/usr/bin/env python3
"""Generate decorative SKY130 silicon art (met4) for the free pocket right of sar_digital.

Icons: cat faces + hearts filling the pocket; signature "DBS" along the bottom.

Output:
  mag/macros/silicon_art/silicon_art.gds
  mag/macros/silicon_art/silicon_art.lef
  mag/macros/silicon_art/silicon_art.svg   (preview only)

Fits ~185 x 130 µm; placed by mag/build_top_2x2.tcl at (140, 68).
"""
from __future__ import annotations
from pathlib import Path
import gdstk

CELL = "silicon_art"
OUT = Path(__file__).resolve().parent

# SKY130 — Tiny Tapeout silicon-art guide
ART_LAYER, ART_DT = 71, 20          # met4.drawing
BOUND_LAYER, BOUND_DT = 235, 4      # prBoundary

# Pocket-friendly macro size (leave margins to macro edge / dig channel / tile edge)
WIDTH, HEIGHT = 185.0, 130.0
PX = 1.6                            # pixel pitch (>> met4 min width/spacing)


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


def add_px(cell: gdstk.Cell, ox: float, oy: float, grid: list[str],
           scale: float = PX) -> None:
    """Paint '#' pixels from a bitmap (row 0 = top). Origin = lower-left of glyph."""
    rows = len(grid)
    cols = max(len(r) for r in grid)
    for r, line in enumerate(grid):
        y1 = oy + (rows - 1 - r) * scale
        for c, ch in enumerate(line):
            if ch == "#":
                x1 = ox + c * scale
                cell.add(gdstk.rectangle(
                    (x1, y1), (x1 + scale * 0.92, y1 + scale * 0.92),
                    layer=ART_LAYER, datatype=ART_DT,
                ))


# --- icon bitmaps (compact; painted at PX or 2*PX) ---------------------------------
CAT = [
    "#..#...#..#",
    ".#.#...#.#.",
    "..#######..",
    ".#.......#.",
    "#..#...#..#",
    "#.........#",
    "#..#####..#",
    ".#.......#.",
    "..#######..",
]

HEART = [
    ".###...###.",
    "#####.#####",
    "###########",
    ".#########.",
    "..#######..",
    "...#####...",
    "....###....",
    ".....#.....",
]

# 5x7 capitals for DBS
GLYPHS = {
    "D": [
        "####.",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        "####.",
    ],
    "B": [
        "####.",
        "#...#",
        "#...#",
        "####.",
        "#...#",
        "#...#",
        "####.",
    ],
    "S": [
        ".####",
        "#....",
        "#....",
        ".###.",
        "....#",
        "....#",
        "####.",
    ],
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    lib = gdstk.Library()
    cell = lib.new_cell(CELL)

    # PR boundary (required)
    cell.add(gdstk.rectangle(
        (0, 0), (WIDTH, HEIGHT),
        layer=BOUND_LAYER, datatype=BOUND_DT,
    ))

    # --- icon field: 2 rows x 3 cols of alternating cats / hearts ----------------
    # Each icon ~11 * 1.6 ≈ 17.6 µm; with spacing fills width comfortably.
    icon = 11 * PX
    gap_x = (WIDTH - 3 * icon) / 4.0
    gap_y = 4.0
    top_y = HEIGHT - 6.0 - icon          # upper row
    mid_y = top_y - icon - gap_y         # lower icon row
    icons = [
        (0, 0, CAT), (1, 0, HEART), (2, 0, CAT),
        (0, 1, HEART), (1, 1, CAT), (2, 1, HEART),
    ]
    for col, row, bmp in icons:
        ox = gap_x + col * (icon + gap_x)
        oy = top_y if row == 0 else mid_y
        add_px(cell, ox, oy, bmp, PX)

    # Decorative small hearts between rows as filler accents
    mini = [
        ".#.#.",
        "#####",
        ".###.",
        "..#..",
    ]
    for i, ox in enumerate([gap_x + icon * 0.55,
                            gap_x + icon + gap_x + icon * 0.55,
                            gap_x + 2 * (icon + gap_x) + icon * 0.15]):
        add_px(cell, ox, mid_y + icon + 0.6, mini, PX * 0.7)

    # --- signature "DBS" along the bottom ---------------------------------------
    gpx = 2.0                                   # larger pixels for the name
    gw, gh = 5 * gpx, 7 * gpx
    letter_gap = 3.0
    total_w = 3 * gw + 2 * letter_gap
    sx = (WIDTH - total_w) / 2.0
    sy = 4.0
    for i, ch in enumerate("DBS"):
        add_px(cell, sx + i * (gw + letter_gap), sy, GLYPHS[ch], gpx)

    # Thin underline under the signature
    cell.add(gdstk.rectangle(
        (sx, sy - 2.2), (sx + total_w, sy - 0.6),
        layer=ART_LAYER, datatype=ART_DT,
    ))

    lib.write_gds(OUT / f"{CELL}.gds")
    write_lef(OUT / f"{CELL}.lef", CELL, WIDTH, HEIGHT)
    cell.write_svg(str(OUT / f"{CELL}.svg"))
    print(f"wrote {OUT}/{CELL}.gds  ({WIDTH} x {HEIGHT} µm)")
    print(f"wrote {OUT}/{CELL}.lef")
    print(f"wrote {OUT}/{CELL}.svg  (preview)")


if __name__ == "__main__":
    main()
