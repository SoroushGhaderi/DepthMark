"""Shared helpers for the FotMob scrape and pipeline commands."""

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum
from typing import Any

from selenium.common.exceptions import WebDriverException

from src.common.dates import (
    DATE_FORMAT_COMPACT,
    inclusive_date_ids,
    month_date_ids,
)
from src.common.logging import get_logger

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


@dataclass
class StepResult:
    """Result of a pipeline step execution."""

    name: str
    success: bool
    exit_code: int
    elapsed_time: float
    date_str: str | None = None
    error_message: str | None = None


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

    dates: list[str]
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


logger = get_logger(__name__)


def extract_year_month(month_str: str) -> tuple[str, str]:
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
    date: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    month: str | None = None,
    num_days: int | None = None,
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
        dates = month_date_ids(month)
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
        dates = inclusive_date_ids(start_date, end_date)
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
    Context manager for temporarily changing Selenium implicit wait.
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
        except WebDriverException:
            logger.debug("Could not set implicit wait", exc_info=True)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Exit context: restore original wait."""
        try:
            self.driver.implicitly_wait(self.original_wait)
        except WebDriverException:
            logger.debug("Could not restore implicit wait", exc_info=True)
        return False


class PerformanceTimer:
    """
    Simple timer for performanc in e measurement.
    Usage:
        timer = PerformanceTimer("Operation name")
        timer.log_elapsed()
    """

    def __init__(self, operation_name: str, logger: logging.Logger | None = None):
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
        return f"{seconds:.1f}s ({seconds / 60:.1f} minutes)"


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


def format_stats_summary(stats: dict[str, Any], indent: int = 2) -> str:
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
