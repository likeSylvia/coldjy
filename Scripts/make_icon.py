#!/usr/bin/env python3
"""Generate a 1024x1024 AppIcon for cold tools.

Design: A rounded-square gradient tile with a minimalist snowflake + leaf
motif suggesting calm/cold (name: cold tools). No text inside the icon.
Runs in CI without external image assets; only depends on Pillow.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "ColdTools", "Assets.xcassets",
                   "AppIcon.appiconset", "AppIcon-1024.png")


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_rounded_square(size, radius, top_color, bottom_color):
    base = Image.new("RGB", (size, size), bottom_color)
    for y in range(size):
        t = y / (size - 1)
        base.paste(lerp(top_color, bottom_color, t), [0, y, size, y + 1])

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size, size], radius=radius, fill=255)

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask)
    return out


def draw_snowflake(draw, cx, cy, size, color, line_width):
    arms = 6
    for i in range(arms):
        angle = (math.pi * 2 / arms) * i
        ex = cx + math.cos(angle) * size
        ey = cy + math.sin(angle) * size
        draw.line([(cx, cy), (ex, ey)], fill=color, width=line_width)
        # small side branches
        for sign in (-1, 1):
            ba = angle + sign * math.radians(35)
            bx1 = cx + math.cos(angle) * size * 0.55
            by1 = cy + math.sin(angle) * size * 0.55
            bx2 = bx1 + math.cos(ba) * size * 0.22
            by2 = by1 + math.sin(ba) * size * 0.22
            draw.line([(bx1, by1), (bx2, by2)], fill=color, width=max(2, line_width - 6))


def main():
    top = (30, 60, 90)       # midnight navy
    bottom = (12, 24, 42)    # darker
    icon = gradient_rounded_square(SIZE, radius=int(SIZE * 0.22),
                                   top_color=top, bottom_color=bottom)

    # Soft highlight blob
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([SIZE * 0.1, -SIZE * 0.15, SIZE * 0.9, SIZE * 0.55],
               fill=(120, 190, 255, 55))
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    icon = Image.alpha_composite(icon, glow)

    # Accent ring
    ring = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    cx = cy = SIZE // 2
    r = int(SIZE * 0.30)
    rd.ellipse([cx - r, cy - r, cx + r, cy + r],
               outline=(180, 220, 255, 220), width=10)
    icon = Image.alpha_composite(icon, ring)

    # Snowflake
    snow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(snow)
    draw_snowflake(sd, cx, cy, int(SIZE * 0.22),
                   color=(240, 250, 255, 240), line_width=18)
    # Center dot
    d = int(SIZE * 0.04)
    sd.ellipse([cx - d, cy - d, cx + d, cy + d], fill=(255, 255, 255, 255))
    icon = Image.alpha_composite(icon, snow)

    # Subtle vignette
    vignette = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    vd.rounded_rectangle([0, 0, SIZE, SIZE], radius=int(SIZE * 0.22),
                         outline=(0, 0, 0, 60), width=4)
    icon = Image.alpha_composite(icon, vignette)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.convert("RGB").save(OUT, format="PNG")
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
