"""
Date utility functions and constants for consistent date handling.

Replaces magic numbers and hardcoded string slicing with proper constants and functions.
"""
from datetime import datetime

DATE_FORMAT_COMPACT = "%Y%m%d"
DATE_FORMAT_DISPLAY = "%Y-%m-%d"
DATE_FORMAT_MONTH = "%Y%m"
YEAR_START = 0
YEAR_END = 4
MONTH_START = 4
MONTH_END = 6
DAY_START = 6
DAY_END = 8


def format_date_compact_to_display(date_str: str) -> str:
    """
    Convert date from YYYYMMDD format to YYYY-MM-DD format.
    Args:
        date_str: Date string in YYYYMMDD format (e.g., "20251113")
    Returns:
        Date string in YYYY-MM-DD format (e.g., "2025-11-13")
    Examples:
        >>> format_date_compact_to_display("20251113")
        '2025-11-13'
        >>> format_date_compact_to_display("20250101")
        '2025-01-01'
    """
    if len(date_str) < 8:
        raise ValueError(f"Date string must be at least 8 characters (YYYYMMDD), got: {date_str}")
    year = date_str[YEAR_START:YEAR_END]
    month = date_str[MONTH_START:MONTH_END]
    day = date_str[DAY_START:DAY_END]
    return f"{year}-{month}-{day}"


def format_date_compact_to_display_partial(date_str: str) -> str:
    """
    Convert date from YYYYMMDD format to YYYY-MM-DD format.
    Handles partial dates (e.g., if date_str is longer than 8 chars, uses first 8).
    Args:
        date_str: Date string in YYYYMMDD format or longer (e.g., "20251113" or "20251113123456")
    Returns:
        Date string in YYYY-MM-DD format (e.g., "2025-11-13")
    """
    if len(date_str) < 8:
        raise ValueError(f"Date string must be at least 8 characters (YYYYMMDD), got: {date_str}")
    date_part = date_str[:8]
    return format_date_compact_to_display(date_part)


def parse_compact_date(date_str: str) -> datetime:
    """
    Parse date string in YYYYMMDD format to datetime object.
    Args:
        date_str: Date string in YYYYMMDD format
    Returns:
        datetime object
    """
    return datetime.strptime(date_str[:8], DATE_FORMAT_COMPACT)


def format_date_display_to_compact(date_str: str) -> str:
    """
    Convert date from YYYY-MM-DD format to YYYYMMDD format.
    Args:
        date_str: Date string in YYYY-MM-DD format (e.g., "2025-11-13")
    Returns:
        Date string in YYYYMMDD format (e.g., "20251113")
    """
    dt = datetime.strptime(date_str, DATE_FORMAT_DISPLAY)
    return dt.strftime(DATE_FORMAT_COMPACT)


def extract_year_month(date_str: str) -> tuple[str, str]:
    """
    Extract year and month from YYYYMMDD format string.
    Args:
        date_str: Date string in YYYYMMDD format
    Returns:
        Tuple of (year, month) as strings
    """
    if len(date_str) < 6:
        raise ValueError(f"Date string must be at least 6 characters (YYYYMM), got: {date_str}")
    year = date_str[YEAR_START:YEAR_END]
    month = date_str[MONTH_START:MONTH_END]
    return year, month
