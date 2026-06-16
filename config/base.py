"""Base configuration utilities for DepthMark.

This module previously contained the abstract ``BaseConfig`` class and
dataclass-based config models.  Configuration has been unified into
:class:`~config.settings.Settings` (pydantic-settings).  The dataclass
types are retained as lightweight type aliases for any code that still
references them, but new code should use the pydantic models in
``config.settings`` directly.
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import List


@dataclass
class StorageConfig:
    """Legacy storage config (use ``FotMobStorageSettings`` instead)."""

    bronze_path: str = ""
    enabled: bool = True

    def ensure_directories(self) -> None:
        if not self.enabled:
            return
        if self.bronze_path:
            Path(self.bronze_path).mkdir(parents=True, exist_ok=True)


@dataclass
class LoggingConfig:
    """Legacy logging config (use ``FotMobLoggingSettings`` instead)."""

    level: str = "INFO"
    format: str = (
        "%(asctime)s - %(name)s - %(levelname)s - "
        "%(funcName)s:%(lineno)d - %(message)s"
    )
    file: str = "logs/scraper.log"
    max_bytes: int = 10485760
    backup_count: int = 5
    dir: str = "logs"

    def ensure_directories(self) -> None:
        Path(self.dir).mkdir(parents=True, exist_ok=True)
        Path(self.file).parent.mkdir(parents=True, exist_ok=True)


@dataclass
class MetricsConfig:
    """Legacy metrics config (use ``FotMobMetricsSettings`` instead)."""

    enabled: bool = False
    export_path: str = "metrics"
    export_format: str = "json"


@dataclass
class RetryConfig:
    """Legacy retry config (use ``FotMobRetrySettings`` instead)."""

    max_attempts: int = 3
    initial_wait: float = 2.0
    max_wait: float = 10.0
    exponential_base: float = 2.0
    backoff_factor: float = 2.0
    status_codes: tuple = field(
        default_factory=lambda: (429, 500, 502, 503, 504)
    )


__all__ = [
    "StorageConfig",
    "LoggingConfig",
    "MetricsConfig",
    "RetryConfig",
]
