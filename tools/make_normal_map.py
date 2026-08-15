#!/usr/bin/env python3
"""Derives a normal map from a ship plate's luminance.

    tools/make_normal_map.py assets/ship/hull_plate.png

Godot's 2D lights need a normal map to do anything interesting to a flat
image. Without one a PointLight2D just brightens a region uniformly, which
looks like a torch shone at a photograph. With one, the plating catches the
light edge-on and the hull reads as relief.

The plate is a rendered image, not a height field, so treating luminance as
height is an approximation. It works here because the art is lit from directly
overhead by request: bright pixels really are the raised plating, dark pixels
really are the recesses between it.

Committed rather than run at import time, because Godot has no image
processing in-engine and the output is a build input, not a runtime asset.
"""

import sys
from PIL import Image, ImageFilter

STRENGTH = 2.6
BLUR = 1.2


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    src = sys.argv[1]
    dst = src.rsplit(".", 1)[0] + "_normal.png"

    img = Image.open(src).convert("RGB")
    w, h = img.size

    # Slight blur first: the plate has single-pixel speckle that would otherwise
    # become normal-map noise and make the whole hull sparkle under a light.
    height = img.convert("L").filter(ImageFilter.GaussianBlur(BLUR))
    hp = height.load()

    out = Image.new("RGB", (w, h))
    op = out.load()

    for y in range(h):
        y0 = y - 1 if y > 0 else 0
        y1 = y + 1 if y < h - 1 else h - 1
        for x in range(w):
            x0 = x - 1 if x > 0 else 0
            x1 = x + 1 if x < w - 1 else w - 1

            dx = (hp[x1, y] - hp[x0, y]) / 255.0 * STRENGTH
            dy = (hp[x, y1] - hp[x, y0]) / 255.0 * STRENGTH

            # Normalise (-dx, -dy, 1) and pack into 0..255.
            nz = 1.0
            length = (dx * dx + dy * dy + nz * nz) ** 0.5
            op[x, y] = (
                int((-dx / length * 0.5 + 0.5) * 255.0),
                int((-dy / length * 0.5 + 0.5) * 255.0),
                int((nz / length * 0.5 + 0.5) * 255.0),
            )

    out.save(dst)
    print("wrote %s  %dx%d" % (dst, w, h))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
