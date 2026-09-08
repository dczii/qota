#!/usr/bin/env python3
"""Draw the Qota Dock icon: three quota bars plus a check badge."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
BG = (26, 29, 36, 255)
TRACK = (54, 59, 70, 255)
TEAL = (45, 201, 176, 255)
AMBER = (240, 163, 58, 255)
CORAL = (232, 108, 116, 255)
BADGE_FILL = (20, 46, 44, 255)


def _circle(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill) -> None:
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def _capsule(draw: ImageDraw.ImageDraw, x: float, y: float, w: float, h: float, fill) -> None:
    draw.rounded_rectangle((x, y, x + w, y + h), radius=h / 2, fill=fill)


def _draw_mark(layer: Image.Image, alpha: int) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")
    fill = (*TEAL[:3], alpha)
    track = (*TRACK[:3], alpha)
    badge = (*BADGE_FILL[:3], alpha)
    amber = (*AMBER[:3], alpha)
    coral = (*CORAL[:3], alpha)

    bar_h = 96
    gap = 42
    bar_w = 548
    left = 118
    top = (SIZE - (bar_h * 3 + gap * 2)) / 2
    fills = ((TEAL[:3] + (alpha,), 0.70), (amber, 0.46), (coral, 0.84))

    for i, (color, used) in enumerate(fills):
        y = top + i * (bar_h + gap)
        _capsule(draw, left, y, bar_w, bar_h, track)
        _capsule(draw, left, y, max(bar_h, bar_w * used), bar_h, color)

    cx, cy, r = 778, 548, 168
    _circle(draw, cx, cy, r, fill)
    _circle(draw, cx, cy, r - 26, badge)

    # Thick rounded check
    check = [
        (cx - 78, cy + 8),
        (cx - 18, cy + 68),
        (cx + 86, cy - 58),
    ]
    draw.line(check, fill=fill, width=46, joint="curve")
    for x, y in check:
        _circle(draw, x, y, 23, fill)


def render() -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), BG)

    silhouette = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _draw_mark(silhouette, 255)
    alpha = silhouette.split()[-1]
    dark = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    dark.putalpha(alpha.point(lambda a: int(a * 0.45)))
    dark = dark.filter(ImageFilter.GaussianBlur(22))
    canvas.alpha_composite(dark, (0, 18))

    mark = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _draw_mark(mark, 255)
    canvas.alpha_composite(mark)
    return canvas


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    dest = root / "Qota" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    image = render().convert("RGB")
    image.save(dest, "PNG", optimize=True)
    print(f"wrote {dest} ({dest.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
