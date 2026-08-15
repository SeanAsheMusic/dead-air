#!/usr/bin/env python3
"""Collect YouTube-hosted source imagery for every standard public upload.

The script uses only exact public images exposed by YouTube for each video:
- the current public thumbnail at the highest available resolution
- YouTube's three automatically selected player frames

It does not generate, synthesize, replace, or hallucinate any visual content.
"""

from __future__ import annotations

import json
import re
import shutil
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont, ImageOps

INVENTORY = Path("artifacts/channel-inventory/inventory.json")
OUT = Path("artifacts/thumbnail-sources")
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/126 Safari/537.36"

CURRENT_CANDIDATES = (
    "maxresdefault.jpg",
    "sddefault.jpg",
    "hqdefault.jpg",
    "mqdefault.jpg",
    "0.jpg",
)
AUTO_CANDIDATES = {
    1: ("maxres1.jpg", "sd1.jpg", "hq1.jpg", "mq1.jpg", "1.jpg"),
    2: ("maxres2.jpg", "sd2.jpg", "hq2.jpg", "mq2.jpg", "2.jpg"),
    3: ("maxres3.jpg", "sd3.jpg", "hq3.jpg", "mq3.jpg", "3.jpg"),
}


def safe_name(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("_")
    return value[:120] or "untitled"


def download(url: str, path: Path) -> tuple[bool, str | None]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Referer": "https://www.youtube.com/"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
    except (urllib.error.URLError, TimeoutError) as exc:
        return False, str(exc)

    if len(body) < 1000:
        return False, f"response too small: {len(body)} bytes"

    path.write_bytes(body)
    try:
        with Image.open(path) as image:
            image.verify()
        with Image.open(path) as image:
            width, height = image.size
            if width < 300 or height < 160:
                path.unlink(missing_ok=True)
                return False, f"image too small: {width}x{height}"
    except Exception as exc:  # noqa: BLE001
        path.unlink(missing_ok=True)
        return False, f"invalid image: {exc}"
    return True, None


def choose_best(video_id: str, names: tuple[str, ...], destination: Path, attempts: list[dict[str, Any]]) -> dict[str, Any] | None:
    temp_dir = destination.parent / "candidates"
    temp_dir.mkdir(parents=True, exist_ok=True)
    valid: list[tuple[int, int, int, Path, str]] = []

    for name in names:
        url = f"https://i.ytimg.com/vi/{video_id}/{name}"
        candidate = temp_dir / name
        ok, error = download(url, candidate)
        attempt: dict[str, Any] = {"url": url, "name": name, "ok": ok, "error": error}
        if ok:
            with Image.open(candidate) as image:
                width, height = image.size
            attempt.update({"width": width, "height": height, "bytes": candidate.stat().st_size})
            valid.append((width * height, width, height, candidate, name))
        attempts.append(attempt)
        time.sleep(0.06)

    if not valid:
        return None

    valid.sort(reverse=True, key=lambda item: (item[0], item[1], item[2]))
    _, width, height, source, selected_name = valid[0]
    shutil.copy2(source, destination)
    return {
        "selected_name": selected_name,
        "width": width,
        "height": height,
        "bytes": destination.stat().st_size,
        "path": str(destination),
    }


def fit_frame(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
    )
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def make_contact_sheet(video: dict[str, Any], folder: Path, selected: dict[str, Any]) -> None:
    canvas_w, canvas_h = 1600, 1050
    header_h = 150
    cell_w, cell_h = 760, 380
    gutter = 26
    canvas = Image.new("RGB", (canvas_w, canvas_h), "#111111")
    draw = ImageDraw.Draw(canvas)

    title = str(video.get("title") or video.get("video_id"))
    draw.text((36, 28), title, fill="white", font=font(42))
    draw.text((36, 88), str(video.get("video_id")), fill="#b7b7b7", font=font(25))

    slots = [
        ("CURRENT", folder / "current.jpg"),
        ("AUTO 1", folder / "auto1.jpg"),
        ("AUTO 2", folder / "auto2.jpg"),
        ("AUTO 3", folder / "auto3.jpg"),
    ]
    for index, (label, path) in enumerate(slots):
        row, col = divmod(index, 2)
        x = 26 + col * (cell_w + gutter)
        y = header_h + row * (cell_h + 55)
        if path.exists():
            with Image.open(path) as source:
                frame = fit_frame(source, (cell_w, cell_h))
            canvas.paste(frame, (x, y))
        else:
            draw.rectangle((x, y, x + cell_w, y + cell_h), fill="#242424")
            draw.text((x + 30, y + cell_h // 2 - 20), "SOURCE NOT AVAILABLE", fill="#aaaaaa", font=font(30))
        draw.rectangle((x, y, x + 150, y + 46), fill="#000000")
        draw.text((x + 14, y + 8), label, fill="white", font=font(25))

    canvas.save(folder / "contact-sheet.jpg", quality=92, optimize=True)


def make_overview(videos: list[dict[str, Any]]) -> None:
    per_page = 5
    page_w, row_h = 1760, 450
    for page_index in range(0, len(videos), per_page):
        batch = videos[page_index : page_index + per_page]
        canvas = Image.new("RGB", (page_w, 100 + row_h * len(batch)), "#0f0f0f")
        draw = ImageDraw.Draw(canvas)
        draw.text((30, 25), f"SOURCE REVIEW — STANDARD VIDEOS {page_index + 1}–{page_index + len(batch)}", fill="white", font=font(36))

        for local_index, video in enumerate(batch):
            row_y = 100 + local_index * row_h
            folder = OUT / "videos" / video["video_id"]
            draw.text((30, row_y + 15), f"{page_index + local_index + 1:02d}. {video['title']}", fill="white", font=font(25))
            draw.text((30, row_y + 55), video["video_id"], fill="#a9a9a9", font=font(19))
            for slot_index, filename in enumerate(("current.jpg", "auto1.jpg", "auto2.jpg", "auto3.jpg")):
                path = folder / filename
                x = 30 + slot_index * 430
                y = row_y + 92
                if path.exists():
                    with Image.open(path) as source:
                        frame = fit_frame(source, (410, 300))
                    canvas.paste(frame, (x, y))
                else:
                    draw.rectangle((x, y, x + 410, y + 300), fill="#292929")
                draw.text((x + 8, y + 8), filename.replace(".jpg", "").upper(), fill="white", font=font(17), stroke_width=2, stroke_fill="black")
        page_number = page_index // per_page + 1
        canvas.save(OUT / f"overview-{page_number:02d}.jpg", quality=91, optimize=True)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    payload = json.loads(INVENTORY.read_text(encoding="utf-8"))
    standard_videos = [video for video in payload["videos"] if "videos" in (video.get("source_tabs") or [])]

    results: list[dict[str, Any]] = []
    for index, video in enumerate(standard_videos, start=1):
        video_id = video["video_id"]
        folder = OUT / "videos" / video_id
        folder.mkdir(parents=True, exist_ok=True)
        attempts: list[dict[str, Any]] = []
        selected: dict[str, Any] = {}

        current = choose_best(video_id, CURRENT_CANDIDATES, folder / "current.jpg", attempts)
        selected["current"] = current
        for frame_index, candidates in AUTO_CANDIDATES.items():
            selected[f"auto{frame_index}"] = choose_best(
                video_id, candidates, folder / f"auto{frame_index}.jpg", attempts
            )

        video_manifest = {
            "index": index,
            "video_id": video_id,
            "title": video.get("title"),
            "url": video.get("url"),
            "selected": selected,
            "attempts": attempts,
        }
        (folder / "manifest.json").write_text(json.dumps(video_manifest, indent=2), encoding="utf-8")
        make_contact_sheet(video, folder, selected)
        results.append(video_manifest)
        print(f"[{index:02d}/{len(standard_videos)}] {video_id}: {video.get('title')}")

    manifest = {
        "source": "YouTube public thumbnail CDN",
        "standard_video_count": len(standard_videos),
        "videos": results,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    make_overview(standard_videos)

    complete = sum(
        1
        for item in results
        if all(item["selected"].get(slot) for slot in ("current", "auto1", "auto2", "auto3"))
    )
    print(json.dumps({"standard_video_count": len(results), "complete_four-source_sets": complete}))
    return 0 if len(results) == 40 else 2


if __name__ == "__main__":
    raise SystemExit(main())
