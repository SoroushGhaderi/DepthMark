import threading
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional

from src.oddspedia.scraping.logging import get_logger


logger = get_logger(__name__)


@dataclass
class Metrics:
    """Thread-safe metrics collector for a scraping run."""

    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)
    _context: Dict[str, object] = field(default_factory=dict, repr=False)

    phase_1_total: int = 0
    phase_1_success: int = 0
    phase_1_duration_seconds: int = 0

    phase_2_total: int = 0
    phase_2_success: int = 0
    phase_2_duration_seconds: int = 0
    phase_2_skipped: int = 0
    phase_2_failed: int = 0

    page_load_time_ms: List[int] = field(default_factory=list)

    cloudflare_challenges: int = 0
    cloudflare_timeouts: int = 0

    scrape_errors: Dict[str, int] = field(default_factory=dict)

    odds_markets_by_type: Dict[str, int] = field(default_factory=dict)
    odds_extraction_success: int = 0
    odds_extraction_failed: int = 0
    live_odds_extraction_success: int = 0
    live_odds_extraction_failed: int = 0

    validation_failures: int = 0

    circuit_breaker_paused: int = 0
    circuit_breaker_aborted: bool = False

    start_time: datetime = field(default_factory=datetime.now)
    end_time: Optional[datetime] = None

    def _increment(self, counter_name: str, value: int = 1) -> None:
        with self._lock:
            current = getattr(self, counter_name, 0)
            setattr(self, counter_name, current + value)

    def _inc_dict(self, dict_name: str, key: str, value: int = 1) -> None:
        with self._lock:
            d = getattr(self, dict_name)
            d[key] = d.get(key, 0) + value

    def phase1_start(self) -> None:
        self.start_time = datetime.now()

    def phase1_complete(self, total: int, success: int, duration_seconds: int) -> None:
        self.phase_1_total = total
        self.phase_1_success = success
        self.phase_1_duration_seconds = duration_seconds

    def phase2_start(self, total: int = 0) -> None:
        with self._lock:
            self.phase_2_total = total
            self.phase_2_success = 0
            self.phase_2_skipped = 0

    def record_phase2_success(self) -> None:
        self._increment("phase_2_success")

    def record_phase2_skip(self) -> None:
        self._increment("phase_2_skipped")

    def record_phase2_failure(self) -> None:
        self._increment("phase_2_failed")

    def set_context(self, **context: object) -> None:
        """Attach run metadata to the snapshot stored in each date manifest."""
        with self._lock:
            self._context = dict(context)

    def phase2_complete(self, total: int, success: int, skipped: int, duration_seconds: int) -> None:
        with self._lock:
            self.phase_2_total = total
            self.phase_2_success = success
            self.phase_2_skipped = skipped
            self.phase_2_duration_seconds = duration_seconds

    def sync_phase2_progress(self, success: int, skipped: int, failed: int) -> None:
        """Checkpoint authoritative Sport-Date Scrape state from the manifest."""
        with self._lock:
            self.phase_2_success = success
            self.phase_2_skipped = skipped
            self.phase_2_failed = failed

    def record_page_load(self, duration_ms: int) -> None:
        with self._lock:
            self.page_load_time_ms.append(duration_ms)

    def record_cloudflare_challenge(self) -> None:
        self._increment("cloudflare_challenges")

    def record_cloudflare_timeout(self) -> None:
        self._increment("cloudflare_timeouts")

    def record_scrape_error(self, error_type: str) -> None:
        self._inc_dict("scrape_errors", error_type)

    def record_odds_market(self, market_type: str) -> None:
        self._inc_dict("odds_markets_by_type", market_type)

    def record_odds_extraction(self, success: bool, is_live: bool = False) -> None:
        if is_live:
            if success:
                self._increment("live_odds_extraction_success")
            else:
                self._increment("live_odds_extraction_failed")
        else:
            if success:
                self._increment("odds_extraction_success")
            else:
                self._increment("odds_extraction_failed")

    def record_validation_failure(self) -> None:
        self._increment("validation_failures")

    def record_circuit_breaker_pause(self) -> None:
        self._increment("circuit_breaker_paused")

    def record_circuit_breaker_abort(self) -> None:
        with self._lock:
            self.circuit_breaker_aborted = True

    def finish(self) -> None:
        self.end_time = datetime.now()

    @property
    def total_duration_seconds(self) -> int:
        if self.end_time:
            return int((self.end_time - self.start_time).total_seconds())
        return int((datetime.now() - self.start_time).total_seconds())

    @property
    def avg_page_load_ms(self) -> float:
        if self.page_load_time_ms:
            return sum(self.page_load_time_ms) / len(self.page_load_time_ms)
        return 0.0

    @property
    def phase1_success_rate(self) -> float:
        if self.phase_1_total:
            return self.phase_1_success / self.phase_1_total * 100
        return 0.0

    @property
    def phase2_success_rate(self) -> float:
        if self.phase_2_total:
            return self.phase_2_success / self.phase_2_total * 100
        return 0.0

    @property
    def odds_success_rate(self) -> float:
        total = self.odds_extraction_success + self.odds_extraction_failed
        if total:
            return self.odds_extraction_success / total * 100
        return 0.0

    @property
    def live_odds_success_rate(self) -> float:
        total = self.live_odds_extraction_success + self.live_odds_extraction_failed
        if total:
            return self.live_odds_extraction_success / total * 100
        return 0.0

    @property
    def phase2_completed_progress(self) -> float:
        if self.phase_2_total == 0:
            return 0.0
        terminal = self.phase_2_success + self.phase_2_skipped
        return round((terminal / self.phase_2_total) * 100, 2)

    def to_dict(self) -> Dict:
        return {
            "run": {
                "start": self.start_time.isoformat(),
                "end": self.end_time.isoformat() if self.end_time else None,
                "duration_seconds": self.total_duration_seconds,
            },
            "event_discovery": {
                "total": self.phase_1_total,
                "success": self.phase_1_success,
                "success_rate_pct": round(self.phase1_success_rate, 2),
                "duration_seconds": self.phase_1_duration_seconds,
            },
            "match_detail_extraction": {
                "total": self.phase_2_total,
                "success": self.phase_2_success,
                "skipped": self.phase_2_skipped,
                "failed": self.phase_2_failed,
                "success_rate_pct": round(self.phase2_success_rate, 2),
                "completed_progress_pct": self.phase2_completed_progress,
                "duration_seconds": self.phase_2_duration_seconds,
            },
            "performance": {
                "avg_page_load_ms": round(self.avg_page_load_ms, 2),
                "page_load_samples": len(self.page_load_time_ms),
            },
            "cloudflare": {
                "challenges": self.cloudflare_challenges,
                "timeouts": self.cloudflare_timeouts,
            },
            "odds": {
                "success_rate_pct": round(self.odds_success_rate, 2),
                "markets_by_type": dict(self.odds_markets_by_type),
            },
            "live_odds": {
                "success_rate_pct": round(self.live_odds_success_rate, 2),
            },
            "errors": dict(self.scrape_errors),
            "validation_failures": self.validation_failures,
            "circuit_breaker": {
                "paused_count": self.circuit_breaker_paused,
                "aborted": self.circuit_breaker_aborted,
            },
        }

    def manifest_snapshot(self) -> Dict:
        """Return the latest run summary for embedding in a scrape manifest."""
        with self._lock:
            context = dict(self._context)
        return {**self.to_dict(), **context}

    def log_summary(self) -> None:
        logger.info(
            "run_summary",
            **self.to_dict(),
        )

_global_metrics: Optional[Metrics] = None


def get_metrics() -> Metrics:
    """Get or create the global metrics instance."""
    global _global_metrics
    if _global_metrics is None:
        _global_metrics = Metrics()
    return _global_metrics


def reset_metrics() -> None:
    """Reset the global metrics for a new run."""
    global _global_metrics
    _global_metrics = Metrics()
