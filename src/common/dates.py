"""
Date utility functions and constants for consistent date handling.

Replaces magic numbers and hardcoded string slicing with proper constants and functions.
"""

from calendar import monthrange
from datetime import date, datetime, timedelta

DATE_FORMAT_COMPACT = "%Y%m%d"
DATE_FORMAT_DISPLAY = "%Y-%m-%d"
DATE_FORMAT_MONTH = "%Y%m"
YEAR_START = 0
YEAR_END = 4
MONTH_START = 4
MONTH_END = 6
DAY_START = 6
DAY_END = 8


def normalize_compact_date(value: str) -> str:
    """Return a strict ``YYYYMMDD`` identifier."""
    date_id = str(value).strip()
    if len(date_id) != 8 or not date_id.isdigit():
        raise ValueError(f"date must use YYYYMMDD format: {value}")
    datetime.strptime(date_id, DATE_FORMAT_COMPACT)
    return date_id


def normalize_compact_month(value: str) -> str:
    """Return a strict ``YYYYMM`` identifier."""
    month_id = str(value).strip()
    if len(month_id) != 6 or not month_id.isdigit():
        raise ValueError(f"month must use YYYYMM format: {value}")
    datetime.strptime(month_id, DATE_FORMAT_MONTH)
    return month_id


def inclusive_date_ids(start_date: str, end_date: str) -> list[str]:
    """Return an ordered, inclusive range of compact date identifiers."""
    start = datetime.strptime(normalize_compact_date(start_date), DATE_FORMAT_COMPACT).date()
    end = datetime.strptime(normalize_compact_date(end_date), DATE_FORMAT_COMPACT).date()
    if end < start:
        raise ValueError("--end-date cannot be before --start-date")
    result = []
    selected = start
    while selected <= end:
        result.append(selected.strftime(DATE_FORMAT_COMPACT))
        selected += timedelta(days=1)
    return result


def month_date_ids(month: str, through_date: date | None = None) -> list[str]:
    """Return the dates in a month, optionally clipped through one date."""
    month_id = normalize_compact_month(month)
    year, month_number = int(month_id[:4]), int(month_id[4:])
    last_day = monthrange(year, month_number)[1]
    if through_date and (year, month_number) == (through_date.year, through_date.month):
        last_day = min(last_day, through_date.day)
    return [f"{year:04d}{month_number:02d}{day:02d}" for day in range(1, last_day + 1)]


def resolve_date_scope(
    date_value: str | None = None,
    month: str | None = None,
    current_date: date | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    default_to_today: bool = True,
) -> list[str]:
    """Resolve one date, month, or inclusive range without admitting future dates.

    A current-month selector stops at ``current_date``. This keeps collection,
    reporting, and downstream date scopes consistent while allowing historical
    months to retain their complete calendar-day behavior.
    """
    selectors = sum(bool(value) for value in (date_value, month, start_date))
    if selectors > 1:
        raise ValueError("choose only one of --date, --month, or --start-date")
    if start_date and not end_date:
        raise ValueError("--end-date is required with --start-date")
    if end_date and not start_date:
        raise ValueError("--end-date can only be used with --start-date")

    today = current_date or date.today()
    if date_value:
        date_id = normalize_compact_date(date_value)
        if datetime.strptime(date_id, DATE_FORMAT_COMPACT).date() > today:
            raise ValueError(f"future dates cannot be selected: {date_id}")
        return [date_id]
    if start_date:
        dates = inclusive_date_ids(start_date, end_date or "")
        if datetime.strptime(dates[-1], DATE_FORMAT_COMPACT).date() > today:
            raise ValueError(f"future dates cannot be selected: {dates[-1]}")
        return dates
    if month:
        month_id = normalize_compact_month(month)
        selected_month = datetime.strptime(month_id, DATE_FORMAT_MONTH).date()
        first_day = selected_month.replace(day=1)
        if first_day > today:
            raise ValueError(f"future months cannot be selected: {month_id}")
        return month_date_ids(month_id, through_date=today)
    if default_to_today:
        return [today.strftime(DATE_FORMAT_COMPACT)]
    raise ValueError("one of --date, --month, or --start-date is required")


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
