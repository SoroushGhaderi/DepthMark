import os
from datetime import date, datetime
from pathlib import Path
from typing import Optional

from config.settings import OddspediaSettings, get_settings as get_depthmark_settings


def get_settings() -> OddspediaSettings:
    """Return the Oddspedia section of DepthMark's unified settings."""
    return get_depthmark_settings().oddspedia


settings = get_settings()

_PROJECT_ROOT = Path(__file__).resolve().parents[2]
# Oddspedia is an isolated source domain. Historical and Live aspects mirror
# FotMob's source-local storage convention without sharing implementation.
_configured_data_dir = Path(settings.data_dir)
# Accept the former aspect-specific setting as a root override so deployments
# do not accidentally create ``historical/historical`` on upgrade.
if _configured_data_dir.name == "historical":
    _configured_data_dir = _configured_data_dir.parent
DATA_DIR = str(
    _configured_data_dir
    if _configured_data_dir.is_absolute()
    else _PROJECT_ROOT / _configured_data_dir
)
HISTORICAL_DIR = os.path.join(DATA_DIR, "historical")
LIVE_DIR = os.path.join(DATA_DIR, "live")
LOGS_DIR = str(_PROJECT_ROOT / "logs" / "oddspedia")

BASE_URL = settings.base_url
FOOTBALL_ODDS_URL = f"{BASE_URL}/football"
DEFAULT_SPORT = "football"
SCRAPER_ENV = settings.scraper_env
MIN_DELAY = settings.min_delay
MAX_DELAY = settings.max_delay
PAGE_LOAD_TIMEOUT = settings.page_load_timeout
CLOUDFLARE_WAIT = settings.cloudflare_wait
SCROLL_PAUSE = settings.scroll_pause
WORKER_MIN_DELAY = settings.worker_min_delay
WORKER_MAX_DELAY = settings.worker_max_delay


def normalize_sport(sport=None):
    """Return this project’s fixed sport, rejecting cross-project values."""
    requested = (sport or DEFAULT_SPORT).strip().lower()
    if requested != DEFAULT_SPORT:
        raise ValueError(f"this project only supports {DEFAULT_SPORT}: {requested}")
    return DEFAULT_SPORT


def get_sport_listing_url(sport=None):
    """Return the Oddspedia football listing URL."""
    normalize_sport(sport)
    return FOOTBALL_ODDS_URL


def normalize_date(date_str: str) -> str:
    """Return a date identifier in the canonical YYYYMMDD format."""
    value = str(date_str).strip()
    if len(value) == 8 and value.isdigit():
        datetime.strptime(value, "%Y%m%d")
        return value
    raise ValueError(f"date must use YYYYMMDD format: {date_str}")


def normalize_month(month_str: str) -> str:
    """Return a month identifier in the canonical YYYYMM format."""
    value = str(month_str).strip()
    if len(value) == 6 and value.isdigit():
        datetime.strptime(value, "%Y%m")
        return value
    raise ValueError(f"month must use YYYYMM format: {month_str}")


def get_storage_aspect(date_str: str, current_date: Optional[date] = None) -> str:
    """Return the Historical or Live aspect for one collection date.

    Completed dates are immutable Historical artifacts. The machine-local
    current date is a refreshable Live snapshot; future dates are rejected.
    """
    target_date = datetime.strptime(normalize_date(date_str), "%Y%m%d").date()
    today = current_date or datetime.now().date()
    if target_date > today:
        raise ValueError(f"future dates cannot be collected: {date_str}")
    return "live" if target_date == today else "historical"


def get_date_dir(date_str=None, sport=None):
    """Return the root directory for a date's storage aspect."""
    normalize_sport(sport)
    date_id = normalize_date(date_str or datetime.now().strftime("%Y%m%d"))
    return LIVE_DIR if get_storage_aspect(date_id) == "live" else HISTORICAL_DIR


def _get_artifact_date_dir(artifact: str, date_str: str, sport=None) -> str:
    """Return a canonical ``{aspect}/{artifact}/{YYYYMM}/{YYYYMMDD}`` directory."""
    normalize_sport(sport)
    date_id = normalize_date(date_str)
    return os.path.join(get_date_dir(date_id, sport=sport), artifact, date_id[:6], date_id)


def get_match_links_file(date_str=None, sport=None):
    """Return the match-links JSON path for a given date.
    e.g. data/oddspedia/historical/daily_listings/202602/20260227/match_links.json
    """
    date_id = normalize_date(date_str or datetime.now().strftime("%Y%m%d"))
    return os.path.join(
        _get_artifact_date_dir("daily_listings", date_id, sport), "match_links.json"
    )


def get_discovery_snapshot_file(date_str, sport=None):
    """Return the diagnostic snapshot path for an unaccepted discovery."""
    normalize_sport(sport)
    date_id = normalize_date(date_str)
    return os.path.join(
        _get_artifact_date_dir("daily_listings", date_id, sport), "discovery_partial.json"
    )


def get_manifest_file(date_str, sport=None):
    """Return the scrape manifest JSON path for a given date."""
    normalize_sport(sport)
    date_id = normalize_date(date_str)
    return os.path.join(_get_artifact_date_dir("manifests", date_id, sport), "manifest.json")


def get_matches_dir(date_str=None, sport=None):
    """Return the per-match JSON directory for a given date.
    e.g. data/oddspedia/historical/matches/202602/20260227/
    """
    date_id = normalize_date(date_str or datetime.now().strftime("%Y%m%d"))
    return _get_artifact_date_dir("matches", date_id, sport)


def get_match_file(date_str: str, match_id: str, sport=None) -> str:
    """Return the canonical raw match-payload filename for one fixture."""
    return os.path.join(get_matches_dir(date_str, sport=sport), f"{match_id}.json")


def get_run_logs_dir(date_str, sport=None):
    """Return the directory containing event logs for one scrape date."""
    date_id = normalize_date(date_str)
    return os.path.join(LOGS_DIR, normalize_sport(sport), date_id[:6], date_id)
