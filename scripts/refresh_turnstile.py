#!/usr/bin/env python3
"""Refresh the turnstile_verified cookie in credentials.json.

Run this whenever the scraper reports TURNSTILE_REQUIRED:
    python3 scripts/refresh_turnstile.py

Requirements: Chrome must be open and you must have visited fotmob.com recently.
The scraper hot-reloads credentials.json on every request — no restart needed.
"""
import json
import sys
import time
from pathlib import Path
from typing import List, Optional, Tuple

ROOT = Path(__file__).parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from src.common.logging import get_logger, initialize_logging

initialize_logging(log_level="INFO", force=True)
logger = get_logger(__name__)


def get_chrome_turnstile() -> str:
    """Read freshest `turnstile_verified` from Chrome cookies for FotMob."""
    try:
        import browser_cookie3

        candidates: List[str] = []
        for domain in ("www.fotmob.com", ".fotmob.com", "fotmob.com"):
            cj = browser_cookie3.chrome(domain_name=domain)
            for cookie in cj:
                if cookie.name == "turnstile_verified" and cookie.value:
                    candidates.append(cookie.value)

        if not candidates:
            return ""

        # Prefer the token with the newest embedded timestamp; fall back to latest seen.
        def _token_created_at(value: str) -> int:
            parts = value.split(".")
            if len(parts) == 3:
                try:
                    return int(parts[1])
                except ValueError:
                    pass
            return -1

        return max(candidates, key=_token_created_at)
    except Exception as exc:
        logger.debug("Could not read Chrome cookies: %s", exc)
    return ""


def get_turnstile_age_seconds(turnstile_value: str) -> Optional[int]:
    """Get age of turnstile token in seconds. Returns None if format is invalid."""
    parts = turnstile_value.split(".")
    if len(parts) == 3:
        try:
            created_time = int(parts[1])
            age = int(time.time()) - created_time
            return age
        except ValueError:
            pass
    return None


def get_turnstile_age_info(turnstile_value: str) -> Tuple[Optional[int], str]:
    """Get turnstile age in seconds and human-readable status.

    Returns:
        Tuple of (age_seconds, status_string)
    """
    age_seconds = get_turnstile_age_seconds(turnstile_value)

    if age_seconds is None:
        return None, "unknown format"

    if age_seconds < 0:
        return age_seconds, f"future ({-age_seconds}s ahead)"

    remaining = 3600 - age_seconds
    if remaining > 0:
        minutes = remaining // 60
        seconds = remaining % 60
        return age_seconds, f"valid ({minutes}m {seconds}s remaining)"
    else:
        minutes_ago = (-remaining) // 60
        return age_seconds, f"expired ({minutes_ago}m ago)"


def check_age(tv: str) -> str:
    """Return a human-readable status for a turnstile token."""
    _, status = get_turnstile_age_info(tv)
    return status


def _load_credentials_json(path: Path) -> dict:
    """Load credentials.json from disk."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def update_credentials_json(tv: str) -> bool:
    """Update `credentials.json` atomically with a fresh turnstile token."""
    path = ROOT / "credentials.json"
    if not path.exists():
        logger.error(f"credentials.json not found: {path}")
        return False

    try:
        data = _load_credentials_json(path)

        if "cookies" not in data:
            data["cookies"] = {}

        data["cookies"]["turnstile_verified"] = tv

        temp_path = path.with_suffix(".json.tmp")
        with open(temp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        temp_path.replace(path)

        logger.info("Updated credentials.json with new turnstile token")
        return True
    except Exception as e:
        logger.error(f"Error updating credentials.json: {e}")
        return False


def refresh_if_needed(max_age_seconds: int = 1800) -> Tuple[bool, Optional[str]]:
    """Check turnstile age and refresh if needed.

    Args:
        max_age_seconds: Maximum age before refresh (default 30 minutes = 1800 seconds)

    Returns:
        Tuple of (was_refreshed, message)
    """
    creds_path = ROOT / "credentials.json"
    if not creds_path.exists():
        return False, "credentials.json not found"

    try:
        data = _load_credentials_json(creds_path)

        current_tv = data.get("cookies", {}).get("turnstile_verified", "")
        if not current_tv:
            new_tv = get_chrome_turnstile()
            if new_tv and update_credentials_json(new_tv):
                age, status = get_turnstile_age_info(new_tv)
                return True, f"Refreshed (no existing token), age: {status}"
            return False, "No turnstile token found"

        age_seconds, status = get_turnstile_age_info(current_tv)

        if age_seconds is not None and age_seconds >= max_age_seconds:
            new_tv = get_chrome_turnstile()
            if new_tv:
                if update_credentials_json(new_tv):
                    new_age, new_status = get_turnstile_age_info(new_tv)
                    return (
                        True,
                        f"Refreshed (age={age_seconds}s>{max_age_seconds}s), new age: {new_status}",
                    )
            # Auto-refresh via Chrome cookies failed (e.g. no D-Bus in Docker).
            # The existing token may still be usable — report its actual validity.
            return (
                False,
                f"Token stale (age={age_seconds}s>={max_age_seconds}s, {status}), auto-refresh unavailable (run refresh_turnstile.py manually)",
            )

        return False, f"Token valid (age={age_seconds}s<{max_age_seconds}s), {status}"

    except Exception as e:
        return False, f"Error: {str(e)}"


def main():
    """Refresh the stored turnstile cookie from Chrome if available."""
    logger.info("Reading turnstile_verified from Chrome...")
    tv = get_chrome_turnstile()

    if not tv:
        logger.error(
            "Could not read turnstile_verified from Chrome. "
            "1. Open Chrome and visit https://www.fotmob.com, "
            "2. Wait for the page to fully load, "
            "3. Run this script again"
        )
        sys.exit(1)

    status = check_age(tv)
    logger.info(f"Found turnstile: {tv[:60]}...")
    logger.info(f"Status: {status}")

    if status.startswith("expired"):
        logger.warning(
            "Cookie appears expired by timestamp format, but saving anyway. "
            "If scraping still fails, revisit https://www.fotmob.com in Chrome "
            "and solve any challenge before re-running."
        )

    if not update_credentials_json(tv):
        sys.exit(1)
    logger.info("Done. The running scraper will pick up the change automatically.")


if __name__ == "__main__":
    main()
