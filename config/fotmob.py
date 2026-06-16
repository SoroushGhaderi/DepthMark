"""Backward-compatible FotMob configuration adapter.

``FotMobConfig`` is now a thin wrapper around the unified
:class:`~config.settings.Settings` object.  It preserves the attribute
layout and ``@property`` accessors that existing scraper code relies on
while delegating all storage to the single-source ``Settings.fotmob``
nested model.

Usage (unchanged)::

    from config import FotMobConfig

    config = FotMobConfig()
    logger.info(config.api.base_url)

Sensitive data (tokens) should be in .env file::

    FOTMOB_X_MAS_TOKEN: API authentication token
"""

import json
import random
from typing import Dict, List, Optional

from .settings import (
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
)


class FotMobConfig:
    """Backward-compatible adapter that delegates to ``Settings.fotmob``.

    All nested sub-attributes (``api``, ``request``, ``scraping``, …) are
    the pydantic model instances from :class:`FotMobSettings`.  The
    backward-compatibility ``@property`` accessors on this class continue
    to work so that existing scraper code does not need to change.
    """

    def __init__(self, settings: Optional[Settings] = None) -> None:
        self._settings = settings or get_settings()
        self._fotmob: FotMobSettings = self._settings.fotmob

    # ------------------------------------------------------------------
    # Nested attribute delegation
    # ------------------------------------------------------------------

    @property
    def api(self) -> FotMobApiSettings:
        return self._fotmob.api

    @property
    def request(self) -> FotMobRequestSettings:
        return self._fotmob.request

    @property
    def scraping(self) -> FotMobScrapingSettings:
        return self._fotmob.scraping

    @property
    def storage(self) -> FotMobStorageSettings:
        return self._fotmob.storage

    @property
    def retry(self) -> FotMobRetrySettings:
        return self._fotmob.retry

    @property
    def logging(self) -> FotMobLoggingSettings:
        return self._fotmob.logging

    @property
    def metrics(self) -> FotMobMetricsSettings:
        return self._fotmob.metrics

    @property
    def data_quality(self) -> FotMobDataQualitySettings:
        return self._fotmob.data_quality

    @property
    def proxy(self) -> FotMobProxySettings:
        return self._fotmob.proxy

    # ------------------------------------------------------------------
    # Backward-compatibility @property accessors
    # ------------------------------------------------------------------

    @property
    def api_base_url(self) -> str:
        return self.api.base_url

    @property
    def user_agent(self) -> str:
        return self.api.user_agent

    @property
    def x_mas_token(self) -> str:
        return self.api.x_mas_token

    @property
    def user_agents(self) -> List[str]:
        return self.api.user_agents

    @property
    def request_timeout(self) -> int:
        return self.request.timeout

    @property
    def request_delay_min(self) -> float:
        return self.request.delay_min

    @property
    def request_delay_max(self) -> float:
        return self.request.delay_max

    @property
    def max_workers(self) -> int:
        return self.scraping.max_workers

    @property
    def enable_parallel(self) -> bool:
        return self.scraping.enable_parallel

    @property
    def enable_caching(self) -> bool:
        return self.scraping.enable_caching

    @property
    def cache_ttl_hours(self) -> int:
        return self.scraping.cache_ttl_hours

    @property
    def metrics_update_interval(self) -> int:
        return self.scraping.metrics_update_interval

    @property
    def filter_by_status(self) -> bool:
        return self.scraping.filter_by_status

    @property
    def allowed_match_statuses(self) -> tuple:
        return self.scraping.allowed_match_statuses

    @property
    def parquet_base_dir(self) -> str:
        raise DeprecationWarning(
            "Parquet storage has been removed. Use load_clickhouse.py to load data to ClickHouse."
        )

    @property
    def enable_bronze_storage(self) -> bool:
        return self.storage.enabled

    @property
    def log_level(self) -> str:
        return self.logging.level

    @property
    def log_dir(self) -> str:
        return self.logging.dir

    @property
    def log_format(self) -> str:
        return self.logging.format

    @property
    def metrics_dir(self) -> str:
        return self.metrics.export_path

    @property
    def enable_metrics(self) -> bool:
        return self.metrics.enabled

    @property
    def enable_data_quality_checks(self) -> bool:
        return self.data_quality.enabled

    @property
    def fail_on_quality_issues(self) -> bool:
        return self.data_quality.fail_on_issues

    @property
    def max_retries(self) -> int:
        return self.retry.max_attempts

    @property
    def retry_backoff_factor(self) -> float:
        return self.retry.backoff_factor

    @property
    def retry_status_codes(self) -> tuple:
        return self.retry.status_codes

    # ------------------------------------------------------------------
    # Convenience helpers
    # ------------------------------------------------------------------

    def get_headers(self, referer: str = "https://www.fotmob.com/") -> Dict[str, str]:
        """Get HTTP headers for API requests with random User-Agent."""
        user_agent = (
            random.choice(self.api.user_agents) if self.api.user_agents else self.api.user_agent
        )
        headers = {
            "accept": "*/*",
            "accept-language": "en-US,en;q=0.9,fa;q=0.8",
            "priority": "u=1, i",
            "sec-ch-ua-platform": '"macOS"',
            "Referer": referer,
            "User-Agent": user_agent,
            "x-mas": self.api.x_mas_token,
            "sec-ch-ua": '"Not(A:Brand";v="8", "Chromium";v="144", "Google Chrome";v="144"',
            "sec-ch-ua-mobile": "?0",
            "sec-fetch-dest": "empty",
            "sec-fetch-mode": "cors",
            "sec-fetch-site": "same-origin",
        }
        if self.api.cookies:
            headers["Cookie"] = self._format_cookies(self.api.cookies)
        return headers

    @staticmethod
    def _format_cookies(cookies_input: str) -> str:
        """Convert JSON cookies to cookie header format."""
        try:
            cookies_dict = json.loads(cookies_input)
            return "; ".join(f"{k}={v}" for k, v in cookies_dict.items())
        except (json.JSONDecodeError, AttributeError):
            return cookies_input

    def ensure_directories(self) -> None:
        """Create storage/log directories (delegates to Settings)."""
        self._settings.ensure_directories()

    def to_dict(self) -> Dict[str, object]:
        """Serialise configuration to a plain dict."""
        result = self._settings.to_dict()
        result["fotmob"] = {
            "api": self.api.model_dump(),
            "request": self.request.model_dump(),
            "scraping": self.scraping.model_dump(),
            "storage": self.storage.model_dump(),
            "retry": self.retry.model_dump(),
            "logging": self.logging.model_dump(),
            "metrics": self.metrics.model_dump(),
            "data_quality": self.data_quality.model_dump(),
            "proxy": self.proxy.model_dump(),
        }
        return result

    def validate(self) -> List[str]:
        """Validate configuration values."""
        errors: List[str] = []
        valid_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if self.logging.level not in valid_levels:
            errors.append(
                f"Invalid log level: {self.logging.level}. Must be one of {valid_levels}"
            )
        if not self.storage.bronze_path:
            errors.append("bronze_path cannot be empty")
        return errors
