"""Resolve Oddspedia source events against canonical FotMob fixtures."""

import argparse
import sys
from collections.abc import Sequence
from contextlib import ExitStack, nullcontext
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.common.dates import resolve_date_scope
from src.oddspedia.scraping.operation_lock import oddspedia_date_lock
from src.oddspedia.silver import OddspediaMatchResolver, OddspediaResolutionService
from src.warehouse.identities import WarehouseConnectionError, warehouse_session


def _dates(args):
    return resolve_date_scope(
        date_value=args.date,
        month=args.month,
        start_date=args.start_date,
        end_date=args.end_date,
        default_to_today=False,
    )


def main(argv: Sequence[str] | None = None) -> int:
    """Resolve one Oddspedia date or month against the FotMob Silver window."""
    parser = argparse.ArgumentParser(
        description="Resolve Oddspedia events to FotMob Silver matches"
    )
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--date", help="Oddspedia event date in YYYYMMDD format")
    scope.add_argument("--month", help="Oddspedia event month in YYYYMM format")
    scope.add_argument(
        "--start-date",
        help="First Oddspedia date of an inclusive range; requires --end-date",
    )
    parser.add_argument(
        "--end-date",
        help="Last Oddspedia date of an inclusive range; requires --start-date",
    )
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
    if args.start_date and not args.end_date:
        parser.error("--end-date is required with --start-date")
    if args.end_date and not args.start_date:
        parser.error("--end-date can only be used with --start-date")
    if args.legacy_reference_window_complete:
        print(
            "Warning: --reference-window-complete is deprecated; use "
            "--silver-reference-window-ready instead.",
            file=sys.stderr,
        )
        args.reference_window_complete = True
    try:
        dates = _dates(args)
    except ValueError as exc:
        parser.error(str(exc))
    resolver = OddspediaMatchResolver(
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "scoring_policy.yaml",
        PROJECT_ROOT / "config" / "oddspedia_match_resolution" / "team_aliases.yaml",
    )
    with ExitStack() as stack:
        try:
            client = stack.enter_context(warehouse_session())
        except WarehouseConnectionError as error:
            print(error, file=sys.stderr)
            return 1
        service = OddspediaResolutionService(client, resolver)
        for date_id in dates:
            lock = (
                nullcontext() if args.dry_run else oddspedia_date_lock(date_id, operation="resolve")
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
            print(f"{date_id} {summary}")
    return 0


if __name__ == "__main__":
    print(
        "Warning: scripts/oddspedia/resolve_events.py is deprecated; use "
        "scripts/oddspedia/resolve_oddspedia_events.py instead.",
        file=sys.stderr,
    )
    raise SystemExit(main())
