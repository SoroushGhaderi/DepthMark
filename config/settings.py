"""Unified configuration management for DepthMark project.

Single source of truth for all configuration. Loads from:
1. .env file - Environment variables (pydantic-settings)
2. config.yaml - Application settings (YAML fallback for FotMob scraping config)

Environment variables override YAML values. FotMob-specific env vars use the
pattern FOTMOB_<SECTION>_<KEY> (e.g., FOTMOB_API_BASE_URL).

Usage:
    from config.settings import get_settings, Environment

    settings = get_settings()

    if settings.environment == Environment.PRODUCTION:
        logger.info("Running in production")

    logger.info(f"ClickHouse host: {settings.clickhouse_host}")
    logger.info(f"FotMob API URL: {settings.fotmob.api.base_url}")
"""

import os
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from pydantic import BaseModel, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


# ---------------------------------------------------------------------------
# Environment enum
# ---------------------------------------------------------------------------


class Environment(str, Enum):
    """Application environment types."""

    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"
    TESTING = "testing"


# ---------------------------------------------------------------------------
# FotMob nested configuration models
# ---------------------------------------------------------------------------


class FotMobApiSettings(BaseModel):
    """FotMob API connection settings."""

    base_url: str = "https://www.fotmob.com/api/data"
    user_agent: str = ""
    x_mas_token: str = ""
    cookies: str = ""
    user_agents: List[str] = []


class FotMobRequestSettings(BaseModel):
    """HTTP request throttling settings."""

    timeout: int = 30
    delay_min: float = 2.0
    delay_max: float = 4.0


class FotMobScrapingSettings(BaseModel):
    """Scraping behaviour settings."""

    max_workers: int = 2
    enable_parallel: bool = True
    metrics_update_interval: int = 20
    filter_by_status: bool = True
    allowed_match_statuses: Tuple[str, ...] = (
        "Finished",
        "FullTime",
        "FT",
        "After Extra Time",
        "AET",
        "After Penalties",
        "AP",
    )
    enable_caching: bool = True
    cache_ttl_hours: int = 24


class FotMobStorageSettings(BaseModel):
    """Bronze layer storage settings."""

    bronze_path: str = "data/fotmob"
    enabled: bool = True


class FotMobRetrySettings(BaseModel):
    """HTTP retry/back-off settings."""

    max_attempts: int = 3
    initial_wait: float = 2.0
    max_wait: float = 10.0
    exponential_base: float = 2.0
    backoff_factor: float = 2.0
    status_codes: Tuple[int, ...] = (429, 500, 502, 503, 504)


class FotMobLoggingSettings(BaseModel):
    """FotMob-specific logging settings."""

    level: str = "INFO"
    format: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    file: str = "logs/fotmob_scraper.log"
    max_bytes: int = 10485760
    backup_count: int = 5
    dir: str = "logs"


class FotMobMetricsSettings(BaseModel):
    """FotMob-specific metrics settings."""

    enabled: bool = True
    export_path: str = "metrics"
    export_format: str = "json"


class FotMobDataQualitySettings(BaseModel):
    """Post-scrape data quality checking."""

    enabled: bool = True
    fail_on_issues: bool = False


class FotMobProxySettings(BaseModel):
    """HTTP proxy settings."""

    enabled: bool = False
    http: str = ""
    https: str = ""


class FotMobSettings(BaseModel):
    """Container for all FotMob scraping configuration."""

    api: FotMobApiSettings = FotMobApiSettings()
    request: FotMobRequestSettings = FotMobRequestSettings()
    scraping: FotMobScrapingSettings = FotMobScrapingSettings()
    storage: FotMobStorageSettings = FotMobStorageSettings()
    retry: FotMobRetrySettings = FotMobRetrySettings()
    logging: FotMobLoggingSettings = FotMobLoggingSettings()
    metrics: FotMobMetricsSettings = FotMobMetricsSettings()
    data_quality: FotMobDataQualitySettings = FotMobDataQualitySettings()
    proxy: FotMobProxySettings = FotMobProxySettings()


# ---------------------------------------------------------------------------
# Env-var → FotMob nested-field mapping
# ---------------------------------------------------------------------------

_FOTMOB_ENV_MAP: Dict[str, Tuple[str, str]] = {
    # env var name → (nested_path, key)
    "FOTMOB_X_MAS_TOKEN": ("api", "x_mas_token"),
    "FOTMOB_COOKIES": ("api", "cookies"),
    "FOTMOB_USER_AGENT": ("api", "user_agent"),
    "FOTMOB_API_BASE_URL": ("api", "base_url"),
    "FOTMOB_REQUEST_TIMEOUT": ("request", "timeout"),
    "FOTMOB_DELAY_MIN": ("request", "delay_min"),
    "FOTMOB_DELAY_MAX": ("request", "delay_max"),
    "FOTMOB_MAX_WORKERS": ("scraping", "max_workers"),
    "FOTMOB_ENABLE_PARALLEL": ("scraping", "enable_parallel"),
    "FOTMOB_ENABLE_CACHING": ("scraping", "enable_caching"),
    "FOTMOB_CACHE_TTL_HOURS": ("scraping", "cache_ttl_hours"),
    "FOTMOB_METRICS_UPDATE_INTERVAL": ("scraping", "metrics_update_interval"),
    "FOTMOB_FILTER_BY_STATUS": ("scraping", "filter_by_status"),
    "FOTMOB_ALLOWED_MATCH_STATUSES": ("scraping", "allowed_match_statuses"),
    "FOTMOB_BRONZE_PATH": ("storage", "bronze_path"),
    "FOTMOB_STORAGE_ENABLED": ("storage", "enabled"),
    "FOTMOB_RETRY_MAX_ATTEMPTS": ("retry", "max_attempts"),
    "FOTMOB_RETRY_INITIAL_WAIT": ("retry", "initial_wait"),
    "FOTMOB_RETRY_MAX_WAIT": ("retry", "max_wait"),
    "FOTMOB_DATA_QUALITY_ENABLED": ("data_quality", "enabled"),
    "FOTMOB_DATA_QUALITY_FAIL_ON_ISSUES": ("data_quality", "fail_on_issues"),
    "FOTMOB_PROXY_ENABLED": ("proxy", "enabled"),
    "FOTMOB_PROXY_HTTP": ("proxy", "http"),
    "FOTMOB_PROXY_HTTPS": ("proxy", "https"),
}

_BOOL_KEYS = frozenset(
    {
        "enable_parallel",
        "enable_caching",
        "filter_by_status",
        "enabled",
        "fail_on_issues",
    }
)
_INT_KEYS = frozenset(
    {
        "timeout",
        "max_workers",
        "cache_ttl_hours",
        "metrics_update_interval",
        "max_attempts",
        "max_bytes",
        "backup_count",
    }
)
_FLOAT_KEYS = frozenset(
    {"delay_min", "delay_max", "initial_wait", "max_wait", "exponential_base", "backoff_factor"}
)


def _coerce_value(key: str, raw: str) -> Any:
    """Coerce a raw env-var string to the correct Python type."""
    if key in _BOOL_KEYS:
        return raw.lower() == "true"
    if key in _INT_KEYS:
        return int(raw)
    if key in _FLOAT_KEYS:
        return float(raw)
    if key == "allowed_match_statuses":
        return tuple(s.strip() for s in raw.split(","))
    return raw


def _load_yaml_fotmob() -> Dict[str, Any]:
    """Load the ``fotmob`` section from config.yaml, if it exists."""
    try:
        import yaml
    except ImportError:
        return {}

    config_path = os.getenv("CONFIG_FILE_PATH", "config.yaml")
    if not Path(config_path).exists():
        config_path = Path(__file__).parent.parent / "config.yaml"
    if not Path(config_path).exists():
        return {}

    with open(config_path, "r") as fh:
        data = yaml.safe_load(fh) or {}

    return data.get("fotmob", {})


def _build_fotmob_overrides() -> Dict[str, Any]:
    """Build a nested dict from FOTMOB_* env vars (env vars win over YAML)."""
    yaml_data = _load_yaml_fotmob()
    overrides: Dict[str, Any] = {}

    for env_name, (section, key) in _FOTMOB_ENV_MAP.items():
        raw = os.getenv(env_name)
        if raw is not None:
            overrides.setdefault(section, {})[key] = _coerce_value(key, raw)

    # Merge: YAML provides defaults, env-var overrides win
    merged: Dict[str, Any] = {}
    for section_name in (
        "api",
        "request",
        "scraping",
        "storage",
        "retry",
        "logging",
        "metrics",
        "data_quality",
        "proxy",
    ):
        section_data = yaml_data.get(section_name, {})
        env_data = overrides.get(section_name, {})
        merged[section_name] = {**section_data, **env_data}

    return merged


# ---------------------------------------------------------------------------
# Main Settings class
# ---------------------------------------------------------------------------


class Settings(BaseSettings):
    """Global application settings — single source of truth.

    Infrastructure fields are read from environment variables via
    pydantic-settings.  FotMob scraping fields are loaded from
    ``config.yaml`` with env-var overrides (see ``FotMobSettings``).
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="allow",
    )

    environment: Environment = Environment.DEVELOPMENT

    log_level: str = "INFO"
    log_dir: str = "logs"

    data_dir: str = "data"

    # ClickHouse
    clickhouse_host: str = "localhost"
    clickhouse_port: int = 8123
    clickhouse_user: str = "default"
    clickhouse_password: str = ""
    clickhouse_database: str = "default"
    clickhouse_db_fotmob: str = "fotmob"
    clickhouse_db_gold: str = "gold"
    clickhouse_db_gold_scenarios: str = "gold_scenarios"
    clickhouse_db_gold_signals: str = "gold_signals"

    # Feature flags
    enable_metrics: bool = True
    enable_health_checks: bool = True

    # Telegram
    telegram_enabled: bool = True
    telegram_bot_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None

    # YAML config path
    config_file_path: str = "config.yaml"

    # FotMob browser/proxy (kept for backward compat with .env)
    fotmob_browser_enabled: bool = False
    fotmob_proxy_enabled: bool = False
    fotmob_proxy_http: Optional[str] = None
    fotmob_proxy_https: Optional[str] = None

    # S3
    s3_endpoint: Optional[str] = None
    s3_access_key: Optional[str] = None
    s3_secret_key: Optional[str] = None

    # FotMob scraping configuration (nested)
    fotmob: FotMobSettings = FotMobSettings()

    @model_validator(mode="before")
    @classmethod
    def _load_fotmob_from_yaml(cls, values: Dict[str, Any]) -> Dict[str, Any]:
        """Merge YAML-based FotMob config with env-var overrides."""
        fotmob_overrides = _build_fotmob_overrides()
        existing_fotmob = values.get("fotmob")
        if isinstance(existing_fotmob, dict):
            # Deep merge: existing values < YAML < env vars
            for section, section_data in fotmob_overrides.items():
                if section in existing_fotmob:
                    if isinstance(existing_fotmob[section], dict):
                        existing_fotmob[section] = {**section_data, **existing_fotmob[section]}
                    else:
                        existing_fotmob[section] = section_data
                else:
                    existing_fotmob[section] = section_data
        else:
            values["fotmob"] = fotmob_overrides
        return values

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @property
    def is_development(self) -> bool:
        """Check if running in development environment."""
        return self.environment == Environment.DEVELOPMENT

    @property
    def is_production(self) -> bool:
        """Check if running in production environment."""
        return self.environment == Environment.PRODUCTION

    @property
    def is_testing(self) -> bool:
        """Check if running in testing environment."""
        return self.environment == Environment.TESTING

    def ensure_directories(self) -> None:
        """Create required directories if they don't exist."""
        Path(self.data_dir).mkdir(parents=True, exist_ok=True)
        Path(self.log_dir).mkdir(parents=True, exist_ok=True)

    def to_dict(self) -> dict:
        """Convert settings to dictionary."""
        return {
            "environment": self.environment.value,
            "log_level": self.log_level,
            "log_dir": self.log_dir,
            "data_dir": self.data_dir,
            "clickhouse_host": self.clickhouse_host,
            "clickhouse_port": self.clickhouse_port,
            "clickhouse_database": self.clickhouse_database,
            "clickhouse_db_fotmob": self.clickhouse_db_fotmob,
            "enable_metrics": self.enable_metrics,
            "enable_health_checks": self.enable_health_checks,
        }


# ---------------------------------------------------------------------------
# Lazy singleton
# ---------------------------------------------------------------------------

_settings: Optional[Settings] = None


def get_settings() -> Settings:
    """Return the cached ``Settings`` instance (created on first call)."""
    global _settings
    if _settings is None:
        _settings = Settings()
        _settings.ensure_directories()
    return _settings


def reset_settings() -> None:
    """Reset the cached settings (useful in tests)."""
    global _settings
    _settings = None


# Backward-compat module-level accessor (lazy)
def __getattr__(name: str):
    if name == "settings":
        return get_settings()
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = [
    "settings",
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
]
