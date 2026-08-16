#!/usr/bin/env python3
"""Pulls rendered sprites toward the ship's palette.

    tools/grim_sprites.py assets/crew/*.png

Kenney's Mini Characters are bright and pastel by design. Dropped unmodified
onto a worn steel hull they read as toys on a battleship — the same clash that
killed the station props in the medbay.

Two steps, both in place:

1. Desaturate hard, leaving a trace of the original hue so the models do not all
   collapse into identical grey. What remains of the colour is not what
   identifies a crew member — the game tints each sprite by class at runtime,
   and that only works if the base is close to neutral.

2. Darken. The compartment lights in ShipView are additive, so anything that
   looks correct in isolation blows out once a light falls on it. This was
   learned the expensive way on the hand-drawn crew.

Alpha is preserved exactly; the models were rendered on a transparent
background and the silhouette is the most valuable part of the render.
"""

import sys
from PIL import Image

SATURATION = 0.16
BRIGHTNESS = 0.62


def grim(path: str) -> None:
    img = Image.open(path).convert("RGBA")
    px = img.load()
    w, h = img.size

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # Rec. 709 luma: a plain average turns skin and cloth the same grey.
            luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            px[x, y] = (
                int((luma + (r - luma) * SATURATION) * BRIGHTNESS),
                int((luma + (g - luma) * SATURATION) * BRIGHTNESS),
                int((luma + (b - luma) * SATURATION) * BRIGHTNESS),
                a,
            )

    img.save(path)


def main() -> int:
    paths = sys.argv[1:]
    if not paths:
        print(__doc__)
        return 2
    for path in paths:
        grim(path)
    print("grim_sprites: processed %d files" % len(paths))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
