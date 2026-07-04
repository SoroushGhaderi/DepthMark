"""Load raw FotMob bronze files into ClickHouse bronze tables.

SCRAPER: FotMob
PURPOSE: Transform raw bronze files (JSON/JSON.gz/TAR) into ClickHouse bronze tables

Usage:
    # Load FotMob data for a date
    python3 scripts/bronze/load_clickhouse.py --date 20251113

    # Load date range
    python3 scripts/bronze/load_clickhouse.py --start-date 20251101 --end-date 20251107

    # Load entire month
    python3 scripts/bronze/load_clickhouse.py --month 202511

    # Load every completed date found in Historical storage
    python3 scripts/bronze/load_clickhouse.py --full-history

    # Show table statistics
    python3 scripts/bronze/load_clickhouse.py --stats

    Note:
    Table optimization is handled separately via SQL scripts.
    Run clickhouse/bronze/99_optimize_tables.sql to optimize and deduplicate tables.
"""

import argparse
import logging
import os
import sys
from calendar import monthrange
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import List, Optional

project_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(project_root))

from src.services.bronze import BronzeRunResult, BronzeService
from src.services.telegram import ErrorAlertData, TelegramClient
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.date_utils import DATE_FORMAT_COMPACT, extract_year_month
from src.utils.layer_contracts import LayerContractError
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Load data from bronze layer JSON files into ClickHouse",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Load FotMob data for a date
  python3 scripts/bronze/load_clickhouse.py --date 20251113

  # Load date range
  python3 scripts/bronze/load_clickhouse.py --start-date 20251101 --end-date 20251107

  # Load entire month
  python3 scripts/bronze/load_clickhouse.py --month 202511

  # Load every locally available Historical date
  python3 scripts/bronze/load_clickhouse.py --full-history

  # Show table statistics
  python3 scripts/bronze/load_clickhouse.py --stats

  # Truncate and reload
  python3 scripts/bronze/load_clickhouse.py --date 20251113 --truncate
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

    parser.add_argument("--truncate", action="store_true", help="Truncate tables before loading")
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


def generate_date_range(start_date: str, end_date: str) -> List[str]:
    """Generate list of dates between start and end (inclusive)."""
    start = datetime.strptime(start_date, DATE_FORMAT_COMPACT)
    end = datetime.strptime(end_date, DATE_FORMAT_COMPACT)

    dates = []
    current = start
    while current <= end:
        dates.append(current.strftime(DATE_FORMAT_COMPACT))
        current += timedelta(days=1)

    return dates


def generate_month_dates(month_str: str) -> List[str]:
    """Generate all dates in a month."""
    year = int(month_str[:4])
    month = int(month_str[4:6])

    _, last_day = monthrange(year, month)
    return [f"{year}{month:02d}{day:02d}" for day in range(1, last_day + 1)]


def discover_historical_dates(historical_root: Path) -> List[str]:
    """Return valid completed-date directories available in Historical storage."""
    discovered: set[str] = set()
    for parent_name in ("matches", "daily_listings"):
        parent = historical_root / parent_name
        if not parent.exists():
            continue
        for path in parent.iterdir():
            if not path.is_dir() or len(path.name) != 8 or not path.name.isdigit():
                continue
            try:
                candidate_date = datetime.strptime(path.name, DATE_FORMAT_COMPACT).date()
            except ValueError:
                continue
            if candidate_date < date.today():
                discovered.add(path.name)
    return sorted(discovered)


def get_dates_to_process(
    args: argparse.Namespace,
    log: logging.Logger,
    historical_root: Optional[Path] = None,
) -> List[str]:
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
            extra={"historical_root": str(root), "total_dates": len(dates)},
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
            extra={
                "month": args.month,
                "month_name": month_name,
                "year": int(year),
                "total_dates": len(dates),
            },
        )
        return dates
    elif args.start_date:
        return generate_date_range(args.start_date, args.end_date)
    elif args.date:
        return [args.date]
    return []


def show_statistics(client: ClickHouseClient, log: logging.Logger) -> None:
    """Show table statistics."""
    from src.services.bronze.fotmob_bronze_service import FOTMOB_TABLES, to_bronze_table_name

    log.info("=" * 80)
    log.info("Database statistics", extra={"database": "BRONZE"})
    log.info("=" * 80)

    for table in FOTMOB_TABLES:
        physical_table = to_bronze_table_name(table)
        stats = client.get_table_stats(physical_table, database="bronze")
        if "error" not in stats:
            log.info(
                "Table statistics",
                extra={
                    "database": "bronze",
                    "table_name": physical_table,
                    "row_count": stats.get("row_count", 0),
                    "size": stats.get("size", "0 B"),
                },
            )
        else:
            log.warning(
                "Failed to read table statistics",
                extra={
                    "database": "bronze",
                    "table_name": physical_table,
                    "error": stats.get("error", "Unknown error"),
                },
            )


def main(argv: Optional[List[str]] = None) -> int:
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

    client = ClickHouseClient(
        host=args.host,
        port=args.port,
        username=args.username,
        password=args.password,
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
        result = service.run(dates=dates, truncate=args.truncate)
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
                    f"Loaded {result.total_rows} rows across {result.tables_loaded} tables "
                    f"for {result.dates_processed} date(s)."
                ),
                context={
                    "date": date_range,
                    "scraper": "fotmob",
                    "database": "bronze",
                    "step": "ClickHouse Loading — fotmob",
                    "total_rows": str(result.total_rows),
                    "tables_loaded": str(result.tables_loaded),
                },
            ),
        )


if __name__ == "__main__":
    raise SystemExit(main())
