"""Bronze Layer Processing - Raw Data Scraping.

SCRAPER: FotMob
PURPOSE: Scrapes raw match data from FotMob API and saves to Bronze layer.
    Supports single date, date range, and monthly scraping.

Usage:
    # Single date
    python scripts/bronze/scrape_fotmob.py 20250108

    # Date range (start and end)
    python scripts/bronze/scrape_fotmob.py 20250101 20250107

    # Date range (start + number of days)
    python scripts/bronze/scrape_fotmob.py 20250101 --days 7

    # Monthly scraping
    python scripts/bronze/scrape_fotmob.py --month 202511

    # With options
    python scripts/bronze/scrape_fotmob.py 20250108 --force --debug
"""

import argparse
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

# Ensure local project imports resolve before importing project modules.
SCRIPT_DIR = Path(__file__).resolve().parent
SCRIPTS_ROOT = SCRIPT_DIR.parent
PROJECT_ROOT = SCRIPT_DIR.parents[1]
for _path in (str(SCRIPT_DIR), str(SCRIPTS_ROOT), str(PROJECT_ROOT)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

from config import FotMobConfig
from scripts.refresh_turnstile import refresh_if_needed
from src.orchestrator import FotMobOrchestrator
from src.services.telegram import (
    DailyReportData,
    ErrorAlertData,
    LayerAlertData,
    MonthlyReportData,
    TelegramClient,
)
from src.utils.logging_utils import get_logger, setup_logging
from utils import (
    DateRangeInfo,
    create_date_range_info,
    print_header,
    print_separator,
    validate_date_format,
)

logger = get_logger(__name__)


# ============================================================================
# Data Classes
# ============================================================================


@dataclass
class ScrapingStats:
    """Statistics for scraping operations."""

    dates_processed: int = 0
    dates_failed: int = 0
    total_matches: int = 0
    total_successful: int = 0
    total_failed: int = 0
    total_skipped: int = 0
    total_duration_seconds: float = 0
    bronze_files: int = 0
    bronze_size_mb: float = 0

    def update_from_metrics(self, metrics) -> None:
        """Update stats from orchestrator metrics."""
        self.dates_processed += 1
        self.total_matches += metrics.total_matches
        self.total_successful += metrics.successful_matches
        self.total_failed += metrics.failed_matches
        self.total_skipped += metrics.skipped_matches

    def add_duration(self, duration: float) -> None:
        """Add duration for a date."""
        self.total_duration_seconds += duration

    def record_failure(self) -> None:
        """Record a date processing failure."""
        self.dates_failed += 1

    def add_bronze_storage(self, files: int, size_mb: float) -> None:
        """Add bronze storage stats."""
        self.bronze_files += files
        self.bronze_size_mb += size_mb


def get_bronze_storage_stats(bronze_base_dir: str, date_str: str) -> tuple:
    """Get bronze storage stats for a specific date."""
    date_dir = Path(bronze_base_dir) / "matches" / date_str
    if not date_dir.exists():
        return 0, 0.0

    json_files = list(date_dir.glob("match_*.json"))
    gz_files = list(date_dir.glob("match_*.json.gz"))
    all_files = json_files + gz_files

    total_size = sum(f.stat().st_size for f in all_files)
    size_mb = total_size / (1024 * 1024)

    return len(all_files), size_mb


# ============================================================================
# Argument Parsing
# ============================================================================


def create_argument_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description="FotMob Bronze Layer Processing - Scrape raw match data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Single Date:
    python scripts/bronze/scrape_fotmob.py 20250108                   # Scrape Jan 8, 2025
    python scripts/bronze/scrape_fotmob.py 20250108 --force --debug   # Force + debug mode

  Date Range:
    python scripts/bronze/scrape_fotmob.py 20250101 20250107          # Scrape Jan 1-7
    python scripts/bronze/scrape_fotmob.py 20250101 --days 7          # 7 days from Jan 1
    python scripts/bronze/scrape_fotmob.py 20250101 --days 30 --force # Force 30 days

  Monthly Scraping:
    python scripts/bronze/scrape_fotmob.py --month 202511              # Scrape entire November 2025
    python scripts/bronze/scrape_fotmob.py --month 202511 --force       # Month with force re-scrape
        """,
    )

    _add_date_arguments(parser)
    _add_option_arguments(parser)

    return parser


def _add_date_arguments(parser: argparse.ArgumentParser) -> None:
    """Add date-related arguments to parser."""
    date_group = parser.add_mutually_exclusive_group(required=True)
    date_group.add_argument(
        "start_date",
        type=str,
        nargs="?",
        help="Date (or start date) in YYYYMMDD format. Required unless --month is used.",
    )
    date_group.add_argument(
        "--single-date",
        type=str,
        help="Scrape a single date (YYYYMMDD format). Equivalent to the positional start_date argument.",
    )
    date_group.add_argument(
        "--month",
        type=str,
        help="Scrape entire month (YYYYMM format, e.g., 202511 for November 2025)",
    )

    range_group = parser.add_mutually_exclusive_group()
    range_group.add_argument(
        "end_date",
        type=str,
        nargs="?",
        help="End date in YYYYMMDD format (for range scraping, requires start_date)",
    )
    range_group.add_argument(
        "--days",
        type=int,
        help="Number of days to scrape from start date (requires start_date)",
    )


def _add_option_arguments(parser: argparse.ArgumentParser) -> None:
    """Add option arguments to parser."""
    parser.add_argument(
        "--force", action="store_true", help="Force re-scrape already processed matches"
    )
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    parser.add_argument(
        "--compress",
        action="store_true",
        help="Compress files after scraping (creates .tar archives)",
    )


def parse_arguments() -> argparse.Namespace:
    """Parse and validate command-line arguments."""
    parser = create_argument_parser()
    args = parser.parse_args()

    _validate_month_argument(parser, args)
    _validate_start_date_argument(parser, args)

    return args


def _validate_month_argument(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    """Validate month argument if provided."""
    if not args.month:
        return

    is_valid, error_msg = validate_date_format(args.month, "YYYYMM")
    if not is_valid:
        parser.error(error_msg)

    if args.end_date or args.days:
        parser.error("Cannot use --end_date or --days with --month option")


def _validate_start_date_argument(
    parser: argparse.ArgumentParser, args: argparse.Namespace
) -> None:
    """Validate start date and related arguments."""
    if args.single_date:
        if args.start_date:
            parser.error("Use either the positional start_date or --single-date, not both")
        args.start_date = args.single_date
    if not args.start_date:
        return

    is_valid, error_msg = validate_date_format(args.start_date, "YYYYMMDD")
    if not is_valid:
        parser.error(error_msg)

    if args.end_date:
        is_valid, error_msg = validate_date_format(args.end_date, "YYYYMMDD")
        if not is_valid:
            parser.error(error_msg)

        if args.end_date < args.start_date:
            parser.error(
                f"End date ({args.end_date}) cannot be before start date ({args.start_date})"
            )

    if args.days and args.days < 1:
        parser.error(f"Number of days must be at least 1 (got: {args.days})")


# ============================================================================
# Date Range Generation
# ============================================================================


def create_date_info(args: argparse.Namespace) -> DateRangeInfo:
    """Create DateRangeInfo from parsed arguments."""
    return create_date_range_info(
        date=args.start_date if not args.end_date and not args.days else None,
        start_date=args.start_date if args.end_date or args.days else None,
        end_date=args.end_date,
        month=args.month,
        num_days=args.days,
    )


# ============================================================================
# Configuration
# ============================================================================


def create_config(args: argparse.Namespace) -> FotMobConfig:
    """Create FotMob configuration from arguments."""
    config = FotMobConfig()

    if args.debug:
        config.logging.level = "DEBUG"

    # FotMob runs single-threaded (sequential) by default
    config.scraping.enable_parallel = False
    config.scraping.max_workers = 1

    return config


# ============================================================================
# Output Formatting
# ============================================================================


def print_scraping_header(date_info: DateRangeInfo, args: argparse.Namespace) -> None:
    """Log scraping header."""
    print_header("Bronze Layer Processing")
    logger.info("Mode:             %s", date_info.mode_text)
    logger.info("Date(s):          %s", date_info.display_text)
    logger.info("Total dates:      %s", len(date_info.dates))
    logger.info("Mode:             Single-threaded (sequential)")
    logger.info("Force re-scrape:  %s", args.force)
    logger.info("Auto-compress:    %s", args.compress)
    logger.info("%s", "=" * 80 + "\n")


def print_date_metrics(metrics) -> None:
    """Log metrics for a single date."""
    logger.info("  Matches:   %s", metrics.total_matches)
    logger.info("  Success:   %s", metrics.successful_matches)
    logger.info("  Failed:    %s", metrics.failed_matches)
    logger.info("  Skipped:   %s", metrics.skipped_matches)


def print_final_summary(stats: ScrapingStats, total_dates: int) -> None:
    """Log final scraping summary."""
    print_header("BRONZE LAYER COMPLETE")
    logger.info("Dates processed:  %s/%s", stats.dates_processed, total_dates)
    logger.info("Dates failed:     %s", stats.dates_failed)
    print_separator()
    logger.info("Total matches:    %s", stats.total_matches)
    logger.info("Successful:       %s", stats.total_successful)
    logger.info("Failed:           %s", stats.total_failed)
    logger.info("Skipped:          %s", stats.total_skipped)
    logger.info("%s", "=" * 80)


def print_next_steps(stats: ScrapingStats) -> None:
    """Log next steps if applicable."""
    if stats.total_successful > 0:
        logger.info("Next steps:")
        logger.info(
            "  Load to ClickHouse:  "
            "python scripts/bronze/load_clickhouse.py --scraper fotmob --date <date>"
        )
        logger.info("  View profiling:  python manage.py bronze view-profiling")


# ============================================================================
# Scraping Execution
# ============================================================================


def process_single_date(
    date_str: str,
    orchestrator: FotMobOrchestrator,
    args: argparse.Namespace,
    logger,
    idx: int,
    total: int,
) -> Optional[object]:
    """
    Process a single date.

    Returns:
        Metrics object if successful, None if failed
    """
    logger.info(f"[{idx}/{total}] Processing date: {date_str}")
    logger.info("[%s/%s] Scraping %s...", idx, total, date_str)

    try:
        metrics = orchestrator.scrape_date(date_str=date_str, force_rescrape=args.force)
        return metrics
    except Exception as e:
        logger.error(f"Failed to process date {date_str}: {e}")
        logger.error("Date processing error: %s", e)
        _send_failure_alert(date_str, e)
        return None


def _send_failure_alert(date_str: str, error: Exception) -> None:
    """Send alert for date processing failure."""
    client = TelegramClient()
    client.render_and_send(
        "error_alert.html.j2",
        ErrorAlertData(
            level="ERROR",
            title=f"FotMob Bronze Scraping Failed — {date_str}",
            message=f"Failed to scrape FotMob data for date {date_str}.\n\nError: {error}",
            context={
                "date": date_str,
                "step": "FotMob Bronze Scraping",
                "error": str(error),
            },
        ),
    )


def run_scraping(args: argparse.Namespace) -> int:
    """
    Run the scraping process.

    Args:
        args: Parsed command-line arguments

    Returns:
        Exit code (0 for success, 1 for failure)
    """
    config = create_config(args)
    date_info = create_date_info(args)

    pipeline_start = time.time()

    # Setup logging
    logger = setup_logging(
        name="bronze_processing",
        log_dir=config.log_dir,
        log_level=config.log_level,
    )

    # Print header
    print_scraping_header(date_info, args)

    # Initialize
    stats = ScrapingStats()
    orchestrator = FotMobOrchestrator(config)

    # Process each date
    for idx, date_str in enumerate(date_info.dates, 1):
        start_time = time.time()
        metrics = process_single_date(
            date_str, orchestrator, args, logger, idx, len(date_info.dates)
        )
        duration = time.time() - start_time

        if metrics:
            stats.update_from_metrics(metrics)
            stats.add_duration(duration)

            bronze_files, bronze_size_mb = get_bronze_storage_stats(
                config.storage.bronze_path, date_str
            )
            stats.add_bronze_storage(bronze_files, bronze_size_mb)

            print_date_metrics(metrics)

            # Send daily Telegram report
            telegram_client = TelegramClient()
            formatted_date = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:]}"
            telegram_client.render_and_send(
                "daily_report.html.j2",
                DailyReportData(
                    date=formatted_date,
                    matches_scraped=metrics.successful_matches,
                    matches_total=metrics.total_matches,
                    skipped=metrics.skipped_matches,
                    errors=metrics.failed_matches,
                    duration_seconds=duration,
                    bronze_files=bronze_files,
                    bronze_size_mb=bronze_size_mb,
                    s3_uploaded=metrics.s3_uploaded,
                    s3_size_mb=metrics.s3_size_mb,
                ),
            )

            # Check and refresh turnstile if needed (every 30 minutes)
            was_refreshed, turnstile_status = refresh_if_needed(max_age_seconds=1800)
            if was_refreshed:
                logger.info(f"Turnstile refreshed: {turnstile_status}")
            else:
                logger.info(f"Turnstile status: {turnstile_status}")
        else:
            stats.record_failure()

    # Send monthly report if scraping multiple dates
    if len(date_info.dates) > 1:
        month = date_info.dates[0][:6] if date_info.dates else None
        formatted_month = f"{month[:4]}-{month[4:]}" if month else ""
        telegram_client = TelegramClient()
        telegram_client.render_and_send(
            "monthly_report.html.j2",
            MonthlyReportData(
                year_month=formatted_month,
                dates_processed=stats.dates_processed,
                dates_total=len(date_info.dates),
                total_matches=stats.total_matches,
                matches_scraped=stats.total_successful,
                errors=stats.total_failed,
                duration_seconds=stats.total_duration_seconds,
                bronze_files=stats.bronze_files,
                bronze_size_mb=stats.bronze_size_mb,
            ),
        )

    # Print summary
    print_final_summary(stats, len(date_info.dates))
    print_next_steps(stats)

    exit_code = 0 if stats.dates_failed == 0 else 1
    scope = date_info.display_text
    total_dates = len(date_info.dates)
    date_coverage = (stats.dates_processed / total_dates * 100) if total_dates > 0 else 0
    matches_attempted = stats.total_successful + stats.total_failed
    scrape_success_rate = (
        (stats.total_successful / matches_attempted * 100) if matches_attempted > 0 else 0
    )
    telegram_client.render_and_send(
        "layer_alert.html.j2",
        LayerAlertData(
            layer="bronze",
            success=exit_code == 0,
            scope=scope,
            duration_seconds=time.time() - pipeline_start,
            details={
                "Dates processed": f"{stats.dates_processed}/{total_dates}",
                "Matches scraped": str(stats.total_successful),
                "Failures": str(stats.total_failed),
            },
            insights={
                "Date coverage": f"{date_coverage:.1f}%",
                "Success rate": f"{scrape_success_rate:.1f}%",
                "Bronze files": str(stats.bronze_files),
            },
        ),
    )

    return exit_code


# ============================================================================
# Main Entry Point
# ============================================================================


def main() -> int:
    """Main execution function."""
    args = parse_arguments()
    return run_scraping(args)


if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.warning("Scraping interrupted by user. Exiting...")
        sys.exit(130)
    except Exception as e:
        logger.error("Fatal error: %s", e)
        sys.exit(1)
