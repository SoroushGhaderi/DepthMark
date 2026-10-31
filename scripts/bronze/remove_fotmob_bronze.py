"""Remove FotMob Bronze data for a Source Date scope (ADR 0032).

A Source Date is the Historical folder ``matches/YYYYMM/YYYYMMDD/``. Removal
deletes the matches stored under each selected folder from all 15 Bronze tables;
``--full-history`` truncates the tables. Removal touches only Bronze and prints
the Silver and Gold commands for the Match Dates it made stale.

Usage:
    # Preview what one date's removal would delete
    python3 scripts/bronze/remove_fotmob_bronze.py --date 20251208 --dry-run

    # Remove one date, a range, or a month
    python3 scripts/bronze/remove_fotmob_bronze.py --date 20251208
    python3 scripts/bronze/remove_fotmob_bronze.py --start-date 20251201 --end-date 20251207
    python3 scripts/bronze/remove_fotmob_bronze.py --month 202512

    # Remove every date (truncate; maintenance identity)
    python3 scripts/bronze/remove_fotmob_bronze.py --full-history

To reload a scope instead of only clearing it, use
``load_fotmob_bronze.py --replace``.
"""

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config import FotMobConfig  # noqa: E402
from src.common.logging import get_logger, setup_logging  # noqa: E402
from src.common.run_scope import RunScope, add_scope_arguments  # noqa: E402
from src.fotmob.bronze.paths import get_fotmob_historical_path  # noqa: E402
from src.fotmob.bronze.removal import BronzeRemovalResult, BronzeRemovalService  # noqa: E402
from src.warehouse.identities import Identity, WarehouseConnectionError, warehouse_session  # noqa: E402

logger = get_logger(__name__)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Remove FotMob Bronze data for a Source Date scope (ADR 0032)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Usage:", 1)[1],
    )
    add_scope_arguments(parser, noun="Source Date")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count the rows that would be removed; change nothing and take no lock",
    )
    return parser


def report(result: BronzeRemovalResult) -> None:
    """Log the outcome in one place for operators and automation."""
    verb = "Would remove" if result.dry_run else "Removed"
    logger.info(
        "%s FotMob Bronze rows",
        verb,
        scope="full history" if result.full_history else ",".join(result.dates_removed),
        rows=result.removed_rows,
        total_rows=sum(result.removed_rows.values()),
    )
    for command in result.follow_up_commands:
        logger.info("Follow-up command", command=command)


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        dates = RunScope.from_args(args).dates()
    except ValueError as error:
        parser.error(str(error))

    global logger
    logger = setup_logging(name="bronze_removal", log_dir="logs", log_level="INFO")

    # Truncation is reserved for the maintenance identity (ADR 0029).
    identity = (
        Identity.MAINTENANCE if args.full_history and not args.dry_run else Identity.APPLICATION
    )
    historical_root = get_fotmob_historical_path(FotMobConfig().storage.bronze_path)
    try:
        with warehouse_session(identity) as client:
            result = BronzeRemovalService(client, historical_root).run(
                dates=dates, full_history=args.full_history, dry_run=args.dry_run
            )
    except WarehouseConnectionError as error:
        logger.error(str(error))
        return 1
    report(result)
    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
