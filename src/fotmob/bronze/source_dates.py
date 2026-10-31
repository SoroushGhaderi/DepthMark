"""Source Date selection shared by the FotMob Bronze commands (ADR 0032).

A Source Date is the name of a Historical folder, ``matches/YYYYMM/YYYYMMDD/``.
Load, replace, rebuild, and removal parse their ``--date``, range, ``--month``,
and ``--full-history`` selectors with :class:`src.common.run_scope.RunScope`,
and full history expands to the dates discovered here, so they cover the same
dates.
"""

from datetime import date, datetime
from pathlib import Path

from src.common.dates import DATE_FORMAT_COMPACT


def discover_historical_dates(historical_root: Path) -> list[str]:
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
