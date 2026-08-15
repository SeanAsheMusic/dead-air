#!/usr/bin/env python3
"""Capture exact video pixels from YouTube's real HTML5 video element.

This is a browser fallback for public uploads when direct media extraction is
blocked at a cloud-runner IP. It does not synthesize, recreate, or alter the
subject. The output is a screenshot of the decoded video element itself.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from playwright.sync_api import Browser, Page, TimeoutError as PlaywrightTimeoutError, sync_playwright

VIDEO_IDS = (
    "aj6xPlCG0sA",  # recent horizontal upload; embedding may be disabled
    "eDqL7vfFWw0",  # older music video
    "vETs-koEJro",  # Short
)
OUT = Path("artifacts/browser-frame-probe")

ROUTES: tuple[tuple[str, str], ...] = (
    (
        "nocookie-embed",
        "https://www.youtube-nocookie.com/embed/{video_id}?autoplay=1&mute=1&controls=0&playsinline=1&rel=0&enablejsapi=1",
    ),
    (
        "youtube-embed",
        "https://www.youtube.com/embed/{video_id}?autoplay=1&mute=1&controls=0&playsinline=1&rel=0&enablejsapi=1",
    ),
    ("desktop-watch", "https://www.youtube.com/watch?v={video_id}&autoplay=1"),
    ("mobile-watch", "https://m.youtube.com/watch?v={video_id}&autoplay=1"),
)


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", value).strip("-")


def video_state(page: Page) -> dict[str, Any]:
    return page.evaluate(
        """
        () => {
          const video = document.querySelector('video');
          if (!video) return {present: false};
          return {
            present: true,
            readyState: video.readyState,
            networkState: video.networkState,
            duration: Number.isFinite(video.duration) ? video.duration : null,
            currentTime: video.currentTime,
            paused: video.paused,
            ended: video.ended,
            muted: video.muted,
            videoWidth: video.videoWidth,
            videoHeight: video.videoHeight,
            currentSrc: video.currentSrc || null,
            error: video.error ? {code: video.error.code, message: video.error.message || null} : null,
          };
        }
        """
    )


def dismiss_consent(page: Page) -> None:
    candidates = (
        "Accept all",
        "Reject all",
        "I agree",
        "No thanks",
        "Not now",
    )
    for text in candidates:
        try:
            locator = page.get_by_role("button", name=re.compile(f"^{re.escape(text)}$", re.I)).first
            if locator.is_visible(timeout=500):
                locator.click(timeout=1500)
        except Exception:  # noqa: BLE001 - optional UI varies by region
            continue


def seek_and_capture(page: Page, path: Path, target_seconds: float) -> dict[str, Any]:
    page.wait_for_selector("video", state="attached", timeout=45_000)
    page.wait_for_function(
        "document.querySelector('video') && document.querySelector('video').readyState >= 1",
        timeout=60_000,
    )

    state = video_state(page)
    duration = state.get("duration")
    if isinstance(duration, (int, float)) and duration > 0:
        target_seconds = min(target_seconds, max(0.0, float(duration) - 0.75))

    page.evaluate(
        """
        async (target) => {
          const video = document.querySelector('video');
          video.muted = true;
          video.volume = 0;
          try { await video.play(); } catch (_) {}
          if (Number.isFinite(target)) video.currentTime = target;
        }
        """,
        target_seconds,
    )

    try:
        page.wait_for_function(
            """
            (target) => {
              const video = document.querySelector('video');
              return video && video.readyState >= 2 && Math.abs(video.currentTime - target) < 1.75;
            }
            """,
            arg=target_seconds,
            timeout=60_000,
        )
    except PlaywrightTimeoutError:
        # A decoded current frame can still be valid even when the seek event is
        # not observable in a heavily scripted player.
        pass

    locator = page.locator("video").first
    box = locator.bounding_box()
    if not box or box["width"] < 160 or box["height"] < 90:
        raise RuntimeError(f"Video element has unusable bounds: {box}")

    locator.screenshot(path=str(path), type="jpeg", quality=94, timeout=60_000)
    result = video_state(page)
    result["target_seconds"] = target_seconds
    result["bounding_box"] = box
    result["path"] = str(path)
    result["size_bytes"] = path.stat().st_size if path.exists() else 0
    return result


def try_route(browser: Browser, video_id: str, route_name: str, url_template: str) -> dict[str, Any]:
    url = url_template.format(video_id=video_id)
    context = browser.new_context(
        viewport={"width": 1440, "height": 900},
        device_scale_factor=1,
        locale="en-US",
        timezone_id="America/Los_Angeles",
        user_agent=(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/140.0.0.0 Safari/537.36"
        ),
        extra_http_headers={
            "Accept-Language": "en-US,en;q=0.9",
            "DNT": "1",
        },
    )
    context.add_init_script(
        "Object.defineProperty(navigator, 'webdriver', {get: () => undefined});"
    )
    page = context.new_page()
    console: list[str] = []
    page.on("console", lambda message: console.append(f"{message.type}: {message.text}"))
    page.on("pageerror", lambda error: console.append(f"pageerror: {error}"))

    stem = f"{video_id}-{safe_name(route_name)}"
    result: dict[str, Any] = {
        "video_id": video_id,
        "route": route_name,
        "url": url,
        "success": False,
    }

    try:
        response = page.goto(url, wait_until="domcontentloaded", timeout=75_000)
        result["http_status"] = response.status if response else None
        page.wait_for_timeout(4_000)
        dismiss_consent(page)
        page.wait_for_timeout(2_000)

        result["title"] = page.title()
        result["final_url"] = page.url
        try:
            result["body_text"] = page.locator("body").inner_text(timeout=5_000)[:4_000]
        except Exception:  # noqa: BLE001
            result["body_text"] = None

        diagnostic_path = OUT / f"{stem}.page.jpg"
        page.screenshot(path=str(diagnostic_path), type="jpeg", quality=80, full_page=False)
        result["diagnostic_page"] = str(diagnostic_path)
        result["initial_video_state"] = video_state(page)

        frame_path = OUT / f"{stem}.frame.jpg"
        capture = seek_and_capture(page, frame_path, target_seconds=5.0)
        result["capture"] = capture
        result["success"] = bool(frame_path.exists() and capture.get("videoWidth") and capture.get("videoHeight"))
    except Exception as exc:  # noqa: BLE001 - full diagnostic is required
        result["error"] = repr(exc)
        try:
            result["failure_video_state"] = video_state(page)
        except Exception:  # noqa: BLE001
            pass
    finally:
        result["console"] = console[-100:]
        context.close()

    return result


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    report: dict[str, Any] = {"videos": []}
    successes = 0

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            args=(
                "--autoplay-policy=no-user-gesture-required",
                "--disable-blink-features=AutomationControlled",
                "--disable-dev-shm-usage",
                "--no-sandbox",
                "--mute-audio",
            ),
            ignore_default_args=("--enable-automation",),
        )
        try:
            for video_id in VIDEO_IDS:
                item: dict[str, Any] = {"video_id": video_id, "attempts": []}
                for route_name, url_template in ROUTES:
                    attempt = try_route(browser, video_id, route_name, url_template)
                    item["attempts"].append(attempt)
                    if attempt.get("success"):
                        successes += 1
                        item["selected_route"] = route_name
                        break
                report["videos"].append(item)
        finally:
            browser.close()

    report["successful_exact_frames"] = successes
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"successful_exact_frames": successes}))
    return 0 if successes else 2


if __name__ == "__main__":
    raise SystemExit(main())
