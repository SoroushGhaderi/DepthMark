"""Typed dataclasses for Telegram message payloads.

Each message family has its own dataclass. Callers construct an instance and pass
it to ``TelegramClient.render_and_send()``.
"""

from dataclasses import dataclass, field
from typing import Any, Dict, List


@dataclass
class DailyReportData:
    """Payload for the daily FotMob scrape report."""

    date: str
    matches_scraped: int = 0
    matches_total: int = 0
    skipped: int = 0
    errors: int = 0
    duration_seconds: float = 0.0
    bronze_files: int = 0
    bronze_size_mb: float = 0.0
    avg_response_time: float = 0.0
    max_response_time: float = 0.0
    retries: int = 0
    failed_retries: int = 0
    cache_hits: int = 0
    s3_uploaded: bool = False
    s3_size_mb: float = 0.0
    clickhouse_rows: int = 0
    silent: bool = True


@dataclass
class MonthlyReportData:
    """Payload for the monthly FotMob summary."""

    year_month: str
    dates_processed: int = 0
    dates_total: int = 0
    total_matches: int = 0
    matches_scraped: int = 0
    errors: int = 0
    duration_seconds: float = 0.0
    bronze_files: int = 0
    bronze_size_mb: float = 0.0
    s3_archives: int = 0
    s3_size_mb: float = 0.0
    silent: bool = True


@dataclass
class LayerAlertData:
    """Payload for a layer completion alert (bronze / silver / gold / quality)."""

    layer: str
    success: bool
    scope: str
    duration_seconds: float = 0.0
    details: Dict[str, Any] = field(default_factory=dict)
    insights: Dict[str, Any] = field(default_factory=dict)
    entity_coverage: List[Dict[str, Any]] = field(default_factory=list)
    missing_count: int = 0
    avg_coverage: float = 0.0
    min_coverage: float = 0.0
    silent: bool = False


@dataclass
class PipelineSummaryData:
    """Payload for the pipeline completion summary."""

    date: str
    success: bool
    total_duration_seconds: float = 0.0
    steps: List[Dict[str, Any]] = field(default_factory=list)
    dates_processed: int = 0
    dates_total: int = 0
    silent: bool = False


@dataclass
class ErrorAlertData:
    """Payload for an error / failure alert."""

    level: str
    title: str
    message: str
    timestamp: str = ""
    context: Dict[str, Any] = field(default_factory=dict)
    action_hint: str = ""
    silent: bool = False
