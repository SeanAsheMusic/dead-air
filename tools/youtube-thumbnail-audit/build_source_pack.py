#!/usr/bin/env python3
"""Build an exact-frame review pack for every public channel upload.

All candidate imagery is fetched from YouTube's numbered thumbnail endpoints
(maxres1/2/3), which are source frames generated directly from each uploaded
video. Shorts also include YouTube's selected portrait frame (oar2). No image
is synthesized or reconstructed.
"""

from __future__ import annotations

import csv
import io
import json
import math
import textwrap
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

INVENTORY_PATH = Path("artifacts/channel-inventory/inventory.json")
OUT = Path("artifacts/youtube-source-pack")
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
)


def load_font(size: int, *, bold: bool = False) -> ImageFont.ImageFont:
    candidates = (
        "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf" if bold else "/usr/share/fonts/opentype/inter/InterDisplay-Medium.otf",
        "/usr/share/fonts/truetype/lato/Lato-Heavy.ttf" if bold else "/usr/share/fonts/truetype/lato/Lato-Medium.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    )
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def fetch_image(url: str, attempts: int = 4) -> tuple[Image.Image | None, bytes | None, str | None]:
    last_error: str | None = None
    for attempt in range(1, attempts + 1):
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = response.read()
            image = Image.open(io.BytesIO(data))
            image.load()
            return image.convert("RGB"), data, None
        except urllib.error.HTTPError as exc:
            last_error = f"HTTP {exc.code}"
            if exc.code == 404:
                break
        except Exception as exc:  # noqa: BLE001
            last_error = repr(exc)
        time.sleep(attempt * 0.6)
    return None, None, last_error


def fetch_numbered_frame(video_id: str, number: int) -> tuple[Image.Image | None, bytes | None, str, str | None]:
    variants = (
        f"maxres{number}.jpg",
        f"sd{number}.jpg",
        f"hq{number}.jpg",
    )
    for variant in variants:
        url = f"https://i.ytimg.com/vi/{video_id}/{variant}"
        image, data, error = fetch_image(url)
        if image and data and image.width >= 480 and image.height >= 270:
            return image, data, variant, None
    return None, None, variants[-1], error if "error" in locals() else "unavailable"


def letterbox(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    background = ImageOps.fit(image, size, Image.Resampling.LANCZOS)
    background = background.filter(ImageFilter.GaussianBlur(18))
    background = ImageEnhance.Brightness(background).enhance(0.58)
    foreground = ImageOps.contain(image, size, Image.Resampling.LANCZOS)
    x = (size[0] - foreground.width) // 2
    y = (size[1] - foreground.height) // 2
    background.paste(foreground, (x, y))
    return background


def frame_tile(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    if abs((image.width / image.height) - (size[0] / size[1])) < 0.05:
        return ImageOps.fit(image, size, Image.Resampling.LANCZOS)
    return letterbox(image, size)


def wrap_title(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, width: int, max_lines: int = 3) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = f"{current} {word}".strip()
        if draw.textbbox((0, 0), trial, font=font)[2] <= width or not current:
            current = trial
        else:
            lines.append(current)
            current = word
            if len(lines) == max_lines - 1:
                break
    remaining_start = sum(len(line.split()) for line in lines)
    if len(lines) == max_lines - 1 and remaining_start < len(words):
        rest = " ".join(words[remaining_start:])
        while draw.textbbox((0, 0), rest + "…", font=font)[2] > width and len(rest) > 3:
            rest = rest[:-1]
        current = rest.rstrip() + "…"
    if current:
        lines.append(current)
    return lines[:max_lines]


def save_overview(
    videos: list[dict[str, Any]],
    sheet_index: int,
    kind: str,
    destination: Path,
) -> None:
    label_w = 470
    tile_w, tile_h = 360, 203
    gap = 16
    header_h = 82
    row_h = 246
    columns = 4 if kind == "shorts" else 3
    canvas_w = label_w + columns * tile_w + (columns + 1) * gap
    canvas_h = header_h + len(videos) * row_h
    canvas = Image.new("RGB", (canvas_w, canvas_h), "#111214")
    draw = ImageDraw.Draw(canvas)
    header_font = load_font(34, bold=True)
    title_font = load_font(27, bold=True)
    meta_font = load_font(21)
    frame_font = load_font(20, bold=True)

    draw.text((24, 20), f"SEAN ASHE — {kind.upper()} SOURCE FRAMES — BOARD {sheet_index:02d}", font=header_font, fill="#F4F4F2")

    for row_index, video in enumerate(videos):
        y = header_h + row_index * row_h
        if row_index % 2:
            draw.rectangle((0, y, canvas_w, y + row_h), fill="#181A1D")
        draw.text((24, y + 22), f"{video['index']:03d}  {video['video_id']}", font=meta_font, fill="#AEB3BA")
        title_lines = wrap_title(draw, video["title"], title_font, label_w - 50, max_lines=4)
        ty = y + 58
        for line in title_lines:
            draw.text((24, ty), line, font=title_font, fill="#F4F4F2")
            ty += 34
        draw.text((24, y + row_h - 36), f"Views: {video.get('view_count') or 0:,}", font=meta_font, fill="#858C95")

        candidate_paths: list[tuple[str, Path | None]] = [
            ("FRAME 1", video.get("frame_1_path")),
            ("FRAME 2", video.get("frame_2_path")),
            ("FRAME 3", video.get("frame_3_path")),
        ]
        if kind == "shorts":
            candidate_paths.append(("CURRENT", video.get("portrait_path")))

        for column_index, (label, path) in enumerate(candidate_paths):
            x = label_w + gap + column_index * (tile_w + gap)
            if path and Path(path).exists():
                image = Image.open(path).convert("RGB")
                tile = frame_tile(image, (tile_w, tile_h))
                canvas.paste(tile, (x, y + 18))
            else:
                draw.rectangle((x, y + 18, x + tile_w, y + 18 + tile_h), fill="#2A2D32")
                draw.line((x, y + 18, x + tile_w, y + 18 + tile_h), fill="#555B64", width=3)
                draw.line((x + tile_w, y + 18, x, y + 18 + tile_h), fill="#555B64", width=3)
            draw.rectangle((x, y + 18 + tile_h - 34, x + tile_w, y + 18 + tile_h), fill="#000000")
            draw.text((x + 10, y + 18 + tile_h - 29), label, font=frame_font, fill="#FFFFFF")

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, quality=92, subsampling=0, optimize=True)


def main() -> int:
    if not INVENTORY_PATH.exists():
        raise FileNotFoundError(f"Inventory missing: {INVENTORY_PATH}")

    inventory = json.loads(INVENTORY_PATH.read_text(encoding="utf-8"))
    videos = inventory.get("videos") or []
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "longform").mkdir(exist_ok=True)
    (OUT / "shorts").mkdir(exist_ok=True)
    (OUT / "overview-longform").mkdir(exist_ok=True)
    (OUT / "overview-shorts").mkdir(exist_ok=True)

    records: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []

    for index, source in enumerate(videos, start=1):
        source_tabs = source.get("source_tabs") or []
        kind = "shorts" if "shorts" in source_tabs else "longform"
        video_id = str(source["video_id"])
        video_dir = OUT / kind / video_id
        video_dir.mkdir(parents=True, exist_ok=True)

        record: dict[str, Any] = {
            "index": index,
            "video_id": video_id,
            "title": str(source.get("title") or video_id),
            "kind": kind,
            "view_count": int(source.get("view_count") or 0),
            "duration_seconds": source.get("duration_seconds"),
            "url": source.get("url"),
        }

        for frame_number in (1, 2, 3):
            image, data, variant, error = fetch_numbered_frame(video_id, frame_number)
            key = f"frame_{frame_number}"
            if image and data:
                path = video_dir / f"{key}.jpg"
                path.write_bytes(data)
                record[f"{key}_path"] = str(path)
                record[f"{key}_variant"] = variant
                record[f"{key}_width"] = image.width
                record[f"{key}_height"] = image.height
                record[f"{key}_source_url"] = f"https://i.ytimg.com/vi/{video_id}/{variant}"
            else:
                record[f"{key}_path"] = None
                errors.append({"video_id": video_id, "asset": key, "error": error or "unavailable"})

        if kind == "shorts":
            portrait_url = f"https://i.ytimg.com/vi/{video_id}/oar2.jpg"
            portrait, portrait_data, portrait_error = fetch_image(portrait_url)
            if portrait and portrait_data and portrait.height > portrait.width:
                portrait_path = video_dir / "current_portrait.jpg"
                portrait_path.write_bytes(portrait_data)
                record["portrait_path"] = str(portrait_path)
                record["portrait_width"] = portrait.width
                record["portrait_height"] = portrait.height
                record["portrait_source_url"] = portrait_url
            else:
                record["portrait_path"] = None
                errors.append({"video_id": video_id, "asset": "portrait", "error": portrait_error or "unavailable"})
        else:
            record["portrait_path"] = None

        records.append(record)
        time.sleep(0.08)

    longform = [record for record in records if record["kind"] == "longform"]
    shorts = [record for record in records if record["kind"] == "shorts"]

    for kind, collection, batch_size in (
        ("longform", longform, 6),
        ("shorts", shorts, 7),
    ):
        for sheet_index, start in enumerate(range(0, len(collection), batch_size), start=1):
            batch = collection[start : start + batch_size]
            save_overview(
                batch,
                sheet_index,
                kind,
                OUT / f"overview-{kind}" / f"board-{sheet_index:02d}.jpg",
            )

    manifest = {
        "channel_root": inventory.get("channel_root"),
        "video_count": len(records),
        "longform_count": len(longform),
        "shorts_count": len(shorts),
        "source_policy": (
            "Numbered maxres/sd/hq frames from i.ytimg.com; Shorts portrait frame from oar2. "
            "No generated imagery."
        ),
        "errors": errors,
        "videos": records,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    fields = (
        "index",
        "video_id",
        "title",
        "kind",
        "view_count",
        "duration_seconds",
        "url",
        "frame_1_variant",
        "frame_1_path",
        "frame_2_variant",
        "frame_2_path",
        "frame_3_variant",
        "frame_3_path",
        "portrait_path",
    )
    with (OUT / "manifest.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)

    summary = {
        "video_count": len(records),
        "longform_count": len(longform),
        "shorts_count": len(shorts),
        "frame_failures": len(errors),
        "longform_boards": math.ceil(len(longform) / 6),
        "shorts_boards": math.ceil(len(shorts) / 7),
    }
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary))
    return 0 if len(records) == 109 and not [error for error in errors if error["asset"].startswith("frame_")] else 2


if __name__ == "__main__":
    raise SystemExit(main())
