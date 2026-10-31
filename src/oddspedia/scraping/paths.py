"""Canonical Oddspedia source-artifact paths (mirrors ``fotmob/bronze/paths.py``).

Oddspedia is an isolated source domain. Historical and Live aspects follow
FotMob's source-local storage convention without sharing implementation. The
root comes from ``Settings.oddspedia.data_dir`` each time a path is built.
"""

import os
from datetime import date, datetime
from pathlib import Path

from src.common.dates import normalize_compact_date
from src.common.paths import PROJECT_ROOT
from src.oddspedia.scraping.config import get_settings, normalize_sport


def data_dir() -> str:
    """Return the absolute Oddspedia data root (``data/oddspedia`` by default)."""
    configured = Path(get_settings().data_dir)
    # Accept the former aspect-specific setting as a root override so deployments
    # do not accidentally create ``historical/historical`` on upgrade.
    if configured.name == "historical":
        configured = configured.parent
    return str(configured if configured.is_absolute() else PROJECT_ROOT / configured)


def historical_dir() -> str:
    return os.path.join(data_dir(), "historical")


def live_dir() -> str:
    return os.path.join(data_dir(), "live")


def logs_dir() -> str:
    return str(PROJECT_ROOT / "logs" / "oddspedia")


def get_storage_aspect(date_str: str, current_date: date | None = None) -> str:
    """Return the Historical or Live aspect for one collection date.

    Completed dates are immutable Historical artifacts. The machine-local
    current date is a refreshable Live snapshot; future dates are rejected.
    """
    target_date = datetime.strptime(normalize_compact_date(date_str), "%Y%m%d").date()
    today = current_date or date.today()
    if target_date > today:
        raise ValueError(f"future dates cannot be collected: {date_str}")
    return "live" if target_date == today else "historical"


def get_date_dir(date_str=None, sport=None):
    """Return the root directory for a date's storage aspect."""
    normalize_sport(sport)
    date_id = normalize_compact_date(date_str or date.today().strftime("%Y%m%d"))
    return live_dir() if get_storage_aspect(date_id) == "live" else historical_dir()


def _get_artifact_date_dir(artifact: str, date_str: str, sport=None) -> str:
    """Return a canonical ``{aspect}/{artifact}/{YYYYMM}/{YYYYMMDD}`` directory."""
    normalize_sport(sport)
    date_id = normalize_compact_date(date_str)
    return os.path.join(get_date_dir(date_id, sport=sport), artifact, date_id[:6], date_id)


def get_match_links_file(date_str=None, sport=None):
    """Return the match-links JSON path for a given date.
    e.g. data/oddspedia/historical/daily_listings/202602/20260227/match_links.json
    """
    date_id = normalize_compact_date(date_str or date.today().strftime("%Y%m%d"))
    return os.path.join(
        _get_artifact_date_dir("daily_listings", date_id, sport), "match_links.json"
    )


def get_discovery_snapshot_file(date_str, sport=None):
    """Return the diagnostic snapshot path for an unaccepted discovery."""
    normalize_sport(sport)
    date_id = normalize_compact_date(date_str)
    return os.path.join(
        _get_artifact_date_dir("daily_listings", date_id, sport), "discovery_partial.json"
    )


def get_manifest_file(date_str, sport=None):
    """Return the scrape manifest JSON path for a given date."""
    normalize_sport(sport)
    date_id = normalize_compact_date(date_str)
    return os.path.join(_get_artifact_date_dir("manifests", date_id, sport), "manifest.json")


def get_prioritized_match_links_file(date_str, sport=None):
    """Return the historical DepthMark-derived priority artifact for one date.

    Unlike source listings, priority is meaningful only after a completed
    historical DepthMark reference window. It therefore always belongs below
    the Historical Oddspedia root, including when the source listing was first
    discovered as a Live snapshot.
    """
    normalize_sport(sport)
    date_id = normalize_compact_date(date_str)
    return os.path.join(
        historical_dir(),
        "link_priorities",
        date_id[:6],
        date_id,
        "prioritized_match_links.json",
    )


def get_matches_dir(date_str=None, sport=None):
    """Return the per-match JSON directory for a given date.
    e.g. data/oddspedia/historical/matches/202602/20260227/
    """
    date_id = normalize_compact_date(date_str or date.today().strftime("%Y%m%d"))
    return _get_artifact_date_dir("matches", date_id, sport)


def get_match_file(date_str: str, match_id: str, sport=None) -> str:
    """Return the canonical raw match-payload filename for one fixture."""
    return os.path.join(get_matches_dir(date_str, sport=sport), f"{match_id}.json")


def get_run_logs_dir(date_str, sport=None):
    """Return the directory containing event logs for one scrape date."""
    date_id = normalize_compact_date(date_str)
    return os.path.join(logs_dir(), normalize_sport(sport), date_id[:6], date_id)
