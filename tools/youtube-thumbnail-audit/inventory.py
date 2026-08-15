#!/usr/bin/env python3
"""Inventory Sean Ashe's public YouTube uploads without changing the channel."""

from __future__ import annotations

import csv
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

CHANNEL_ROOT = "https://www.youtube.com/@SeanAsheOfficial"
TABS = ("videos", "shorts", "streams")
OUT = Path("artifacts/channel-inventory")


def extract_tab(tab: str) -> tuple[list[dict[str, Any]], str]:
    command = [
        "yt-dlp",
        "--flat-playlist",
        "--dump-single-json",
        "--playlist-end",
        "500",
        "--ignore-errors",
        "--no-warnings",
        "--quiet",
        "--js-runtimes",
        "node",
        f"{CHANNEL_ROOT}/{tab}",
    ]
    result = subprocess.run(command, text=True, capture_output=True, check=False, timeout=900)
    diagnostic = f"exit={result.returncode}\n\nSTDERR\n{result.stderr}\n\nSTDOUT\n{result.stdout}"
    if result.returncode != 0 or not result.stdout.strip():
        return [], diagnostic
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return [], diagnostic
    entries = payload.get("entries") or []
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
    merged: dict[str, dict[str, Any]] = {}
    tab_counts: dict[str, int] = {}

    for tab in TABS:
        entries, diagnostic = extract_tab(tab)
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
        "channel_root": CHANNEL_ROOT,
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

    print(json.dumps({"unique_video_count": len(videos), "tab_counts": tab_counts}))
    return 0 if videos else 2


if __name__ == "__main__":
    raise SystemExit(main())
