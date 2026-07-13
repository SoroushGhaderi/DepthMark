"""Shared utilities for scraping scripts to reduce code duplication and improve performance.

This module centralizes common operations used across scraping scripts.
"""
import logging
import sys
from calendar import monthrange
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.common.logging import get_logger

DATE_FORMAT_COMPACT = "%Y%m%d"
DATE_FORMAT_MONTH = "%Y%m"
DATE_FORMAT_DISPLAY = "%Y-%m-%d"
MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
VALID_YEAR_RANGE = (2000, 2100)


@dataclass
class StepResult:
    """Result of a pipeline step execution."""

    name: str
    success: bool
    exit_code: int
    elapsed_time: float
    date_str: Optional[str] = None
    error_message: Optional[str] = None


@dataclass
class PipelineStats:
    """Statistics for pipeline execution."""

    dates_processed: int = 0
    dates_failed: int = 0
    total_matches: int = 0
    total_successful: int = 0
    total_failed: int = 0
    total_skipped: int = 0


@dataclass
class DateRangeInfo:
    """Information about a date range for display and logging."""

    dates: List[str]
    display_text: str
    mode_text: str
    log_suffix: str


class ScraperType(Enum):
    """Types of scrapers supported."""

    FOTMOB = "fotmob"


class PipelineMode(Enum):
    """Pipeline execution modes."""

    SINGLE_DATE = "single_date"
    DATE_RANGE = "date_range"
    MONTHLY = "monthly"


_PROJECT_ROOT: Optional[Path] = None
logger = get_logger(__name__)


def get_project_root() -> Path:
    """Get project root directory (cached for performance).

    Returns:
        Path to project root directory
    """
    global _PROJECT_ROOT
    if _PROJECT_ROOT is None:
        current_file = Path(__file__).resolve()
        _PROJECT_ROOT = current_file.parent.parent.parent
    return _PROJECT_ROOT


def add_project_to_path() -> None:
    """Add project root to Python path if not already present."""
    project_root = get_project_root()
    project_root_str = str(project_root)
    if project_root_str not in sys.path:
        sys.path.insert(0, project_root_str)


def validate_date_format(
    date_str: str, format_type: str = "YYYYMMDD"
) -> Tuple[bool, Optional[str]]:
    """
    Validate date string format.
    Args:
        date_str: Date string to validate
        format_type: Expected format ("YYYYMMDD" or "YYYYMM")
    Returns:
        Tuple of (is_valid, error_message)
    """
    if format_type == "YYYYMMDD":
        return _validate_full_date(date_str)
    elif format_type == "YYYYMM":
        return _validate_month_date(date_str)
    return False, f"Unknown format type: {format_type}"


def _validate_full_date(date_str: str) -> Tuple[bool, Optional[str]]:
    """Validate a full date string (YYYYMMDD format)."""
    if len(date_str) != 8 or not date_str.isdigit():
        return False, f"Invalid date format: {date_str}. Expected YYYYMMDD (e.g., 20251113)"
    try:
        year = int(date_str[:4])
        month = int(date_str[4:6])
        day = int(date_str[6:8])
        if not (1 <= month <= 12):
            return False, f"Invalid month: {month}. Must be between 01 and 12"
        if not (1 <= day <= 31):
            return False, f"Invalid day: {day}. Must be between 01 and 31"
        if not (VALID_YEAR_RANGE[0] <= year <= VALID_YEAR_RANGE[1]):
            return (
                False,
                f"Invalid year: {year}. Must be between {VALID_YEAR_RANGE[0]} and {VALID_YEAR_RANGE[1]}",
            )
        datetime(year, month, day)
        return True, None
    except ValueError as e:
        return False, f"Invalid date: {date_str}. {str(e)}"


def _validate_month_date(date_str: str) -> Tuple[bool, Optional[str]]:
    """Validate a month string (YYYYMM format)."""
    if len(date_str) != 6 or not date_str.isdigit():
        return False, f"Invalid month format: {date_str}. Expected YYYYMM (e.g., 202511)"
    try:
        year = int(date_str[:4])
        month = int(date_str[4:6])
        if not (1 <= month <= 12):
            return False, f"Invalid month: {month}. Must be between 01 and 12"
        if not (VALID_YEAR_RANGE[0] <= year <= VALID_YEAR_RANGE[1]):
            return (
                False,
                f"Invalid year: {year}. Must be between {VALID_YEAR_RANGE[0]} and {VALID_YEAR_RANGE[1]}",
            )
        return True, None
    except ValueError as e:
        return False, f"Invalid month: {date_str}. {str(e)}"


def generate_date_range(start_date: str, end_date: str) -> List[str]:
    """
    Generate list of dates between start and end (inclusive).
    Args:
        start_date: Start date in YYYYMMDD format
        end_date: End date in YYYYMMDD format
    Returns:
        List of date strings in YYYYMMDD format
    """
    start = datetime.strptime(start_date, DATE_FORMAT_COMPACT)
    end = datetime.strptime(end_date, DATE_FORMAT_COMPACT)
    dates = []
    current = start
    while current <= end:
        dates.append(current.strftime(DATE_FORMAT_COMPACT))
        current += timedelta(days=1)
    return dates


def generate_month_dates(month_str: str) -> List[str]:
    """
    Generate all dates in a month.
    Args:
        month_str: Month in YYYYMM format
    Returns:
        List of date strings in YYYYMMDD format
    """
    year = int(month_str[:4])
    month = int(month_str[4:6])
    _, last_day = monthrange(year, month)
    return [f"{year}{month:02d}{day:02d}" for day in range(1, last_day + 1)]


def extract_year_month(month_str: str) -> Tuple[str, str]:
    """
    Extract year and month from YYYYMM format.
    Args:
        month_str: Month in YYYYMM format
    Returns:
        Tuple of (year_str, month_str)
    """
    return month_str[:4], month_str[4:6]


def get_month_display_name(month_str: str) -> str:
    """
    Get display name for a month (e.g., "Nov 2025").
    Args:
        month_str: Month in YYYYMM format
    Returns:
        Display string like "Nov 2025"
    """
    year, month = extract_year_month(month_str)
    month_name = MONTH_NAMES[int(month) - 1]
    return f"{month_name} {year}"


def create_date_range_info(
    date: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    month: Optional[str] = None,
    num_days: Optional[int] = None,
) -> DateRangeInfo:
    """
    Create DateRangeInfo from various date arguments.
    Args:
        date: Single date in YYYYMMDD format
        start_date: Start date in YYYYMMDD format
        end_date: End date in YYYYMMDD format
        month: Month in YYYYMM format
        num_days: Number of days from start_date
    Returns:
        DateRangeInfo with dates list and display information
    """
    if month:
        dates = generate_month_dates(month)
        display_name = get_month_display_name(month)
        return DateRangeInfo(
            dates=dates,
            display_text=f"Month: {display_name} ({month})",
            mode_text=f"Monthly ({len(dates)} days)",
            log_suffix=month,
        )
    elif start_date:
        if num_days:
            end = datetime.strptime(start_date, DATE_FORMAT_COMPACT) + timedelta(days=num_days - 1)
            end_date = end.strftime(DATE_FORMAT_COMPACT)
        dates = generate_date_range(start_date, end_date)
        return DateRangeInfo(
            dates=dates,
            display_text=f"Range: {start_date} to {end_date}",
            mode_text=f"Range ({len(dates)} days)",
            log_suffix=f"{start_date}_to_{end_date}",
        )
    elif date:
        return DateRangeInfo(
            dates=[date], display_text=f"Date: {date}", mode_text="Single date", log_suffix=date
        )
    else:
        raise ValueError("Must provide date, start_date, or month")


class ImplicitWaitContext:
    """
    Context manager for temporaril in y changing Selenium implicit wait.
    More efficient than manually saving/restoring wait times.
    Usage:
        with ImplicitWaitContext(driver, 0):
            elements = driver.find_elements(By.CSS_SELECTOR, ".fast")
    """

    DEFAULT_WAIT = 10

    def __init__(self, driver, wait_seconds: float):
        """
        Initialize context manager.
        Args:
            driver: Selenium WebDriver instance
            wait_seconds: Temporary wait time in seconds
        """
        self.driver = driver
        self.new_wait = wait_seconds
        self.original_wait = self.DEFAULT_WAIT

    def __enter__(self):
        """Enter context: save current wait and set new wait."""
        try:
            self.driver.implicitly_wait(self.new_wait)
        except Exception:
            pass
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Exit context: restore original wait."""
        try:
            self.driver.implicitly_wait(self.original_wait)
        except Exception:
            pass
        return False


class PerformanceTimer:
    """
    Simple timer for performanc in e measurement.
    Usage:
        timer = PerformanceTimer("Operation name")
        timer.log_elapsed()
    """

    def __init__(self, operation_name: str, logger: Optional[logging.Logger] = None):
        """
        Initialize timer.
        Args:
            operation_name: Description of operation being timed
            logger: Optional logger (uses module logger if None)
        """
        self.operation_name = operation_name
        self.logger = logger
        self.start_time = datetime.now()

    def elapsed(self) -> float:
        """Get elapsed time in seconds."""
        return (datetime.now() - self.start_time).total_seconds()

    def log_elapsed(self, level: str = "info") -> None:
        """
        Log elapsed time.
        Args:
            level: Log level (info, debug, warning, error)
        """
        elapsed_time = self.elapsed()
        message = f"{self.operation_name} took {elapsed_time:.2f}s"
        if self.logger:
            log_func = getattr(self.logger, level, self.logger.info)
            log_func(message)
        else:
            getattr(logger, level, logger.info)(message)

    def __enter__(self):
        """Support context manager usage."""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Auto-log on context exit."""
        self.log_elapsed()
        return False


def format_elapsed_time(seconds: float) -> str:
    """
    Format elapsed time for displa in y.
    Args:
        seconds: Time in seconds
    Returns:
        Formatted string like "1.5s" or "2.3 minutes"
    """
    if seconds < 60:
        return f"{seconds:.1f}s"
        return f"{seconds:.1f}s ({seconds/60:.1f} minutes)"


def print_header(title: str, char: str = "=", width: int = 80) -> None:
    """Log a formatted header line."""
    logger.info("%s", "\n" + char * width)
    logger.info("%s", title)
    logger.info("%s", char * width)


def print_separator(char: str = "-", width: int = 80) -> None:
    """Log a separator line."""
    logger.info("%s", char * width)


def log_header(logger: logging.Logger, title: str, char: str = "=", width: int = 80) -> None:
    """Log a formatted header line."""
    logger.info("\n" + char * width)
    logger.info(title)
    logger.info(char * width)


def format_stats_summary(stats: Dict[str, Any], indent: int = 2) -> str:
    """
    Format statistics dictionary as a summary string.
    Args:
        stats: Dictionary of statistics
        indent: Number of spaces for indentatio in n
    Returns:
        Formatted multi-line string
    """
    lines = []
    prefix = " " * indent
    for key, value in stats.items():
        if isinstance(value, int):
            lines.append(f"{prefix}{key}: {value:,}")
        elif isinstance(value, float):
            lines.append(f"{prefix}{key}: {value:.2f}")
        else:
            lines.append(f"{prefix}{key}: {value}")
    return "\n".join(lines)
