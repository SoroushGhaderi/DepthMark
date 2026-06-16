"""Unified configuration system for DepthMark.

All configuration lives in :class:`~config.settings.Settings`.  The
``FotMobConfig`` adapter preserves backward-compatible attribute access
for scraper code.

Usage::

    from config import FotMobConfig

    config = FotMobConfig()

Or use the single source of truth directly::

    from config.settings import get_settings

    settings = get_settings()
"""

from .settings import (
    Environment,
    FotMobApiSettings,
    FotMobDataQualitySettings,
    FotMobLoggingSettings,
    FotMobMetricsSettings,
    FotMobProxySettings,
    FotMobRequestSettings,
    FotMobRetrySettings,
    FotMobScrapingSettings,
    FotMobSettings,
    FotMobStorageSettings,
    Settings,
    get_settings,
    reset_settings,
)
from .fotmob import FotMobConfig

# Legacy aliases — still importable for any code that references them
from .base import LoggingConfig, MetricsConfig, RetryConfig, StorageConfig

__all__ = [
    # Unified settings
    "Settings",
    "Environment",
    "get_settings",
    "reset_settings",
    # FotMob nested models
    "FotMobSettings",
    "FotMobApiSettings",
    "FotMobRequestSettings",
    "FotMobScrapingSettings",
    "FotMobStorageSettings",
    "FotMobRetrySettings",
    "FotMobLoggingSettings",
    "FotMobMetricsSettings",
    "FotMobDataQualitySettings",
    "FotMobProxySettings",
    # Backward-compat adapter
    "FotMobConfig",
    # Legacy dataclass aliases
    "StorageConfig",
    "LoggingConfig",
    "MetricsConfig",
    "RetryConfig",
]

__version__ = "2.0.0"
