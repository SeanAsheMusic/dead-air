#!/usr/bin/env python3
"""Probe YouTube's public auto-generated frame thumbnails.

The numbered thumbnail variants are frames selected from the uploaded video by
YouTube. They are not synthetic images. This probe records which resolutions
are available and creates a contact sheet for visual verification.
"""

from __future__ import annotations

import io
import json
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

VIDEO_IDS = (
    "aj6xPlCG0sA",  # standard horizontal upload
    "vETs-koEJro",  # Short
    "eDqL7vfFWw0",  # older music video
)
VARIANTS = (
    "maxres1.jpg",
    "maxres2.jpg",
    "maxres3.jpg",
    "sd1.jpg",
    "sd2.jpg",
    "sd3.jpg",
    "hq1.jpg",
    "hq2.jpg",
    "hq3.jpg",
    "mq1.jpg",
    "mq2.jpg",
    "mq3.jpg",
    "1.jpg",
    "2.jpg",
    "3.jpg",
    "0.jpg",
    "sddefault.jpg",
    "hqdefault.jpg",
    "maxresdefault.jpg",
    "oar2.jpg",
)
OUT = Path("artifacts/cdn-frame-probe")


def fetch(url: str) -> tuple[bytes | None, str | None]:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/140.0.0.0 Safari/537.36"
            )
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read(), None
    except urllib.error.HTTPError as exc:
        return None, f"HTTP {exc.code}"
    except Exception as exc:  # noqa: BLE001 - diagnostics are the point of the probe
        return None, repr(exc)


def font(size: int) -> ImageFont.ImageFont:
    candidates = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
    )
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def contact_sheet(video_id: str, entries: list[dict[str, object]]) -> None:
    available = [entry for entry in entries if entry.get("path")]
    if not available:
        return

    tile_w, tile_h = 480, 320
    label_h = 42
    columns = 3
    rows = (len(available) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * tile_w, rows * (tile_h + label_h)), "#111111")
    draw = ImageDraw.Draw(sheet)
    label_font = font(22)

    for index, entry in enumerate(available):
        row, column = divmod(index, columns)
        x = column * tile_w
        y = row * (tile_h + label_h)
        image = Image.open(str(entry["path"])).convert("RGB")
        fitted = ImageOps.contain(image, (tile_w, tile_h), Image.Resampling.LANCZOS)
        background = ImageOps.fit(image, (tile_w, tile_h), Image.Resampling.LANCZOS)
        background = background.filter(__import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(14))
        sheet.paste(background, (x, y))
        px = x + (tile_w - fitted.width) // 2
        py = y + (tile_h - fitted.height) // 2
        sheet.paste(fitted, (px, py))
        label = f"{entry['variant']}  {entry['width']}×{entry['height']}"
        draw.rectangle((x, y + tile_h, x + tile_w, y + tile_h + label_h), fill="#111111")
        draw.text((x + 10, y + tile_h + 8), label, font=label_font, fill="white")

    sheet.save(OUT / f"{video_id}.contact-sheet.jpg", quality=92, subsampling=0)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    report: dict[str, object] = {"videos": []}
    exact_numbered_successes = 0

    for video_id in VIDEO_IDS:
        video_dir = OUT / video_id
        video_dir.mkdir(parents=True, exist_ok=True)
        entries: list[dict[str, object]] = []

        for variant in VARIANTS:
            url = f"https://i.ytimg.com/vi/{video_id}/{variant}"
            data, error = fetch(url)
            entry: dict[str, object] = {
                "variant": variant,
                "url": url,
                "error": error,
                "available": False,
            }
            if data:
                try:
                    image = Image.open(io.BytesIO(data))
                    image.load()
                except Exception as exc:  # noqa: BLE001
                    entry["error"] = f"invalid image: {exc!r}"
                else:
                    path = video_dir / variant
                    path.write_bytes(data)
                    entry.update(
                        {
                            "available": True,
                            "width": image.width,
                            "height": image.height,
                            "mode": image.mode,
                            "size_bytes": len(data),
                            "path": str(path),
                        }
                    )
                    if variant.startswith(("maxres1", "maxres2", "maxres3", "sd1", "sd2", "sd3", "hq1", "hq2", "hq3")):
                        exact_numbered_successes += 1
            entries.append(entry)

        contact_sheet(video_id, entries)
        report["videos"].append({"video_id": video_id, "variants": entries})

    report["numbered_exact_frame_successes"] = exact_numbered_successes
    (OUT / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"numbered_exact_frame_successes": exact_numbered_successes}))
    return 0 if exact_numbered_successes else 2


if __name__ == "__main__":
    raise SystemExit(main())
