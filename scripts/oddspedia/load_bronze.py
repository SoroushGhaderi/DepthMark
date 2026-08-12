"""Load Oddspedia Historical artifacts into the source Bronze database."""

import argparse
import sys
from pathlib import Path
from typing import Optional, Sequence

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.settings import get_settings
from src.common.dates import resolve_date_scope
from src.integrations.clickhouse.client import ClickHouseClient
from src.oddspedia.bronze import OddspediaBronzeLoader
from src.oddspedia.scraping.operation_lock import oddspedia_date_lock


def _dates(args):
    return resolve_date_scope(
        date_value=args.date,
        month=args.month,
        start_date=args.start_date,
        end_date=args.end_date,
        default_to_today=False,
    )


def main(argv: Optional[Sequence[str]] = None) -> int:
    """Load one Oddspedia date or month into Bronze."""
    parser = argparse.ArgumentParser(description="Load Oddspedia Historical artifacts into Bronze")
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--date", help="Date to load in YYYYMMDD format")
    scope.add_argument("--month", help="Month to load in YYYYMM format")
    scope.add_argument(
        "--start-date",
        help="First date of an inclusive range in YYYYMMDD format; requires --end-date",
    )
    parser.add_argument(
        "--end-date",
        help="Last date of an inclusive range in YYYYMMDD format; requires --start-date",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Plan rows without writing ClickHouse"
    )
    args = parser.parse_args(argv)
    if args.start_date and not args.end_date:
        parser.error("--end-date is required with --start-date")
    if args.end_date and not args.start_date:
        parser.error("--end-date can only be used with --start-date")
    try:
        dates = _dates(args)
    except ValueError as exc:
        parser.error(str(exc))
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
    print(
        "Warning: scripts/oddspedia/load_bronze.py is deprecated; use "
        "scripts/oddspedia/load_oddspedia_bronze.py instead.",
        file=sys.stderr,
    )
    raise SystemExit(main())
