#!/usr/bin/env python3
from pathlib import Path
import math
import subprocess
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "Assets"
ICONSET = ASSET_DIR / "DeadAir.iconset"


def lerp(a, b, t):
    return int(a + (b - a) * t)


def rounded_gradient(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    base = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    px = base.load()
    top = (40, 48, 51)
    bottom = (12, 16, 18)
    accent = (27, 124, 115)
    for y in range(size):
        for x in range(size):
            ty = y / max(1, size - 1)
            tx = x / max(1, size - 1)
            glow = max(0, 1 - math.hypot(tx - 0.22, ty - 0.18) * 1.55)
            r = lerp(top[0], bottom[0], ty)
            g = lerp(top[1], bottom[1], ty)
            b = lerp(top[2], bottom[2], ty)
            r = lerp(r, accent[0], glow * 0.42)
            g = lerp(g, accent[1], glow * 0.42)
            b = lerp(b, accent[2], glow * 0.42)
            px[x, y] = (r, g, b, 255)

    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    radius = int(size * 0.225)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    img.alpha_composite(base)
    img.putalpha(mask)
    return img


def draw_mark(size, icon=True):
    img = rounded_gradient(size)
    draw = ImageDraw.Draw(img)

    pad = int(size * 0.16)
    stroke = max(4, int(size * 0.055))
    center = size // 2
    left = pad
    right = size - pad
    gap_w = int(size * 0.085)
    gap_left = center - gap_w // 2
    gap_right = center + gap_w // 2

    # Soft signal glow, intentionally simple so the mark stays legible in the toolbar.
    glow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow = ImageDraw.Draw(glow_layer)
    points = []
    for i in range(180):
        t = i / 179
        x = left + (right - left) * t
        envelope = 0.34 + 0.66 * math.sin(t * math.pi)
        amp = size * 0.19 * envelope
        y = center + math.sin(t * math.pi * 5.0) * amp
        if not gap_left < x < gap_right:
            points.append((x, y))
        else:
            if len(points) > 1:
                glow.line(points, fill=(64, 222, 197, 115), width=stroke * 3, joint="curve")
            points = []
    if len(points) > 1:
        glow.line(points, fill=(64, 222, 197, 115), width=stroke * 3, joint="curve")
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=stroke * 1.2))
    img.alpha_composite(glow_layer)

    # Primary waveform.
    points = []
    for i in range(280):
        t = i / 279
        x = left + (right - left) * t
        envelope = 0.34 + 0.66 * math.sin(t * math.pi)
        amp = size * 0.19 * envelope
        y = center + math.sin(t * math.pi * 5.0) * amp
        if not gap_left < x < gap_right:
            points.append((x, y))
        else:
            if len(points) > 1:
                draw.line(points, fill=(236, 255, 249, 255), width=stroke, joint="curve")
                draw.line(points, fill=(76, 229, 198, 245), width=max(2, stroke // 3), joint="curve")
            points = []
    if len(points) > 1:
        draw.line(points, fill=(236, 255, 249, 255), width=stroke, joint="curve")
        draw.line(points, fill=(76, 229, 198, 245), width=max(2, stroke // 3), joint="curve")

    # Dead-air gap marker.
    marker_w = int(size * 0.095)
    marker_h = int(size * 0.50)
    marker_x0 = center - marker_w // 2
    marker_y0 = center - marker_h // 2
    marker_x1 = center + marker_w // 2
    marker_y1 = center + marker_h // 2
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((marker_x0, marker_y0, marker_x1, marker_y1), radius=int(size * 0.030), fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=int(size * 0.018)))
    img.alpha_composite(shadow)
    draw.rounded_rectangle((marker_x0, marker_y0, marker_x1, marker_y1), radius=int(size * 0.030), fill=(255, 112, 102, 255))
    draw.rounded_rectangle((marker_x0 + stroke, marker_y0 + stroke, marker_x1 - stroke, marker_y1 - stroke), radius=int(size * 0.016), outline=(255, 234, 216, 190), width=max(1, stroke // 5))

    # Bevel highlight.
    draw.rounded_rectangle((2, 2, size - 3, size - 3), radius=int(size * 0.225), outline=(255, 255, 255, 32), width=max(1, int(size * 0.01)))
    return img


def save_iconset():
    ASSET_DIR.mkdir(exist_ok=True)
    ICONSET.mkdir(exist_ok=True)
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    master = draw_mark(1024)
    master.save(ASSET_DIR / "DeadAirLogoMark.png")
    for name, size in sizes:
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(ICONSET / name)
    subprocess.run(["/usr/bin/iconutil", "-c", "icns", str(ICONSET), "-o", str(ASSET_DIR / "AppIcon.icns")], check=True)


if __name__ == "__main__":
    save_iconset()
    print(ASSET_DIR / "AppIcon.icns")
