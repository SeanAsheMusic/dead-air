#!/usr/bin/env python3
"""Inventory Sean Ashe's public YouTube uploads without changing the channel."""

from __future__ import annotations

import csv
import json
import re
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SEED_VIDEO_IDS = (
    "GJ_7sW8m2mc",  # The MOST important guitar technique
    "BRlpG5_1H7Y",  # Luminescence
    "PVQc5LyfNGU",  # NAMM 2016 performance
)
FALLBACK_ROOTS = (
    "https://www.youtube.com/user/SeanAsheOfficial",
    "https://www.youtube.com/c/SeanAsheOfficial",
    "https://www.youtube.com/SeanAsheOfficial",
    "https://www.youtube.com/@seanasheofficial",
)
TABS = ("videos", "shorts", "streams")
OUT = Path("artifacts/channel-inventory")


def run_json(url: str, *, flat_playlist: bool) -> tuple[dict[str, Any] | None, str]:
    command = ["yt-dlp"]
    if flat_playlist:
        command.extend(["--flat-playlist", "--playlist-end", "500", "--ignore-errors"])
    else:
        command.append("--skip-download")
    command.extend(
        [
            "--dump-single-json",
            "--no-warnings",
            "--quiet",
            "--js-runtimes",
            "node",
            url,
        ]
    )
    result = subprocess.run(command, text=True, capture_output=True, check=False, timeout=900)
    diagnostic = (
        f"URL: {url}\nCOMMAND: {' '.join(command)}\nEXIT: {result.returncode}"
        f"\n\nSTDERR\n{result.stderr}\n\nSTDOUT\n{result.stdout}"
    )
    if result.returncode != 0 or not result.stdout.strip() or result.stdout.strip() == "null":
        return None, diagnostic
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None, diagnostic
    return payload if isinstance(payload, dict) else None, diagnostic


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("_")


def resolve_channel_root() -> tuple[str | None, dict[str, Any]]:
    candidates: list[dict[str, str | None]] = []

    for seed_id in SEED_VIDEO_IDS:
        url = f"https://www.youtube.com/watch?v={seed_id}"
        payload, diagnostic = run_json(url, flat_playlist=False)
        (OUT / f"resolve-seed-{seed_id}.log.txt").write_text(diagnostic, encoding="utf-8")
        if not payload:
            continue

        channel_id = payload.get("channel_id")
        channel_name = payload.get("channel") or payload.get("uploader")
        channel_url = payload.get("channel_url") or payload.get("uploader_url")
        if isinstance(channel_id, str) and channel_id.startswith("UC"):
            canonical_url = f"https://www.youtube.com/channel/{channel_id}"
        elif isinstance(channel_url, str) and channel_url:
            canonical_url = channel_url.rstrip("/")
        else:
            canonical_url = None

        candidates.append(
            {
                "seed_video_id": seed_id,
                "channel_id": channel_id if isinstance(channel_id, str) else None,
                "channel_name": channel_name if isinstance(channel_name, str) else None,
                "channel_url": canonical_url,
            }
        )

    matching = [
        item
        for item in candidates
        if "sean ashe" in str(item.get("channel_name") or "").lower()
        and item.get("channel_url")
    ]
    pool = matching or [item for item in candidates if item.get("channel_url")]
    if pool:
        frequencies = Counter(str(item["channel_url"]) for item in pool)
        selected_url, _ = frequencies.most_common(1)[0]
        selected = next(item for item in pool if item["channel_url"] == selected_url)
        return selected_url, {"method": "seed-video", "selected": selected, "candidates": candidates}

    for root in FALLBACK_ROOTS:
        payload, diagnostic = run_json(f"{root}/videos", flat_playlist=True)
        (OUT / f"resolve-root-{safe_name(root)}.log.txt").write_text(diagnostic, encoding="utf-8")
        entries = payload.get("entries") if payload else None
        if isinstance(entries, list) and entries:
            return root, {"method": "fallback-root", "selected": {"channel_url": root}, "candidates": candidates}

    return None, {"method": "failed", "selected": None, "candidates": candidates}


def extract_tab(channel_root: str, tab: str) -> tuple[list[dict[str, Any]], str]:
    payload, diagnostic = run_json(f"{channel_root.rstrip('/')}/{tab}", flat_playlist=True)
    entries = payload.get("entries") if payload else None
    if not isinstance(entries, list):
        return [], diagnostic
    return [entry for entry in entries if isinstance(entry, dict)], diagnostic


def video_id(entry: dict[str, Any]) -> str | None:
    candidate = entry.get("id") or entry.get("url")
    return candidate if isinstance(candidate, str) and len(candidate) == 11 else None


def best_thumbnail(entry: dict[str, Any]) -> str | None:
    if isinstance(entry.get("thumbnail"), str):
        return entry["thumbnail"]
    thumbs = [item for item in (entry.get("thumbnails") or []) if isinstance(item, dict) and item.get("url")]
    if not thumbs:
        return None
    thumbs.sort(key=lambda item: int(item.get("width") or 0) * int(item.get("height") or 0))
    return str(thumbs[-1]["url"])


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    channel_root, resolution = resolve_channel_root()
    (OUT / "channel-resolution.json").write_text(
        json.dumps(resolution, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    merged: dict[str, dict[str, Any]] = {}
    tab_counts: dict[str, int] = {tab: 0 for tab in TABS}

    if channel_root:
        for tab in TABS:
            entries, diagnostic = extract_tab(channel_root, tab)
            (OUT / f"{tab}.log.txt").write_text(diagnostic, encoding="utf-8")
            tab_counts[tab] = len(entries)
            for entry in entries:
                item_id = video_id(entry)
                if not item_id:
                    continue
                item = merged.setdefault(
                    item_id,
                    {
                        "video_id": item_id,
                        "title": str(entry.get("title") or item_id),
                        "url": f"https://www.youtube.com/watch?v={item_id}",
                        "source_tabs": [],
                        "duration_seconds": entry.get("duration"),
                        "view_count": entry.get("view_count"),
                        "timestamp": entry.get("timestamp"),
                        "upload_date": entry.get("upload_date"),
                        "availability": entry.get("availability"),
                        "live_status": entry.get("live_status"),
                        "thumbnail": best_thumbnail(entry),
                        "channel": entry.get("channel"),
                        "channel_id": entry.get("channel_id"),
                    },
                )
                if tab not in item["source_tabs"]:
                    item["source_tabs"].append(tab)

    videos = sorted(
        merged.values(),
        key=lambda item: (int(item.get("timestamp") or 0), str(item.get("title") or "").lower()),
        reverse=True,
    )
    generated_at = datetime.now(timezone.utc).isoformat()
    document = {
        "generated_at": generated_at,
        "channel_root": channel_root,
        "channel_resolution": resolution,
        "unique_video_count": len(videos),
        "tab_counts_before_deduplication": tab_counts,
        "videos": videos,
    }
    (OUT / "inventory.json").write_text(json.dumps(document, indent=2, ensure_ascii=False), encoding="utf-8")

    columns = [
        "video_id", "title", "url", "source_tabs", "duration_seconds", "view_count",
        "timestamp", "upload_date", "availability", "live_status", "thumbnail", "channel", "channel_id",
    ]
    with (OUT / "inventory.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        for item in videos:
            row = dict(item)
            row["source_tabs"] = ",".join(row["source_tabs"])
            writer.writerow(row)

    lines = [
        "# YouTube Channel Inventory",
        "",
        f"Generated: {generated_at}",
        f"Resolved channel: {channel_root or 'FAILED'}",
        f"Unique public uploads: **{len(videos)}**",
        "",
        "## Source tabs",
        "",
        *[f"- {tab}: {tab_counts[tab]}" for tab in TABS],
        "",
        "## Uploads",
        "",
    ]
    for index, item in enumerate(videos, start=1):
        lines.append(
            f"{index}. [{item['title']}]({item['url']}) — {','.join(item['source_tabs'])} — `{item['video_id']}`"
        )
    (OUT / "SUMMARY.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(json.dumps({"channel_root": channel_root, "unique_video_count": len(videos), "tab_counts": tab_counts}))
    return 0 if videos else 2


if __name__ == "__main__":
    raise SystemExit(main())
