"""Resolve Oddspedia source events against canonical FotMob fixtures."""

import argparse
import sys
from calendar import monthrange
from contextlib import nullcontext
from datetime import datetime
from pathlib import Path
from typing import Optional, Sequence

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.settings import get_settings
from src.integrations.clickhouse.client import ClickHouseClient
from src.oddspedia.scraping.config import normalize_date, normalize_month
from src.oddspedia.scraping.operation_lock import oddspedia_date_lock
from src.oddspedia.silver import OddspediaMatchResolver, OddspediaResolutionService


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
    """Resolve one Oddspedia date or month against the FotMob Silver window."""
    parser = argparse.ArgumentParser(
        description="Resolve Oddspedia events to FotMob Silver matches"
    )
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--date", help="Oddspedia event date in YYYYMMDD format")
    scope.add_argument("--month", help="Oddspedia event month in YYYYMM format")
    parser.add_argument(
        "--dry-run", action="store_true", help="Calculate results without writing them"
    )
    parser.add_argument(
        "--silver-reference-window-ready",
        dest="reference_window_complete",
        action="store_true",
        help="Assert that the previous/current/next FotMob Silver dates are complete",
    )
    parser.add_argument(
        "--reference-window-complete",
        dest="legacy_reference_window_complete",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    raw_argv = list(sys.argv[1:] if argv is None else argv)
    args = parser.parse_args(raw_argv)
    if args.legacy_reference_window_complete:
        print(
            "Warning: --reference-window-complete is deprecated; use "
            "--silver-reference-window-ready instead.",
            file=sys.stderr,
        )
        args.reference_window_complete = True
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
            lock = (
                nullcontext()
                if args.dry_run
                else oddspedia_date_lock(date_id, operation="resolve")
            )
            with lock:
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
