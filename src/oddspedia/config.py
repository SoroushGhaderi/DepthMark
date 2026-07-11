import os
from datetime import datetime
from pathlib import Path

from config.settings import OddspediaSettings, get_settings as get_depthmark_settings


def get_settings() -> OddspediaSettings:
    """Return the Oddspedia section of DepthMark's unified settings."""
    return get_depthmark_settings().oddspedia


settings = get_settings()

_PROJECT_ROOT = Path(__file__).resolve().parents[2]
# Oddspedia is an isolated source domain.  These are immutable Historical
# source artifacts, intentionally separate from FotMob's Bronze paths.
_configured_data_dir = Path(settings.data_dir)
DATA_DIR = str(
    _configured_data_dir
    if _configured_data_dir.is_absolute()
    else _PROJECT_ROOT / _configured_data_dir
)
LINKS_DIR = os.path.join(DATA_DIR, "links")
MANIFESTS_DIR = os.path.join(DATA_DIR, "manifests")
MATCHES_DIR = os.path.join(DATA_DIR, "matches")
LOGS_DIR = str(_PROJECT_ROOT / "logs" / "oddspedia")
MATCH_LINKS_FILE = os.path.join(LINKS_DIR, "match_links.json")

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


def get_date_dir(date_str=None, sport=None):
    """Return the per-date data directory path."""
    normalize_sport(sport)
    if date_str:
        date_id = normalize_date(date_str)
        return os.path.join(DATA_DIR, "by_date", date_id[:6], date_id)
    today = datetime.now().strftime("%Y%m%d")
    return os.path.join(DATA_DIR, "by_date", today[:6], today)


def get_match_links_file(date_str=None, sport=None):
    """Return the match-links JSON path for a given date.
    e.g. data/links/202602/match_links_20260227.json
    """
    normalize_sport(sport)
    if date_str:
        date_id = normalize_date(date_str)
        return os.path.join(LINKS_DIR, date_id[:6], f"match_links_{date_id}.json")
    return MATCH_LINKS_FILE


def get_discovery_snapshot_file(date_str, sport=None):
    """Return the diagnostic snapshot path for an unaccepted discovery."""
    normalize_sport(sport)
    date_id = normalize_date(date_str)
    return os.path.join(LINKS_DIR, date_id[:6], f"discovery_partial_{date_id}.json")


def get_manifest_file(date_str, sport=None):
    """Return the scrape manifest JSON path for a given date."""
    normalize_sport(sport)
    date_id = normalize_date(date_str)
    return os.path.join(MANIFESTS_DIR, date_id[:6], f"manifest_{date_id}.json")


def get_matches_dir(date_str=None, sport=None):
    """Return the per-match JSON directory for a given date.
    e.g. data/matches/202602/20260227/
    """
    normalize_sport(sport)
    if date_str:
        date_id = normalize_date(date_str)
        return os.path.join(DATA_DIR, "matches", date_id[:6], date_id)
    return MATCHES_DIR


def get_run_logs_dir(date_str, sport=None):
    """Return the directory containing event logs for one scrape date."""
    date_id = normalize_date(date_str)
    return os.path.join(LOGS_DIR, normalize_sport(sport), date_id[:6], date_id)
