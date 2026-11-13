"""Generates morrow's launcher icons (Figma section 11, option A).

Option A: the sage sprout on cream. The sprout is the same 24-unit glyph as
the Figma frame "icon/sprout", drawn at half the icon's width.

Development-time only (needs Pillow: `pip install pillow`); nothing here ships
in the app. Run from the repository root:

    python tool/generate_launcher_icons.py

Writes:
- Android legacy launcher PNGs (mipmap-*/ic_launcher.png) for API 24-25.
  API 26+ uses the adaptive icon in mipmap-anydpi-v26, whose foreground is
  the vector drawable/ic_launcher_foreground.xml (kept in step by hand).
- iOS AppIcon PNGs listed in Assets.xcassets/AppIcon.appiconset/Contents.json
  (opaque, square: iOS applies its own mask).
- docs/store/icon-512.png for the Play listing.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

CREAM = (0xF7, 0xF4, 0xEC)  # MorrowColors.background
SAGE = (0x3D, 0x65, 0x52)  # MorrowColors.primary
STROKE = 1.6615  # in glyph units (Figma: 11.077 px at 160 px)

# The glyph, in a 24 x 24 box. Each path is a start point followed by line
# ("L", x, y) or cubic ("C", x1, y1, x2, y2, x, y) segments.
PATHS = [
    [(12, 21), ("L", 12, 12)],
    [(12, 12), ("C", 12, 8, 15, 6, 19, 6), ("C", 19, 10, 16, 12, 12, 12)],
    [(12, 14), ("C", 12, 11, 10, 9, 6, 9), ("C", 6, 12, 8, 14, 12, 14)],
]

ROOT = Path(__file__).resolve().parent.parent
SUPERSAMPLE = 8


def _points(path, steps=64):
    pts = [path[0]]
    for seg in path[1:]:
        x0, y0 = pts[-1]
        if seg[0] == "L":
            pts.append((seg[1], seg[2]))
            continue
        _, x1, y1, x2, y2, x3, y3 = seg
        for i in range(1, steps + 1):
            t = i / steps
            u = 1 - t
            pts.append((
                u**3 * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t**3 * x3,
                u**3 * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t**3 * y3,
            ))
    return pts


def render(size, glyph_fraction=0.5, radius_fraction=0.0, opaque=True):
    """Draws the icon at [size] px. The glyph's 24-unit box spans
    [glyph_fraction] of the width, centred. [radius_fraction] rounds the
    corners (0 = square, for platforms that mask the icon themselves)."""
    big = size * SUPERSAMPLE
    mode = "RGB" if opaque else "RGBA"
    image = Image.new(mode, (big, big), CREAM if opaque else (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if not opaque:
        draw.rounded_rectangle((0, 0, big - 1, big - 1),
                               radius=big * radius_fraction, fill=CREAM)
    unit = big * glyph_fraction / 24
    offset = (big - 24 * unit) / 2
    width = STROKE * unit
    for path in PATHS:
        pts = [(offset + x * unit, offset + y * unit) for x, y in _points(path)]
        # A round-capped, round-joined stroke: discs along the path, close
        # enough together (a tenth of the width) to leave a smooth edge.
        r = width / 2
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = max(1, math.ceil(math.hypot(x1 - x0, y1 - y0) / (width / 10)))
            for i in range(n + 1):
                x = x0 + (x1 - x0) * i / n
                y = y0 + (y1 - y0) * i / n
                draw.ellipse((x - r, y - r, x + r, y + r), fill=SAGE)
    return image.resize((size, size), Image.LANCZOS)


def main():
    android = ROOT / "android/app/src/main/res"
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                       "xxhdpi": 144, "xxxhdpi": 192}.items():
        # Legacy icons carry their own shape: the rounded square from Figma
        # (radius 22% of the width).
        render(px, radius_fraction=0.22, opaque=False).save(
            android / f"mipmap-{folder}/ic_launcher.png")

    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios / "Contents.json").read_text())
    for item in contents["images"]:
        name = item.get("filename")
        if not name:
            continue
        points = float(item["size"].split("x")[0])
        scale = int(item["scale"].rstrip("x"))
        render(round(points * scale)).save(ios / name)

    store = ROOT / "docs/store"
    store.mkdir(parents=True, exist_ok=True)
    render(512).save(store / "icon-512.png")


if __name__ == "__main__":
    main()
