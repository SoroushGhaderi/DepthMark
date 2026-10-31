"""Shared display helpers for the FotMob scrape and pipeline commands."""

from dataclasses import dataclass
from datetime import datetime, timedelta

from src.common.dates import (
    DATE_FORMAT_COMPACT,
    extract_year_month,
    inclusive_date_ids,
    month_date_ids,
)
from src.common.logging import get_logger

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

logger = get_logger(__name__)


@dataclass
class DateRangeInfo:
    """Information about a date range for display and logging."""

    dates: list[str]
    display_text: str
    mode_text: str
    log_suffix: str


def get_month_display_name(month_str: str) -> str:
    """Return a month label such as ``Nov 2025`` for ``202511``."""
    year, month = extract_year_month(month_str)
    return f"{MONTH_NAMES[int(month) - 1]} {year}"


def create_date_range_info(
    date: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    month: str | None = None,
    num_days: int | None = None,
) -> DateRangeInfo:
    """Build the dates and display text for a date, range, or month selection."""
    if month:
        dates = month_date_ids(month)
        return DateRangeInfo(
            dates=dates,
            display_text=f"Month: {get_month_display_name(month)} ({month})",
            mode_text=f"Monthly ({len(dates)} days)",
            log_suffix=month,
        )
    if start_date:
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
    if date:
        return DateRangeInfo(
            dates=[date], display_text=f"Date: {date}", mode_text="Single date", log_suffix=date
        )
    raise ValueError("Must provide date, start_date, or month")


def format_elapsed_time(seconds: float) -> str:
    """Format a duration as ``12.3s`` or ``754.0s (12.6 minutes)``."""
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
