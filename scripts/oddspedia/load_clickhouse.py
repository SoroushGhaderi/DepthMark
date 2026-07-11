"""Load one Oddspedia Historical date or month into its Bronze database."""

import argparse
import sys
from calendar import monthrange
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.settings import get_settings
from src.oddspedia.config import normalize_date, normalize_month
from src.services.oddspedia.bronze_loader import OddspediaBronzeLoader
from src.storage.clickhouse_client import ClickHouseClient


def _dates(args):
    if args.date:
        return [normalize_date(args.date)]
    month = normalize_month(args.month)
    year, month_number = int(month[:4]), int(month[4:])
    return [
        "%04d%02d%02d" % (year, month_number, day)
        for day in range(1, monthrange(year, month_number)[1] + 1)
    ]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Load Oddspedia Historical artifacts into ClickHouse"
    )
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
            loader.load_date(date_id)
        return 0
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
