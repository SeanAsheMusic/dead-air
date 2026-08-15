#!/usr/bin/env python3
"""Probe exact-frame access without account cookies.

The probe tries YouTube clients that currently do not require a GVS PO token
before falling back to mweb with the local bgutil provider. It intentionally
uses one representative public upload to minimize guest-session requests.
"""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

VIDEO_ID = "aj6xPlCG0sA"  # recent horizontal public upload
OUT = Path("artifacts/source-probe")

CLIENT_ATTEMPTS: tuple[tuple[str, str], ...] = (
    (
        "web-embedded-no-webpage",
        "youtube:player_client=web_embedded;player_skip=webpage,configs;fetch_pot=never;jsc_trace=true",
    ),
    (
        "android-vr-no-webpage",
        "youtube:player_client=android_vr;player_skip=webpage,configs;fetch_pot=never;jsc_trace=true",
    ),
    (
        "tv-no-webpage",
        "youtube:player_client=tv;player_skip=webpage,configs;fetch_pot=never;jsc_trace=true",
    ),
    (
        "tv-simply-no-webpage",
        "youtube:player_client=tv_simply;player_skip=webpage,configs;fetch_pot=never;jsc_trace=true",
    ),
    (
        "web-safari-no-webpage",
        "youtube:player_client=web_safari;player_skip=webpage,configs;fetch_pot=auto;pot_trace=true;jsc_trace=true",
    ),
    (
        "mweb-bgutil-no-webpage",
        "youtube:player_client=mweb;player_skip=webpage,configs;fetch_pot=always;pot_trace=true;jsc_trace=true",
    ),
    (
        "default-clients",
        "youtube:player_client=default;fetch_pot=auto;pot_trace=true;jsc_trace=true",
    ),
)


def run(command: list[str], timeout: int = 900) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True, check=False, timeout=timeout)


def base_command() -> list[str]:
    return [
        "yt-dlp",
        "--no-warnings",
        "--js-runtimes",
        "node",
        "--impersonate",
        "chrome",
        "--sleep-requests",
        "3",
    ]


def write_log(path: Path, command: list[str], result: subprocess.CompletedProcess[str]) -> None:
    path.write_text(
        f"COMMAND: {' '.join(command)}\nEXIT: {result.returncode}"
        f"\n\nSTDERR\n{result.stderr}\n\nSTDOUT\n{result.stdout}",
        encoding="utf-8",
    )


def parse_json(stdout: str) -> dict[str, Any] | None:
    value = stdout.strip()
    if not value or value == "null":
        return None
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    url = f"https://www.youtube.com/watch?v={VIDEO_ID}"

    environment_commands = {
        "yt_dlp": ["yt-dlp", "--version"],
        "node": ["node", "--version"],
        "ffmpeg": ["ffmpeg", "-version"],
        "curl_cffi": ["python", "-c", "import curl_cffi; print(curl_cffi.__version__)"],
        "ejs": ["python", "-c", "import importlib.metadata as m; print(m.version('yt-dlp-ejs'))"],
    }
    environment: dict[str, dict[str, object]] = {}
    for name, command in environment_commands.items():
        result = run(command, timeout=120)
        environment[name] = {
            "exit": result.returncode,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        }

    verbose_command = base_command() + [
        "-v",
        "--skip-download",
        "--extractor-args",
        CLIENT_ATTEMPTS[0][1],
        url,
    ]
    verbose_result = run(verbose_command, timeout=600)
    write_log(OUT / "environment.log.txt", verbose_command, verbose_result)
    (OUT / "environment.json").write_text(
        json.dumps(environment, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    attempts: list[dict[str, object]] = []
    selected_name: str | None = None
    selected_args: str | None = None
    selected_metadata: dict[str, Any] | None = None

    for index, (name, extractor_args) in enumerate(CLIENT_ATTEMPTS, start=1):
        metadata_command = base_command() + [
            "--skip-download",
            "--dump-single-json",
            "--extractor-args",
            extractor_args,
            url,
        ]
        result = run(metadata_command, timeout=900)
        write_log(OUT / f"attempt-{index:02d}-{name}.log.txt", metadata_command, result)
        metadata = parse_json(result.stdout)
        formats = metadata.get("formats") if metadata else None
        usable_formats = [
            fmt
            for fmt in (formats or [])
            if isinstance(fmt, dict)
            and fmt.get("url")
            and fmt.get("vcodec") not in (None, "none")
        ]
        attempt = {
            "name": name,
            "extractor_args": extractor_args,
            "exit": result.returncode,
            "metadata_received": bool(metadata),
            "format_count": len(formats or []),
            "usable_video_format_count": len(usable_formats),
        }
        attempts.append(attempt)

        if result.returncode == 0 and metadata and usable_formats:
            selected_name = name
            selected_args = extractor_args
            selected_metadata = metadata
            break

        time.sleep(5)

    report: dict[str, object] = {
        "video_id": VIDEO_ID,
        "url": url,
        "attempts": attempts,
        "selected_attempt": selected_name,
        "exact_frame_created": False,
    }

    if not selected_args or not selected_metadata:
        (OUT / "report.json").write_text(
            json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        print(json.dumps(report, ensure_ascii=False))
        return 2

    formats = selected_metadata.get("formats") or []
    slim_metadata = {
        key: selected_metadata.get(key)
        for key in (
            "id",
            "title",
            "description",
            "duration",
            "width",
            "height",
            "aspect_ratio",
            "channel",
            "channel_id",
            "upload_date",
            "view_count",
            "availability",
        )
    }
    slim_metadata["selected_attempt"] = selected_name
    slim_metadata["format_count"] = len(formats)
    slim_metadata["formats"] = [
        {
            key: fmt.get(key)
            for key in (
                "format_id",
                "format_note",
                "ext",
                "width",
                "height",
                "fps",
                "vcodec",
                "acodec",
                "protocol",
                "filesize",
                "filesize_approx",
            )
        }
        for fmt in formats
        if isinstance(fmt, dict)
    ]
    (OUT / f"{VIDEO_ID}.metadata.json").write_text(
        json.dumps(slim_metadata, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    output_template = str(OUT / f"{VIDEO_ID}.source.%(ext)s")
    download_command = base_command() + [
        "--no-playlist",
        "--extractor-args",
        selected_args,
        "--download-sections",
        "*0-12",
        "--force-keyframes-at-cuts",
        "-f",
        "bestvideo[height<=480][ext=mp4]/best[height<=480][ext=mp4]/worstvideo/worst",
        "-o",
        output_template,
        url,
    ]
    download_result = run(download_command, timeout=1800)
    write_log(OUT / f"{VIDEO_ID}.download.log.txt", download_command, download_result)
    report["download_exit"] = download_result.returncode

    source_files = sorted(
        path
        for path in OUT.glob(f"{VIDEO_ID}.source.*")
        if not path.name.endswith((".part", ".ytdl"))
    )
    if download_result.returncode == 0 and source_files:
        source = source_files[0]
        frame = OUT / f"{VIDEO_ID}.frame.jpg"
        frame_command = [
            "ffmpeg",
            "-y",
            "-ss",
            "5",
            "-i",
            str(source),
            "-frames:v",
            "1",
            "-q:v",
            "2",
            str(frame),
        ]
        frame_result = run(frame_command, timeout=300)
        write_log(OUT / f"{VIDEO_ID}.ffmpeg.log.txt", frame_command, frame_result)
        report["exact_frame_created"] = frame.exists()
        report["frame_path"] = str(frame) if frame.exists() else None
        report["source_size_bytes"] = source.stat().st_size

    (OUT / "report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["exact_frame_created"] else 3


if __name__ == "__main__":
    raise SystemExit(main())
