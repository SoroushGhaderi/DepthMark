"""Oddspedia scraper configuration, read from DepthMark settings when used.

Nothing here is frozen at import: every value comes from
``Settings.oddspedia`` at call time, so tests and overrides only need to change
settings (``reset_settings()`` after changing the environment).
"""

from config.settings import OddspediaSettings
from config.settings import get_settings as get_depthmark_settings

# Odds can be absent while the page is still loading. Keep this policy
# separate from the broader page/error retry budget so an empty odds result is
# only accepted after three football extraction attempts.
FOOTBALL_ODDS_MAX_ATTEMPTS = 3
DEFAULT_SPORT = "football"


def get_settings() -> OddspediaSettings:
    """Return the Oddspedia section of DepthMark's unified settings."""
    return get_depthmark_settings().oddspedia


def base_url() -> str:
    """Return the configured Oddspedia site root, e.g. ``https://oddspedia.com``."""
    return get_settings().base_url


def normalize_sport(sport=None):
    """Return this project’s fixed sport, rejecting cross-project values."""
    requested = (sport or DEFAULT_SPORT).strip().lower()
    if requested != DEFAULT_SPORT:
        raise ValueError(f"this project only supports {DEFAULT_SPORT}: {requested}")
    return DEFAULT_SPORT


def get_sport_listing_url(sport=None):
    """Return the Oddspedia football listing URL."""
    normalize_sport(sport)
    return f"{base_url()}/football"
