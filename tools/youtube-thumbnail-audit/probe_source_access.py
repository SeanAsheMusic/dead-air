#!/usr/bin/env python3
"""Probe exact-frame access for representative Sean Ashe YouTube uploads."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

VIDEO_IDS = (
    "aj6xPlCG0sA",  # standard recent horizontal upload
    "vETs-koEJro",  # recent Short
    "eDqL7vfFWw0",  # older official music video
)
OUT = Path("artifacts/source-probe")
EXTRACTOR_ARGS = "youtube:player_client=mweb"


def run(command: list[str], timeout: int = 900) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True, check=False, timeout=timeout)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    successes = 0
    report: dict[str, object] = {"videos": []}

    version = run(["yt-dlp", "--version"])
    verbose = run(["yt-dlp", "-v", "--skip-download", "--extractor-args", EXTRACTOR_ARGS,
                   f"https://www.youtube.com/watch?v={VIDEO_IDS[0]}"])
    (OUT / "environment.log.txt").write_text(
        f"yt-dlp version: {version.stdout}{version.stderr}\n\nVERBOSE PROBE\n{verbose.stdout}\n{verbose.stderr}",
        encoding="utf-8",
    )

    for video_id in VIDEO_IDS:
        url = f"https://www.youtube.com/watch?v={video_id}"
        item: dict[str, object] = {"video_id": video_id, "url": url}

        metadata_command = [
            "yt-dlp", "--skip-download", "--dump-single-json", "--no-warnings",
            "--js-runtimes", "node", "--extractor-args", EXTRACTOR_ARGS, url,
        ]
        metadata_result = run(metadata_command)
        (OUT / f"{video_id}.metadata.log.txt").write_text(
            f"COMMAND: {' '.join(metadata_command)}\nEXIT: {metadata_result.returncode}"
            f"\n\nSTDERR\n{metadata_result.stderr}\n\nSTDOUT\n{metadata_result.stdout}",
            encoding="utf-8",
        )
        item["metadata_exit"] = metadata_result.returncode

        if metadata_result.returncode != 0 or not metadata_result.stdout.strip() or metadata_result.stdout.strip() == "null":
            report["videos"].append(item)
            continue

        try:
            metadata = json.loads(metadata_result.stdout)
        except json.JSONDecodeError:
            report["videos"].append(item)
            continue

        slim_metadata = {
            key: metadata.get(key)
            for key in (
                "id", "title", "description", "duration", "width", "height", "aspect_ratio",
                "channel", "channel_id", "upload_date", "view_count", "availability",
            )
        }
        formats = metadata.get("formats") or []
        slim_metadata["format_count"] = len(formats)
        slim_metadata["formats"] = [
            {
                key: fmt.get(key)
                for key in (
                    "format_id", "format_note", "ext", "width", "height", "fps",
                    "vcodec", "acodec", "protocol", "filesize", "filesize_approx",
                )
            }
            for fmt in formats
            if isinstance(fmt, dict)
        ]
        (OUT / f"{video_id}.metadata.json").write_text(
            json.dumps(slim_metadata, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        item.update({"title": metadata.get("title"), "duration": metadata.get("duration"), "format_count": len(formats)})

        output_template = str(OUT / f"{video_id}.source.%(ext)s")
        download_command = [
            "yt-dlp", "--no-playlist", "--no-warnings", "--js-runtimes", "node",
            "--extractor-args", EXTRACTOR_ARGS,
            "--download-sections", "*0-12", "--force-keyframes-at-cuts",
            "-f", "bestvideo[height<=480][ext=mp4]/best[height<=480][ext=mp4]/worstvideo/worst",
            "-o", output_template, url,
        ]
        download_result = run(download_command, timeout=1200)
        (OUT / f"{video_id}.download.log.txt").write_text(
            f"COMMAND: {' '.join(download_command)}\nEXIT: {download_result.returncode}"
            f"\n\nSTDERR\n{download_result.stderr}\n\nSTDOUT\n{download_result.stdout}",
            encoding="utf-8",
        )
        item["download_exit"] = download_result.returncode

        source_files = sorted(OUT.glob(f"{video_id}.source.*"))
        if download_result.returncode == 0 and source_files:
            source = source_files[0]
            frame = OUT / f"{video_id}.frame.jpg"
            frame_result = run([
                "ffmpeg", "-y", "-ss", "5", "-i", str(source), "-frames:v", "1",
                "-q:v", "2", str(frame),
            ])
            (OUT / f"{video_id}.ffmpeg.log.txt").write_text(
                f"EXIT: {frame_result.returncode}\n{frame_result.stdout}\n{frame_result.stderr}", encoding="utf-8"
            )
            item["frame_created"] = frame.exists()
            if frame.exists():
                successes += 1

        report["videos"].append(item)

    report["successful_exact_frames"] = successes
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0 if successes else 2


if __name__ == "__main__":
    raise SystemExit(main())
