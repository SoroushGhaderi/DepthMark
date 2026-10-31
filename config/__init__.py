"""Unified configuration system for DepthMark.

:class:`~config.settings.Settings` is the only reader of environment variables,
``.env`` files, and ``config.yaml``. FotMob scraping code receives the
``Settings.fotmob`` model::

    from config.settings import get_settings

    settings = get_settings()
    settings.fotmob.api.base_url
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
    OddspediaSettings,
    Settings,
    get_settings,
    reset_settings,
)

__all__ = [
    "Settings",
    "Environment",
    "get_settings",
    "reset_settings",
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
    "OddspediaSettings",
]
