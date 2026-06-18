"""Metrics tracking for scraper performance."""
from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import List, Dict, Any, Optional
from .logging_utils import get_logger

logger = get_logger(__name__)


@dataclass
class ScraperMetrics:
    """Track scraper performance metrics."""
    date: str
    total_matches: int = 0
    successful_matches: int = 0
    failed_matches: int = 0
    skipped_matches: int = 0
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    errors: List[Dict[str, Any]] = field(default_factory=list)
    warnings: List[Dict[str, Any]] = field(default_factory=list)
    data_quality_issues: List[Dict[str, Any]] = field(default_factory=list)

    def start(self):
        """Mark the start of scraping."""
        self.start_time = datetime.now()

    def end(self):
        """Mark the end of scraping."""
        self.end_time = datetime.now()

    def record_success(
        self, match_id: str, processing_time: Optional[float] = None
    ):
        """Record a successful match scrape."""
        self.successful_matches += 1

    def record_failure(
        self, match_id: str, error: str, error_type: Optional[str] = None
    ):
        """Record a failed match scrape."""
        self.failed_matches += 1
        self.errors.append({
            'match_id': match_id,
            'error': str(error),
            'error_type': error_type or 'Unknown',
            'timestamp': datetime.now().isoformat()
        })

    def record_skip(self, match_id: str, reason: str):
        """Record a skipped match."""
        self.skipped_matches += 1
        self.warnings.append({
            'match_id': match_id,
            'reason': reason,
            'timestamp': datetime.now().isoformat()
        })

    def record_data_quality_issue(self, match_id: str, issues: List[str]):
        """Record data quality issues."""
        self.data_quality_issues.append({
            'match_id': match_id,
            'issues': issues,
            'timestamp': datetime.now().isoformat()
        })

    def get_duration_seconds(self) -> Optional[float]:
        """Get scraping duration in seconds."""
        if self.start_time and self.end_time:
            return (self.end_time - self.start_time).total_seconds()
        return None

    def get_success_rate(self) -> float:
        """Calculate success rate."""
        total_attempted = self.successful_matches + self.failed_matches
        if total_attempted == 0:
            return 0.0
        return round((self.successful_matches / total_attempted) * 100, 2)

    def to_dict(self) -> Dict[str, Any]:
        """Convert metrics to dictionary."""
        data = asdict(self)
        if self.start_time:
            data['start_time'] = self.start_time.isoformat()
        if self.end_time:
            data['end_time'] = self.end_time.isoformat()
        data['duration_seconds'] = self.get_duration_seconds()
        data['success_rate'] = self.get_success_rate()
        data['total_attempted'] = self.successful_matches + self.failed_matches
        return data

    def save_metrics(self, output_dir: str = "metrics"):
        """Metrics persistence is disabled; do not write metrics files."""
        _ = output_dir
        logger.debug("Metrics persistence disabled; skipping save_metrics()")
        return None

    def print_summary(self):
        """Log a summary of the metrics."""
        duration = self.get_duration_seconds()
        duration_str = f"{duration:.2f}s" if duration else "N/A"
        logger.info("%s", "\n" + "=" * 60)
        logger.info("SCRAPER METRICS SUMMARY - %s", self.date)
        logger.info("%s", "=" * 60)
        logger.info("Total Matches:      %s", self.total_matches)
        logger.info("Successful:         %s", self.successful_matches)
        logger.info("Failed:             %s", self.failed_matches)
        logger.info("Skipped:            %s", self.skipped_matches)
        logger.info("Success Rate:       %s%%", self.get_success_rate())
        logger.info("Duration:           %s", duration_str)
        if self.errors:
            logger.info("Errors:             %s", len(self.errors))
            for error in self.errors[:3]:
                logger.info("  - Match %s: %s", error["match_id"], error["error"][:80])
            if len(self.errors) > 3:
                logger.info("  ...and %s more", len(self.errors) - 3)
        if self.data_quality_issues:
            logger.info("Data Quality Issues: %s", len(self.data_quality_issues))
        logger.info("%s", "=" * 60 + "\n")


@dataclass
class MatchMetrics:
    """Track metrics for a single match."""
    match_id: str
    start_time: datetime = field(default_factory=datetime.now)
    end_time: Optional[datetime] = None
    success: bool = False
    error: Optional[str] = None
    goals_count: int = 0
    players_count: int = 0
    shots_count: int = 0

    def complete(self, success: bool = True, error: Optional[str] = None):
        """Mark the match processing as complete."""
        self.end_time = datetime.now()
        self.success = success
        self.error = error

    def get_duration_seconds(self) -> Optional[float]:
        """Get processing duration in seconds."""
        if self.end_time:
            return (self.end_time - self.start_time).total_seconds()
        return None
