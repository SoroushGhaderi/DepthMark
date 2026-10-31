"""Unified configuration management for DepthMark project.

Single source of truth for all configuration. Loads from:
1. .env file - Environment variables (pydantic-settings)
2. config.yaml - Application settings (YAML fallback for FotMob scraping config)

Precedence, highest first: constructor arguments, process environment
variables, the documented flat FotMob/Oddspedia variables in
:data:`NESTED_ENV_ALIASES` (e.g. ``FOTMOB_X_MAS_TOKEN``), ``.env`` files, the
``fotmob`` and ``oddspedia`` sections of ``config.yaml``, then field defaults.
Nested fields can also be set with ``__`` (e.g. ``FOTMOB__API__BASE_URL``).
pydantic validates and coerces every value; no module reads ``os.environ``
for application configuration.

Usage:
    from config.settings import get_settings, Environment

    settings = get_settings()

    if settings.environment == Environment.PRODUCTION:
        logger.info("Running in production")

    logger.info("ClickHouse host: %s", settings.clickhouse_host)
"""

import os
from enum import StrEnum
from pathlib import Path
from typing import Any

from pydantic import AliasChoices, BaseModel, Field, field_validator
from pydantic.fields import FieldInfo
from pydantic_settings import (
    BaseSettings,
    PydanticBaseSettingsSource,
    SettingsConfigDict,
    YamlConfigSettingsSource,
)

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Environment enum
# ---------------------------------------------------------------------------


class Environment(StrEnum):
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
    user_agents: list[str] = []


class FotMobRequestSettings(BaseModel):
    """HTTP request throttling settings."""

    timeout: int = 30
    delay_min: float = 2.0
    delay_max: float = 4.0


class FotMobScrapingSettings(BaseModel):
    """Scraping behaviour settings."""

    metrics_update_interval: int = 20
    filter_by_status: bool = True
    allowed_match_statuses: tuple[str, ...] = (
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
    # Timezone FotMob uses to assign matches to a calendar date.
    timezone: str = "Asia/Tehran"

    @field_validator("allowed_match_statuses", mode="before")
    @classmethod
    def split_comma_separated(cls, value: Any) -> Any:
        if isinstance(value, str):
            return tuple(status.strip() for status in value.split(",") if status.strip())
        return value


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
    status_codes: tuple[int, ...] = (429, 500, 502, 503, 504)


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


class OddspediaSettings(BaseModel):
    """Oddspedia browser-scraper settings and source-artifact root."""

    base_url: str = "https://oddspedia.com"
    scraper_env: str = "development"
    min_delay: float = 3.0
    max_delay: float = 7.0
    worker_min_delay: float = 5.0
    worker_max_delay: float = 8.0
    scroll_pause: float = 2.0
    page_load_timeout: int = 60
    cloudflare_wait: int = 40
    data_dir: str = "data/oddspedia"
    # Explicit browser binaries; None means discover them on the host.
    chrome_binary: str | None = None
    chromedriver_path: str | None = None

    @field_validator("max_delay")
    @classmethod
    def max_delay_gte_min(cls, value: float, info):
        if "min_delay" in info.data and value < info.data["min_delay"]:
            raise ValueError("max_delay must be >= min_delay")
        return value

    @field_validator("worker_max_delay")
    @classmethod
    def worker_max_delay_gte_min(cls, value: float, info):
        if "worker_min_delay" in info.data and value < info.data["worker_min_delay"]:
            raise ValueError("worker_max_delay must be >= worker_min_delay")
        return value


# ---------------------------------------------------------------------------
# Configuration sources
# ---------------------------------------------------------------------------

# Documented flat environment names for nested fields, kept for existing .env
# files and deployments. Values are raw strings; pydantic coerces them.
NESTED_ENV_ALIASES: dict[str, tuple[str, ...]] = {
    "FOTMOB_X_MAS_TOKEN": ("fotmob", "api", "x_mas_token"),
    "FOTMOB_COOKIES": ("fotmob", "api", "cookies"),
    "FOTMOB_USER_AGENT": ("fotmob", "api", "user_agent"),
    "FOTMOB_API_BASE_URL": ("fotmob", "api", "base_url"),
    "FOTMOB_REQUEST_TIMEOUT": ("fotmob", "request", "timeout"),
    "FOTMOB_DELAY_MIN": ("fotmob", "request", "delay_min"),
    "FOTMOB_DELAY_MAX": ("fotmob", "request", "delay_max"),
    "FOTMOB_ENABLE_CACHING": ("fotmob", "scraping", "enable_caching"),
    "FOTMOB_CACHE_TTL_HOURS": ("fotmob", "scraping", "cache_ttl_hours"),
    "FOTMOB_METRICS_UPDATE_INTERVAL": ("fotmob", "scraping", "metrics_update_interval"),
    "FOTMOB_FILTER_BY_STATUS": ("fotmob", "scraping", "filter_by_status"),
    "FOTMOB_ALLOWED_MATCH_STATUSES": ("fotmob", "scraping", "allowed_match_statuses"),
    "FOTMOB_TIMEZONE": ("fotmob", "scraping", "timezone"),
    "FOTMOB_BRONZE_PATH": ("fotmob", "storage", "bronze_path"),
    "FOTMOB_STORAGE_ENABLED": ("fotmob", "storage", "enabled"),
    "FOTMOB_RETRY_MAX_ATTEMPTS": ("fotmob", "retry", "max_attempts"),
    "FOTMOB_RETRY_INITIAL_WAIT": ("fotmob", "retry", "initial_wait"),
    "FOTMOB_RETRY_MAX_WAIT": ("fotmob", "retry", "max_wait"),
    "FOTMOB_DATA_QUALITY_ENABLED": ("fotmob", "data_quality", "enabled"),
    "FOTMOB_DATA_QUALITY_FAIL_ON_ISSUES": ("fotmob", "data_quality", "fail_on_issues"),
    "FOTMOB_PROXY_ENABLED": ("fotmob", "proxy", "enabled"),
    "FOTMOB_PROXY_HTTP": ("fotmob", "proxy", "http"),
    "FOTMOB_PROXY_HTTPS": ("fotmob", "proxy", "https"),
    "ODDSPEDIA_BASE_URL": ("oddspedia", "base_url"),
    "ODDSPEDIA_SCRAPER_ENV": ("oddspedia", "scraper_env"),
    "ODDSPEDIA_MIN_DELAY": ("oddspedia", "min_delay"),
    "ODDSPEDIA_MAX_DELAY": ("oddspedia", "max_delay"),
    "ODDSPEDIA_WORKER_MIN_DELAY": ("oddspedia", "worker_min_delay"),
    "ODDSPEDIA_WORKER_MAX_DELAY": ("oddspedia", "worker_max_delay"),
    "ODDSPEDIA_SCROLL_PAUSE": ("oddspedia", "scroll_pause"),
    "ODDSPEDIA_PAGE_LOAD_TIMEOUT": ("oddspedia", "page_load_timeout"),
    "ODDSPEDIA_CLOUDFLARE_WAIT": ("oddspedia", "cloudflare_wait"),
    "ODDSPEDIA_DATA_DIR": ("oddspedia", "data_dir"),
    # The first variable set wins, so the source-specific name beats the image default.
    "CHROME_BIN": ("oddspedia", "chrome_binary"),
    "ODDSPEDIA_CHROME_BIN": ("oddspedia", "chrome_binary"),
    "CHROMEDRIVER_PATH": ("oddspedia", "chromedriver_path"),
    "ODDSPEDIA_CHROMEDRIVER_PATH": ("oddspedia", "chromedriver_path"),
}
YAML_SECTIONS = ("fotmob", "oddspedia")


class NestedEnvAliasSource(PydanticBaseSettingsSource):
    """Read :data:`NESTED_ENV_ALIASES` from the process environment into nested values."""

    def get_field_value(self, field: FieldInfo, field_name: str) -> tuple[Any, str, bool]:
        return None, field_name, False

    def __call__(self) -> dict[str, Any]:
        values: dict[str, Any] = {}
        for env_name, path in NESTED_ENV_ALIASES.items():
            raw = os.environ.get(env_name)
            if raw is None:
                continue
            node = values
            for key in path[:-1]:
                node = node.setdefault(key, {})
            node[path[-1]] = raw
        return values


class ScraperYamlSource(YamlConfigSettingsSource):
    """Read only the ``fotmob`` and ``oddspedia`` sections of ``config.yaml``."""

    def __call__(self) -> dict[str, Any]:
        data = super().__call__()
        return {section: data[section] for section in YAML_SECTIONS if section in data}


def config_file_path() -> Path:
    """Return ``CONFIG_FILE_PATH``, else ``config.yaml`` in the cwd or the checkout."""
    configured = Path(os.environ.get("CONFIG_FILE_PATH", "config.yaml"))
    return configured if configured.exists() else PROJECT_ROOT / "config.yaml"


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
        # The checkout's .env wins over one in its parent directory.
        env_file=(PROJECT_ROOT.parent / ".env", PROJECT_ROOT / ".env"),
        env_file_encoding="utf-8",
        env_nested_delimiter="__",
        case_sensitive=False,
        extra="allow",
    )

    environment: Environment = Environment.DEVELOPMENT
    # Deployment selector used by the local-credential guard and log rendering;
    # None when no selector is set anywhere (unlike ``environment``'s default).
    deployment_environment: str | None = Field(
        default=None,
        validation_alias=AliasChoices("DEPTHMARK_ENV", "ENVIRONMENT", "SCRAPER_ENV"),
    )

    log_level: str = "INFO"
    log_dir: str = "logs"

    data_dir: str = "data"

    # ClickHouse
    clickhouse_host: str = "localhost"
    clickhouse_port: int = 8123
    clickhouse_user: str = "default"
    clickhouse_password: str = ""
    # Maintenance identity (ADR 0029): setup, full-history swaps, and maintenance
    # commands. The application identity above has no DDL rights on warehouse tables.
    clickhouse_maintenance_user: str | None = None
    clickhouse_maintenance_password: str = ""
    clickhouse_database: str = "default"
    clickhouse_db_fotmob: str = "fotmob"
    clickhouse_db_gold: str = "gold"
    clickhouse_db_gold_scenarios: str = "gold_scenarios"
    clickhouse_db_gold_signals: str = "gold_signals"
    # Redirect Gold job output to another database (testing and backfills).
    clickhouse_gold_target_db: str | None = None

    # Feature flags
    enable_metrics: bool = True
    enable_health_checks: bool = True

    # Telegram
    telegram_enabled: bool = True
    telegram_bot_token: str | None = None
    telegram_chat_id: str | None = None

    # YAML config path
    config_file_path: str = "config.yaml"

    # FotMob browser/proxy (kept for backward compat with .env)
    fotmob_browser_enabled: bool = False
    fotmob_proxy_enabled: bool = False
    fotmob_proxy_http: str | None = None
    fotmob_proxy_https: str | None = None

    # MongoDB content/catalog store
    mongodb_host: str = "localhost"
    mongodb_port: int = 27017
    mongodb_user: str | None = None
    mongodb_password: str | None = None
    mongodb_database: str = "orbit_content"
    mongodb_auth_source: str = "admin"
    mongodb_uri: str | None = None

    # S3
    s3_endpoint: str | None = None
    s3_access_key: str | None = None
    s3_secret_key: str | None = None
    s3_region: str | None = None
    s3_bucket: str | None = None

    # FotMob scraping configuration (nested)
    fotmob: FotMobSettings = FotMobSettings()
    oddspedia: OddspediaSettings = OddspediaSettings()

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: type[BaseSettings],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
    ) -> tuple[PydanticBaseSettingsSource, ...]:
        return (
            init_settings,
            env_settings,
            NestedEnvAliasSource(settings_cls),
            dotenv_settings,
            ScraperYamlSource(settings_cls, yaml_file=config_file_path()),
            file_secret_settings,
        )

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

_settings: Settings | None = None


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


__all__ = [  # noqa: F822 - "settings" resolves lazily via __getattr__
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
    "OddspediaSettings",
    "NESTED_ENV_ALIASES",
]
