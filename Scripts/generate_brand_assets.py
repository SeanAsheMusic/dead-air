#!/usr/bin/env python3
from pathlib import Path
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "Assets"
ICONSET = ASSET_DIR / "DeadAir.iconset"
MASTER = ASSET_DIR / "DeadAirLogoMark.png"
ICNS = ASSET_DIR / "AppIcon.icns"

SIZES = [
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


def main():
    if not MASTER.exists():
        raise SystemExit(f"Missing master icon: {MASTER}")

    ASSET_DIR.mkdir(exist_ok=True)
    ICONSET.mkdir(exist_ok=True)

    with Image.open(MASTER) as source:
        master = source.convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
        master.save(MASTER)
        for name, size in SIZES:
            master.resize((size, size), Image.Resampling.LANCZOS).save(ICONSET / name)

    subprocess.run(["/usr/bin/iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)], check=True)
    print(ICNS)


if __name__ == "__main__":
    main()
