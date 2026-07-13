"""Resolve Oddspedia events against the canonical FotMob Silver reference."""

import argparse
import sys
from calendar import monthrange
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.settings import get_settings
from src.oddspedia.scraping.config import normalize_date, normalize_month
from src.oddspedia.silver import (
    OddspediaMatchResolver,
    OddspediaResolutionService,
)
from src.integrations.clickhouse.client import ClickHouseClient


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
        description="Resolve Oddspedia fixtures to FotMob Silver matches"
    )
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--date", help="Oddspedia discovery date in YYYYMMDD format")
    scope.add_argument("--month", help="Oddspedia discovery month in YYYYMM format")
    parser.add_argument(
        "--dry-run", action="store_true", help="Calculate results without writing them"
    )
    parser.add_argument(
        "--reference-window-complete",
        action="store_true",
        help="Assert that each FotMob date in the three-day reference window is complete",
    )
    args = parser.parse_args(argv)
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
    resolver = OddspediaMatchResolver(
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "scoring_policy.yaml",
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "team_aliases.yaml",
    )
    service = OddspediaResolutionService(client, resolver)
    try:
        for date_id in _dates(args):
            results = service.resolve_date(
                datetime.strptime(date_id, "%Y%m%d").date(),
                reference_window_complete=args.reference_window_complete,
                persist=not args.dry_run,
            )
            summary = {}
            for result in results:
                summary[result.resolution_status] = summary.get(result.resolution_status, 0) + 1
            print("%s %s" % (date_id, summary))
        return 0
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
