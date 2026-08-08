"""Load Oddspedia Historical artifacts into the source Bronze database."""

import argparse
import sys
from calendar import monthrange
from pathlib import Path
from typing import Optional, Sequence

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.settings import get_settings
from src.integrations.clickhouse.client import ClickHouseClient
from src.oddspedia.bronze import OddspediaBronzeLoader
from src.oddspedia.scraping.config import normalize_date, normalize_month
from src.oddspedia.scraping.operation_lock import oddspedia_date_lock


def _dates(args):
    if args.date:
        return [normalize_date(args.date)]
    month = normalize_month(args.month)
    year, month_number = int(month[:4]), int(month[4:])
    return [
        "%04d%02d%02d" % (year, month_number, day)
        for day in range(1, monthrange(year, month_number)[1] + 1)
    ]


def main(argv: Optional[Sequence[str]] = None) -> int:
    """Load one Oddspedia date or month into Bronze."""
    parser = argparse.ArgumentParser(description="Load Oddspedia Historical artifacts into Bronze")
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--date", help="Date to load in YYYYMMDD format")
    scope.add_argument("--month", help="Month to load in YYYYMM format")
    parser.add_argument(
        "--dry-run", action="store_true", help="Plan rows without writing ClickHouse"
    )
    args = parser.parse_args(argv)
    dates = _dates(args)
    if args.dry_run:
        loader = OddspediaBronzeLoader(client=None)  # type: ignore[arg-type]
        for date_id in dates:
            loader.load_date(date_id, dry_run=True)
        return 0
    settings = get_settings()
    client = ClickHouseClient(
        host=settings.clickhouse_host,
        port=settings.clickhouse_port,
        username=settings.clickhouse_user,
        password=settings.clickhouse_password,
        database="default",
    )
    if not client.connect():
        return 1
    try:
        loader = OddspediaBronzeLoader(client=client)
        for date_id in dates:
            with oddspedia_date_lock(date_id, operation="load_bronze"):
                loader.load_date(date_id)
        return 0
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
