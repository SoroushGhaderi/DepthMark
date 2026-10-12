"""Source Date selection shared by the FotMob Bronze commands (ADR 0032).

A Source Date is the name of a Historical folder, ``matches/YYYYMM/YYYYMMDD/``.
Load, replace, rebuild, and removal all expand their ``--date``, range,
``--month``, and ``--full-history`` selectors here, so they cover the same dates.
"""

import argparse
from calendar import monthrange
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import List

from src.common.dates import DATE_FORMAT_COMPACT


def generate_date_range(start_date: str, end_date: str) -> List[str]:
    """Return every YYYYMMDD date from ``start_date`` to ``end_date`` inclusive."""
    start = datetime.strptime(start_date, DATE_FORMAT_COMPACT)
    end = datetime.strptime(end_date, DATE_FORMAT_COMPACT)
    dates = []
    current = start
    while current <= end:
        dates.append(current.strftime(DATE_FORMAT_COMPACT))
        current += timedelta(days=1)
    return dates


def generate_month_dates(month_str: str) -> List[str]:
    """Return every YYYYMMDD date of a YYYYMM month."""
    year = int(month_str[:4])
    month = int(month_str[4:6])
    _, last_day = monthrange(year, month)
    return [f"{year}{month:02d}{day:02d}" for day in range(1, last_day + 1)]


def discover_historical_dates(historical_root: Path) -> List[str]:
    """Return valid completed Source Dates available in Historical storage."""
    discovered: set = set()
    for parent_name in ("matches", "daily_listings"):
        parent = historical_root / parent_name
        if not parent.exists():
            continue
        for path in parent.glob("??????/????????"):
            if not path.is_dir() or len(path.name) != 8 or not path.name.isdigit():
                continue
            try:
                candidate_date = datetime.strptime(path.name, DATE_FORMAT_COMPACT).date()
            except ValueError:
                continue
            if candidate_date < date.today():
                discovered.add(path.name)
    return sorted(discovered)


def add_source_date_arguments(parser: argparse.ArgumentParser) -> None:
    """Add the required, mutually exclusive Source Date scope selectors."""
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--date", help="One Source Date (YYYYMMDD)")
    group.add_argument("--start-date", help="First Source Date of a range (YYYYMMDD)")
    group.add_argument("--month", help="Every Source Date of a month (YYYYMM)")
    group.add_argument("--full-history", action="store_true", help="Every Source Date")
    parser.add_argument("--end-date", help="Last Source Date of a range (YYYYMMDD)")


def source_dates_from_args(args: argparse.Namespace) -> List[str]:
    """Expand date, range, or month selectors; full history returns no explicit dates."""
    for value, display in ((args.date, "YYYYMMDD"), (args.start_date, "YYYYMMDD")):
        if value is not None:
            _validate(value, DATE_FORMAT_COMPACT, display)
    if args.end_date is not None and args.start_date is None:
        raise ValueError("--end-date requires --start-date")
    if args.full_history:
        return []
    if args.month:
        _validate(args.month, "%Y%m", "YYYYMM")
        return generate_month_dates(args.month)
    if args.start_date:
        if args.end_date is None:
            raise ValueError("--start-date requires --end-date")
        _validate(args.end_date, DATE_FORMAT_COMPACT, "YYYYMMDD")
        if args.end_date < args.start_date:
            raise ValueError("--end-date must not be before --start-date")
        return generate_date_range(args.start_date, args.end_date)
    return [args.date]


def _validate(value: str, date_format: str, display: str) -> None:
    try:
        parsed = datetime.strptime(value, date_format)
    except ValueError as error:
        raise ValueError(f"Invalid date '{value}'; expected {display}") from error
    if parsed.strftime(date_format) != value:
        raise ValueError(f"Invalid date '{value}'; expected {display}")
