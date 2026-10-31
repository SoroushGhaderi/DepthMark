"""Load raw FotMob bronze files into ClickHouse bronze tables.

SCRAPER: FotMob
PURPOSE: Transform raw bronze files (JSON/JSON.gz/TAR) into ClickHouse bronze tables

Usage:
    # Load FotMob data for a date
    python3 scripts/bronze/load_fotmob_bronze.py --date 20251113

    # Load date range
    python3 scripts/bronze/load_fotmob_bronze.py --start-date 20251101 --end-date 20251107

    # Load entire month
    python3 scripts/bronze/load_fotmob_bronze.py --month 202511

    # Load every completed date found in Historical storage
    python3 scripts/bronze/load_fotmob_bronze.py --full-history

    # Show table statistics
    python3 scripts/bronze/load_fotmob_bronze.py --stats

    # Replace one date: admit it, remove its matches, then insert (ADR 0032)
    python3 scripts/bronze/load_fotmob_bronze.py --date 20251113 --replace

    # Rebuild all history into staging and swap it in (maintenance identity)
    python3 scripts/bronze/load_fotmob_bronze.py --full-history --rebuild --dry-run

    Note:
    ClickHouse background merges handle routine ReplacingMergeTree storage cleanup.
    Warehouse quality checks report extra physical row versions as diagnostics.
"""

import argparse
import logging
import os
import sys
from pathlib import Path

project_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(project_root))

from config.settings import get_settings
from src.common.dates import extract_year_month
from src.common.logging import get_logger, setup_logging
from src.fotmob.bronze import BronzeRunResult, BronzeService
from src.fotmob.bronze.source_dates import (
    discover_historical_dates,
    generate_date_range,
    generate_month_dates,
)
from src.integrations.clickhouse.client import ClickHouseClient
from src.integrations.telegram import ErrorAlertData, TelegramClient
from src.warehouse.contracts import LayerContractError

logger = get_logger(__name__)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Load data from bronze layer JSON files into ClickHouse",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Load FotMob data for a date
  python3 scripts/bronze/load_fotmob_bronze.py --date 20251113

  # Load date range
  python3 scripts/bronze/load_fotmob_bronze.py --start-date 20251101 --end-date 20251107

  # Load entire month
  python3 scripts/bronze/load_fotmob_bronze.py --month 202511

  # Load every locally available Historical date
  python3 scripts/bronze/load_fotmob_bronze.py --full-history

  # Show table statistics
  python3 scripts/bronze/load_fotmob_bronze.py --stats

  # Replace one date or a month (admit, remove its matches, insert)
  python3 scripts/bronze/load_fotmob_bronze.py --date 20251113 --replace
  python3 scripts/bronze/load_fotmob_bronze.py --month 202511 --replace

  # Rebuild all history without an empty window (maintenance identity)
  python3 scripts/bronze/load_fotmob_bronze.py --full-history --rebuild --dry-run
  python3 scripts/bronze/load_fotmob_bronze.py --full-history --rebuild

  # Clear data without reloading: see scripts/bronze/remove_fotmob_bronze.py
        """,
    )

    date_group = parser.add_mutually_exclusive_group()
    date_group.add_argument("--date", type=str, help="Date to load (YYYYMMDD format)")
    date_group.add_argument(
        "--single-date",
        type=str,
        help="Load a single date (YYYYMMDD format). Equivalent to --date.",
    )
    date_group.add_argument(
        "--start-date", type=str, help="Start date for range loading (YYYYMMDD format)"
    )
    date_group.add_argument("--month", type=str, help="Load entire month (YYYYMM format)")
    date_group.add_argument(
        "--full-history",
        action="store_true",
        help="Load every available date from data/fotmob/historical (Live is excluded)",
    )
    parser.add_argument("--end-date", type=str, help="End date for range loading (YYYYMMDD format)")

    parser.add_argument(
        "--host",
        type=str,
        default=os.getenv("CLICKHOUSE_HOST", "localhost"),
        help="ClickHouse host",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.getenv("CLICKHOUSE_PORT", "8123")),
        help="ClickHouse HTTP port",
    )
    parser.add_argument(
        "--username",
        type=str,
        default=os.getenv("CLICKHOUSE_USER", "fotmob_user"),
        help="ClickHouse username",
    )
    parser.add_argument(
        "--password",
        type=str,
        default=os.getenv("CLICKHOUSE_PASSWORD", "fotmob_pass"),
        help="ClickHouse password",
    )

    parser.add_argument(
        "--replace",
        action="store_true",
        help=(
            "Replace each Source Date: admit its payloads, remove its matches from every "
            "Bronze table, then insert (ADR 0032). A date that fails admission keeps its rows."
        ),
    )
    parser.add_argument(
        "--rebuild",
        action="store_true",
        help=(
            "With --full-history: load every Source Date into staging clones and swap them in "
            "only if every date loads (ADR 0032). Uses the maintenance identity."
        ),
    )
    parser.add_argument(
        "--truncate",
        action="store_true",
        help="Deprecated: with --full-history it runs --rebuild; rejected for narrower scopes",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview bronze load operations without truncating tables or loading data",
    )
    parser.add_argument("--stats", action="store_true", help="Show table statistics and exit")
    parser.add_argument("--force", action="store_true", help="Force reload even if data exists")

    return parser.parse_args(argv)


def validate_arguments(args: argparse.Namespace) -> None:
    """Validate parsed arguments."""
    if args.month:
        if len(args.month) != 6 or not args.month.isdigit():
            raise SystemExit(f"Invalid month format: {args.month}. Use YYYYMM")

        month = int(args.month[4:6])
        if not (1 <= month <= 12):
            raise SystemExit(f"Invalid month: {month}")

        if args.end_date:
            raise SystemExit("Cannot use --end-date with --month option")
    if args.truncate:
        if not args.full_history:
            raise SystemExit(
                "--truncate is no longer accepted with --date, --month, or a range: it erased "
                "every Source Date to reload a few. Use --replace to reload the scope, or "
                "remove_fotmob_bronze.py to clear it (ADR 0032)."
            )
        print(
            "Warning: --truncate is deprecated; running --full-history --rebuild instead.",
            file=sys.stderr,
        )
        args.rebuild = True
    if args.rebuild and not args.full_history:
        raise SystemExit("--rebuild requires --full-history")
    if args.replace and args.rebuild:
        raise SystemExit("--replace and --rebuild cannot be combined")
    if args.replace and args.full_history:
        raise SystemExit("Use --rebuild to reload full history; --replace is for narrower scopes")


def get_dates_to_process(
    args: argparse.Namespace,
    log: logging.Logger,
    historical_root: Path | None = None,
) -> list[str]:
    """Get list of dates to process from arguments."""
    if args.single_date:
        if args.date:
            raise SystemExit("Use either --date or --single-date, not both")
        args.date = args.single_date
    if args.full_history:
        root = historical_root or (project_root / "data" / "fotmob" / "historical")
        dates = discover_historical_dates(root)
        log.info(
            "Full-history Bronze loading mode",
            historical_root=str(root),
            total_dates=len(dates),
        )
        return dates
    if args.month:
        dates = generate_month_dates(args.month)
        year, month = extract_year_month(args.month)
        month_names = [
            "Jan",
            "Feb",
            "Mar",
            "Apr",
            "May",
            "Jun",
            "Jul",
            "Aug",
            "Sep",
            "Oct",
            "Nov",
            "Dec",
        ]
        month_name = month_names[int(month) - 1]
        log.info(
            "Monthly loading mode",
            month=args.month,
            month_name=month_name,
            year=int(year),
            total_dates=len(dates),
        )
        return dates
    elif args.start_date:
        return generate_date_range(args.start_date, args.end_date)
    elif args.date:
        return [args.date]
    return []


def show_statistics(client: ClickHouseClient, log: logging.Logger) -> None:
    """Show table statistics."""
    from src.fotmob.bronze.loader import FOTMOB_TABLES

    log.info("=" * 80)
    log.info("Database statistics", database="BRONZE")
    log.info("=" * 80)

    for physical_table in FOTMOB_TABLES:
        stats = client.get_table_stats(physical_table, database="bronze")
        if "error" not in stats:
            log.info(
                "Table statistics",
                database="bronze",
                table_name=physical_table,
                row_count=stats.get("row_count", 0),
                size=stats.get("size", "0 B"),
            )
        else:
            log.warning(
                "Failed to read table statistics",
                database="bronze",
                table_name=physical_table,
                error=stats.get("error", "Unknown error"),
            )


def _write_mode(args: argparse.Namespace) -> str:
    if args.rebuild:
        return "rebuild"
    return "replace" if args.replace else "append"


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    global logger
    args = parse_args(argv)
    validate_arguments(args)

    settings_log_dir = "logs"
    settings_log_level = "INFO"
    logger = setup_logging(
        name="clickhouse_loader",
        log_dir=settings_log_dir,
        log_level=settings_log_level,
    )

    if args.dry_run and args.stats:
        logger.info("Ignoring --dry-run because --stats is read-only")

    if args.dry_run and not args.stats:
        dates = get_dates_to_process(args, logger)
        if not dates:
            raise SystemExit(
                "One of --date, --start-date, --month, or --full-history must be provided"
            )
        service = BronzeService(client=None, force=args.force)
        result = service.run(dates=dates, dry_run=True, mode=_write_mode(args))
        if result.exit_code == 0:
            logger.info("Bronze dry-run completed successfully")
        return result.exit_code

    username, password = args.username, args.password
    if args.rebuild:
        # Swapping whole tables is reserved for the maintenance identity (ADR 0029).
        settings = get_settings()
        if not settings.clickhouse_maintenance_user:
            logger.error(
                "--rebuild needs the ClickHouse maintenance identity; set "
                "CLICKHOUSE_MAINTENANCE_USER and CLICKHOUSE_MAINTENANCE_PASSWORD"
            )
            return 1
        username = settings.clickhouse_maintenance_user
        password = settings.clickhouse_maintenance_password
    client = ClickHouseClient(
        host=args.host,
        port=args.port,
        username=username,
        password=password,
        database="bronze",
    )

    if not client.connect():
        logger.error("Failed to connect to ClickHouse")
        telegram_client = TelegramClient()
        telegram_client.render_and_send(
            "error_alert.html.j2",
            ErrorAlertData(
                level="ERROR",
                title="ClickHouse Loading Failed — FOTMOB",
                message="Failed to connect to ClickHouse.",
                context={
                    "scraper": "fotmob",
                    "database": "bronze",
                    "step": "ClickHouse Loading — fotmob",
                    "error": "Connection failed",
                },
            ),
        )
        return 1

    result = BronzeRunResult(exit_code=1)
    dates: list[str] = []
    try:
        if args.stats:
            show_statistics(client, logger)
            return 0

        dates = get_dates_to_process(args, logger)
        if not dates:
            raise SystemExit(
                "One of --date, --start-date, --month, or --full-history must be provided"
            )

        service = BronzeService(client=client, force=args.force)
        result = service.run(dates=dates, dry_run=False, mode=_write_mode(args))
        return result.exit_code

    except LayerContractError as exc:
        logger.error("Bronze layer contract assertion failed", error=str(exc))
        return 1
    finally:
        client.disconnect()
        telegram_client = TelegramClient()
        date_range = f"{dates[0]}–{dates[-1]}" if len(dates) > 1 else (dates[0] if dates else "N/A")
        telegram_client.render_and_send(
            "error_alert.html.j2",
            ErrorAlertData(
                level="INFO" if result.exit_code == 0 else "ERROR",
                title=f"ClickHouse Loading {'Succeeded' if result.exit_code == 0 else 'Failed'} — FOTMOB — {date_range}",
                message=(
                    f"{result.mode.capitalize()}: loaded {result.total_rows} rows across "
                    f"{result.tables_loaded} tables for {result.dates_processed} date(s). "
                    f"Failed dates: {len(result.failed_dates)}."
                    + (f" Run stopped: {result.run_error}" if result.run_error else "")
                    + (" Rebuild not swapped." if result.swapped is False else "")
                ),
                context={
                    "date": date_range,
                    "scraper": "fotmob",
                    "database": "bronze",
                    "step": "ClickHouse Loading — fotmob",
                    "total_rows": str(result.total_rows),
                    "tables_loaded": str(result.tables_loaded),
                    "failed_dates": ",".join(sorted(result.failed_dates)) or "none",
                },
            ),
        )


if __name__ == "__main__":
    print(
        "Warning: scripts/bronze/load_clickhouse.py is deprecated; use "
        "scripts/bronze/load_fotmob_bronze.py instead.",
        file=sys.stderr,
    )
    raise SystemExit(main())
