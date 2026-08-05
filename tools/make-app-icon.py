#!/usr/bin/env python3
"""
Renders the Exhale app icon from the same phyllotaxis maths as LogoGeometry.swift,
so the icon can never drift from the mark drawn inside the app.

    python tools/make-app-icon.py

Writes Exhale/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""
import colorsys
import math
import pathlib

GOLDEN = 2.399963
# Must equal LogoGeometry.dotCount. These drifted apart once — the in-app mark
# was made to thin out at small sizes and the icon was not — and the result was
# a home-screen icon that was visibly a different logo from the one in the
# header. See tools/lint-logo.py, which now fails the build if they diverge.
DOTS = 55
SIZE = 1024
SUPERSAMPLE = 4          # render big, downsample — Pillow has no AA for ellipses
MARK_FRACTION = 0.72     # the mark occupies ~72% of the tile
# Icon art is downsampled to 40-60px on a home screen, where LogoGeometry's
# native dot size turns the mark to mush. Verified by rendering at 180/87/60/
# 40/29: at 1.0 the ember core is gone by 40px; at 1.35 the rosette still reads
# at 29px. This is a rendering parameter for the icon only — the in-app mark is
# drawn natively at 26pt and needs no such compensation.
DOT_SCALE = 1.35
TILE_BG = (0x0C, 0x22, 0x25)

from PIL import Image, ImageDraw


def hsl_to_rgb(h_deg, s, l):
    r, g, b = colorsys.hls_to_rgb((h_deg % 360) / 360.0, l, s)
    return (round(r * 255), round(g * 255), round(b * 255))


def render(size=SIZE):
    big = size * SUPERSAMPLE
    img = Image.new("RGB", (big, big), TILE_BG)
    draw = ImageDraw.Draw(img)

    box = big * MARK_FRACTION
    scale = box / 26.0            # LogoGeometry is authored in a 26pt box
    centre = big / 2.0
    hole = 3.1 * scale
    max_r = 12.4 * scale

    for i in range(DOTS):
        t = i / (DOTS - 1)
        radius = hole + (max_r - hole) * math.sqrt(t)
        angle = i * GOLDEN - 1.6
        diameter = (1.3 + t * 1.2) * scale * DOT_SCALE

        x = centre + radius * math.cos(angle)
        y = centre + radius * math.sin(angle)
        colour = hsl_to_rgb(18 + t * 154, (85 - t * 25) / 100, (54 + t * 8) / 100)

        draw.ellipse(
            [x - diameter / 2, y - diameter / 2, x + diameter / 2, y + diameter / 2],
            fill=colour,
        )

    return img.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    out = pathlib.Path("Exhale/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    icon = render()
    # App Store icons must be opaque with no alpha channel, or upload is rejected.
    icon.convert("RGB").save(out, "PNG")

    check = Image.open(out)
    print(f"wrote {out}")
    print(f"  size={check.size} mode={check.mode} alpha={'A' in check.mode}")
    assert check.size == (1024, 1024), "App Store requires exactly 1024x1024"
    assert check.mode == "RGB", "App Store rejects icons with an alpha channel"
    print("  OK — 1024x1024, opaque, no alpha")
