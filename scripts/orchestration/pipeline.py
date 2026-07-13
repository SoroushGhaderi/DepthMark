"""Unified Pipeline Orchestrator.

PURPOSE: Orchestrates the complete data pipeline:
    1. FotMob Bronze Layer (scraping)
    2. Load FotMob raw files into ClickHouse Bronze tables
    3. Build FotMob Silver layer
    4. Build FotMob Gold layer

This script runs all steps sequentially, handling errors gracefully
and providing a comprehensive summary at the end.

Usage:
    python3 scripts/orchestration/pipeline.py 20251113
    python3 scripts/orchestration/pipeline.py --date 20251113
    python3 scripts/orchestration/pipeline.py --start-date 20251101 --end-date 20251107
    python3 scripts/orchestration/pipeline.py --month 202511
    python3 scripts/orchestration/pipeline.py --full-history
    python3 scripts/orchestration/pipeline.py 20251113 --skip-bronze
    python3 scripts/orchestration/pipeline.py 20251113 --skip-clickhouse
    python3 scripts/orchestration/pipeline.py 20251113 --bronze-only
    python3 scripts/orchestration/pipeline.py 20251113 --silver-only
    python3 scripts/orchestration/pipeline.py 20251113 --gold-only
"""
import argparse
import logging
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from utils.script_utils import (
    DateRangeInfo,
    StepResult,
    add_project_to_path,
    create_date_range_info,
    format_elapsed_time,
    get_project_root,
    validate_date_format,
)

add_project_to_path()
from src.integrations.telegram import ErrorAlertData, TelegramClient
from src.common.logging import get_logger, setup_logging

RESULT_CATEGORIES = {
    "fotmob_bronze": "FotMob Bronze",
    "fotmob_clickhouse": "FotMob Bronze -> ClickHouse",
    "fotmob_silver": "FotMob Silver",
    "fotmob_gold": "FotMob Gold",
}

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def _run_script(script_path: Path, args: List[str]) -> int:
    """Run a canonical script entry point and return its exit code."""
    command = [sys.executable, str(script_path), *args]
    result = subprocess.run(command, cwd=PROJECT_ROOT)
    return result.returncode


@dataclass
class PipelineConfig:
    """Configuration for pipeline execution."""

    skip_fotmob: bool = False
    skip_bronze: bool = False
    skip_clickhouse: bool = False
    skip_silver: bool = False
    skip_gold: bool = False
    bronze_only: bool = False
    silver_only: bool = False
    gold_only: bool = False
    force: bool = False
    debug: bool = False


@dataclass
class PipelineResults:
    """Results tracking for pipeline execution."""

    fotmob_bronze: List[StepResult] = field(default_factory=list)
    fotmob_clickhouse: List[StepResult] = field(default_factory=list)
    fotmob_silver: List[StepResult] = field(default_factory=list)
    fotmob_gold: List[StepResult] = field(default_factory=list)

    def add_result(self, category: str, result: StepResult) -> None:
        """Add a result to the appropriate category."""
        getattr(self, category).append(result)

    def all_successful(self) -> bool:
        """Check if all steps were successful."""
        categories = ["fotmob_bronze", "fotmob_clickhouse", "fotmob_silver", "fotmob_gold"]
        for category in categories:
            results = getattr(self, category)
            if results and not all(r.success for r in results):
                return False
        return True

    def get_summary(self) -> Dict[str, Dict[str, Any]]:
        """Get summary statistics for all categories."""
        summary = {}
        categories = ["fotmob_bronze", "fotmob_clickhouse", "fotmob_silver", "fotmob_gold"]
        for category in categories:
            results = getattr(self, category)
            if results:
                successful = sum(1 for r in results if r.success)
                failed = len(results) - successful
                total_time = sum(r.elapsed_time for r in results)
                failed_dates = [r.name.split(" - ")[-1] for r in results if not r.success]
                summary[category] = {
                    "total": len(results),
                    "successful": successful,
                    "failed": failed,
                    "total_time": total_time,
                    "failed_dates": failed_dates,
                }
        return summary


def create_argument_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description=(
            "Unified Pipeline Orchestrator - "
            "Runs FotMob bronze scraping, ClickHouse bronze load, silver, and gold stages"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Full Pipeline:
    python3 scripts/orchestration/pipeline.py 20251113
    python3 scripts/orchestration/pipeline.py --date 20251113
    python3 scripts/orchestration/pipeline.py --start-date 20251101 --end-date 20251107
    python3 scripts/orchestration/pipeline.py --month 202511
    python3 scripts/orchestration/pipeline.py --full-history
  Partial Pipeline:
    python3 scripts/orchestration/pipeline.py 20251113 --bronze-only
    python3 scripts/orchestration/pipeline.py 20251113 --silver-only
    python3 scripts/orchestration/pipeline.py 20251113 --gold-only
    python3 scripts/orchestration/pipeline.py 20251113 --skip-bronze
    python3 scripts/orchestration/pipeline.py 20251113 --skip-fotmob
  Options:
    python3 scripts/orchestration/pipeline.py 20251113 --force
        """,
    )
    _add_date_arguments(parser)
    _add_pipeline_control_arguments(parser)
    _add_option_arguments(parser)
    return parser


def _add_date_arguments(parser: argparse.ArgumentParser) -> None:
    """Add date-related arguments to parser."""
    date_group = parser.add_mutually_exclusive_group(required=True)
    date_group.add_argument(
        "date",
        type=str,
        nargs="?",
        help=(
            "Date to process (YYYYMMDD format). " "Required unless --start-date or --month is used."
        ),
    )
    date_group.add_argument(
        "--single-date",
        type=str,
        help="Process a single date (YYYYMMDD format). Equivalent to the positional date argument.",
    )
    date_group.add_argument(
        "--date",
        dest="named_date",
        type=str,
        help="Process a single date (YYYYMMDD format).",
    )
    date_group.add_argument(
        "--start-date", type=str, help="Start date for range processing (YYYYMMDD format)"
    )
    date_group.add_argument(
        "--month",
        type=str,
        help="Process entire month (YYYYMM format, e.g., 202511 for November 2025)",
    )
    date_group.add_argument(
        "--full-history",
        action="store_true",
        help="Load all available Historical Bronze files and rebuild Silver and Gold",
    )
    parser.add_argument(
        "--end-date",
        type=str,
        help=(
            "End date for range processing (YYYYMMDD format). " "Required if --start-date is used."
        ),
    )


def _add_pipeline_control_arguments(parser: argparse.ArgumentParser) -> None:
    """Add pipeline control arguments to parser."""
    parser.add_argument(
        "--bronze-only",
        action="store_true",
        help="Run bronze scraping only (skip ClickHouse loading, silver, gold)",
    )
    parser.add_argument(
        "--silver-only",
        action="store_true",
        help="Run silver processing only (skip bronze, ClickHouse loading, gold)",
    )
    parser.add_argument(
        "--gold-only",
        action="store_true",
        help="Run gold processing only (skip bronze, ClickHouse loading, silver)",
    )
    parser.add_argument(
        "--skip-bronze",
        action="store_true",
        help="Skip bronze scraping (run ClickHouse bronze loading, silver, and/or gold only)",
    )
    parser.add_argument(
        "--skip-fotmob",
        action="store_true",
        help="Skip all FotMob processing (bronze + ClickHouse + silver + gold)",
    )
    parser.add_argument(
        "--skip-clickhouse",
        action="store_true",
        help="Skip ClickHouse loading",
    )
    parser.add_argument(
        "--skip-silver",
        action="store_true",
        help="Skip silver processing",
    )
    parser.add_argument(
        "--skip-gold",
        action="store_true",
        help="Skip gold processing",
    )


def _add_option_arguments(parser: argparse.ArgumentParser) -> None:
    """Add option arguments to parser."""
    parser.add_argument(
        "--force", action="store_true", help="Force re-scrape/reload even if data exists"
    )
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")


def parse_arguments() -> argparse.Namespace:
    """Parse and validate command-line arguments."""
    parser = create_argument_parser()
    args = parser.parse_args()
    _validate_month_argument(parser, args)
    _validate_date_range_arguments(parser, args)
    _validate_single_date_argument(parser, args)
    _validate_pipeline_flags(parser, args)
    return args


def _validate_pipeline_flags(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    """Validate pipeline-only flag combinations."""
    only_flags = [args.bronze_only, args.silver_only, args.gold_only]
    if sum(bool(f) for f in only_flags) > 1:
        parser.error("Use only one of --bronze-only, --silver-only, --gold-only")
    if args.full_history and args.bronze_only:
        parser.error("--full-history cannot use --bronze-only because scraping is excluded")


def _validate_month_argument(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    """Validate month argument if provided."""
    if not args.month:
        return
    is_valid, error_msg = validate_date_format(args.month, "YYYYMM")
    if not is_valid:
        parser.error(error_msg)
    if args.end_date:
        parser.error("Cannot use --end-date with --month option")


def _validate_date_range_arguments(
    parser: argparse.ArgumentParser, args: argparse.Namespace
) -> None:
    """Validate date range arguments."""
    if not args.start_date:
        return
    if not args.end_date:
        parser.error("--end-date is required when using --start-date")
    is_valid, error_msg = validate_date_format(args.start_date, "YYYYMMDD")
    if not is_valid:
        parser.error(error_msg)
    is_valid, error_msg = validate_date_format(args.end_date, "YYYYMMDD")
    if not is_valid:
        parser.error(error_msg)
    if args.end_date < args.start_date:
        parser.error(
            f"End date ({args.end_date}) cannot be before start date " f"({args.start_date})"
        )


def _validate_single_date_argument(
    parser: argparse.ArgumentParser, args: argparse.Namespace
) -> None:
    """Validate single date argument."""
    named_date = args.single_date or args.named_date
    if named_date:
        if args.date:
            parser.error("Use either the positional date or a named date selector, not both")
        args.date = named_date
    if not args.date:
        return
    is_valid, error_msg = validate_date_format(args.date, "YYYYMMDD")
    if not is_valid:
        parser.error(error_msg)


def create_pipeline_config(args: argparse.Namespace) -> PipelineConfig:
    """Create PipelineConfig from parsed arguments."""
    return PipelineConfig(
        skip_fotmob=args.skip_fotmob,
        skip_bronze=args.skip_bronze,
        skip_clickhouse=args.skip_clickhouse,
        skip_silver=args.skip_silver,
        skip_gold=args.skip_gold,
        bronze_only=args.bronze_only,
        silver_only=args.silver_only,
        gold_only=args.gold_only,
        force=args.force,
        debug=args.debug,
    )


def create_date_info(args: argparse.Namespace) -> DateRangeInfo:
    """Create DateRangeInfo from parsed arguments."""
    if args.full_history:
        return DateRangeInfo(
            dates=[],
            display_text="Full history",
            mode_text="full_history",
            log_suffix="full_history",
        )
    return create_date_range_info(
        date=args.date,
        start_date=args.start_date,
        end_date=args.end_date,
        month=args.month,
    )


def run_step(
    name: str,
    operation: str,
    runner: Callable[[], int],
    continue_on_error: bool = False,
    date_str: Optional[str] = None,
) -> StepResult:
    """
    Run a pipeline step and return result.
    Args:
        name: Step name for logging
        operation: Human-readable operation description
        runner: Callable that executes the step and returns an exit code
        continue_on_error: Whether to continue on failure
        date_str: Date being processed (for alerts)
    Returns:
        StepResult with execution details
    """
    logger = get_logger("pipeline")
    _log_step_header(logger, name, operation)
    start_time = time.time()
    exit_code = _execute_runner(runner, logger)
    elapsed_time = time.time() - start_time
    success = exit_code == 0
    step_result = StepResult(
        name=name,
        success=success,
        exit_code=exit_code,
        elapsed_time=elapsed_time,
        date_str=date_str,
    )
    _handle_step_result(logger, step_result, continue_on_error)
    return step_result


def _log_step_header(logger: logging.Logger, name: str, operation: str) -> None:
    """Log step header information."""
    logger.info("\n" + "=" * 80)
    logger.info("STEP: %s", name)
    logger.info("=" * 80)
    logger.info("Operation: %s", operation)
    logger.info("=" * 80 + "\n")


def _execute_runner(runner: Callable[[], int], logger: logging.Logger) -> int:
    """Execute a step runner and normalize the resulting exit code."""
    try:
        result = runner()
        return int(result) if result is not None else 0
    except SystemExit as exc:
        code = exc.code if isinstance(exc.code, int) else 1
        return code
    except (RuntimeError, OSError, ValueError) as exc:
        logger.error("Step failed with runtime error: %s", exc, exc_info=True)
        return 1


def _handle_step_result(
    logger: logging.Logger, result: StepResult, continue_on_error: bool
) -> None:
    """Handle step result logging and alerting."""
    if result.success:
        logger.info(f"\n[SUCCESS] {result.name} completed in " f"{result.elapsed_time:.1f}s")
        return
    if continue_on_error:
        logger.warning(
            f"\n[WARNING] {result.name} failed (exit code: "
            f"{result.exit_code}) but continuing..."
        )
    else:
        logger.error(f"\n[ERROR] {result.name} failed (exit code: " f"{result.exit_code})")
    _send_step_failure_alert(result)


def _send_step_failure_alert(result: StepResult) -> None:
    """Send alert for step failure."""
    telegram_client = TelegramClient()
    telegram_client.render_and_send(
        "error_alert.html.j2",
        ErrorAlertData(
            level="ERROR",
            title=f"Pipeline Step Failed: {result.name}",
            message=(
                f"Step '{result.name}' failed with exit code "
                f"{result.exit_code}.\n\nElapsed time: "
                f"{result.elapsed_time:.1f}s"
            ),
            context={
                "step_name": result.name,
                "exit_code": str(result.exit_code),
                "elapsed_time": f"{result.elapsed_time:.1f}s",
                "date": result.date_str or "",
                "error_output": "Check logs for details",
            },
        ),
    )


def run_fotmob_bronze(date_str: str, config: PipelineConfig) -> StepResult:
    """Run FotMob bronze scraping for a date."""
    script_path = PROJECT_ROOT / "scripts" / "bronze" / "scrape_fotmob.py"
    argv = [date_str]
    if config.force:
        argv.append("--force")
    if config.debug:
        argv.append("--debug")
    return run_step(
        f"FotMob Bronze - {date_str}",
        f"{script_path} {' '.join(argv)}",
        lambda: _run_script(script_path, argv),
        date_str=date_str,
    )


def run_clickhouse_load(
    scraper: str,
    date_str: str,
    config: PipelineConfig,
) -> StepResult:
    """Load data to ClickHouse for a scraper and date."""
    script_path = PROJECT_ROOT / "scripts" / "bronze" / "load_clickhouse.py"
    argv = ["--date", date_str]
    if config.force:
        argv.append("--force")
    return run_step(
        f"ClickHouse Load - {scraper} - {date_str}",
        f"{script_path} {' '.join(argv)}",
        lambda: _run_script(script_path, argv),
        date_str=date_str,
    )


def run_clickhouse_load_month(
    scraper: str,
    month_str: str,
    config: PipelineConfig,
) -> StepResult:
    """Load data to ClickHouse for a scraper and month."""
    script_path = PROJECT_ROOT / "scripts" / "bronze" / "load_clickhouse.py"
    argv = ["--month", month_str]
    if config.force:
        argv.append("--force")
    return run_step(
        f"ClickHouse Load - {scraper} - Month {month_str}",
        f"{script_path} {' '.join(argv)}",
        lambda: _run_script(script_path, argv),
        date_str=month_str,
    )


def run_silver_process(
    date_str: str,
) -> StepResult:
    """Run silver processing for a date."""
    script_path = PROJECT_ROOT / "scripts" / "silver" / "load_clickhouse.py"
    argv: List[str] = ["--date", date_str]
    return run_step(
        f"Silver Process - {date_str}",
        str(script_path),
        lambda: _run_script(script_path, argv),
        date_str=date_str,
    )


def run_silver_process_month(
    month_str: str,
) -> StepResult:
    """Run silver processing for a month."""
    script_path = PROJECT_ROOT / "scripts" / "silver" / "load_clickhouse.py"
    argv: List[str] = ["--month", month_str]
    return run_step(
        f"Silver Process - Month {month_str}",
        str(script_path),
        lambda: _run_script(script_path, argv),
        date_str=month_str,
    )


def run_gold_process(
    date_str: str,
) -> StepResult:
    """Run gold processing for a date."""
    script_path = PROJECT_ROOT / "scripts" / "gold" / "load_clickhouse_gold.py"
    argv: List[str] = ["--date", date_str]
    return run_step(
        f"Gold Process - {date_str}",
        str(script_path),
        lambda: _run_script(script_path, argv),
        date_str=date_str,
    )


def run_gold_process_month(
    month_str: str,
) -> StepResult:
    """Run gold processing for a month."""
    script_path = PROJECT_ROOT / "scripts" / "gold" / "load_clickhouse_gold.py"
    argv: List[str] = ["--month", month_str]
    return run_step(
        f"Gold Process - Month {month_str}",
        str(script_path),
        lambda: _run_script(script_path, argv),
        date_str=month_str,
    )


def setup_pipeline_logging(
    project_root: Path, date_info: DateRangeInfo, debug: bool = False
) -> tuple[logging.Logger, Path]:
    """Setup logging for pipeline execution."""
    log_file = project_root / "logs" / "pipeline.log"
    log_file.parent.mkdir(parents=True, exist_ok=True)
    logger = setup_logging(name="pipeline", log_dir="logs", log_level="DEBUG" if debug else "INFO")
    return logger, log_file


def log_pipeline_header(
    logger: logging.Logger, date_info: DateRangeInfo, config: PipelineConfig, log_file: Path
) -> None:
    """Log pipeline header information."""
    logger.info("\n" + "=" * 80)
    logger.info("UNIFIED PIPELINE ORCHESTRATOR")
    logger.info("=" * 80)
    logger.info(f"Mode:             {date_info.display_text}")
    logger.info(f"Total dates:      {len(date_info.dates)}")
    logger.info(f"Skip FotMob:      {config.skip_fotmob}")
    logger.info(f"Skip Bronze:      {config.skip_bronze}")
    logger.info(
        f"Skip ClickHouse:  "
        f"{config.skip_clickhouse or config.bronze_only or config.silver_only or config.gold_only}"
    )
    logger.info(f"Skip Silver:      {config.skip_silver or config.bronze_only or config.gold_only}")
    logger.info(f"Skip Gold:        {config.skip_gold or config.bronze_only or config.silver_only}")
    logger.info(f"Force mode:       {config.force}")
    logger.info(f"Log file:         {log_file}")
    logger.info("=" * 80)


def process_bronze_scraping(
    date_str: str,
    config: PipelineConfig,
    results: PipelineResults,
) -> Optional[StepResult]:
    """Process bronze scraping for a single date."""
    if not config.skip_fotmob and not config.skip_bronze:
        result = run_fotmob_bronze(date_str, config)
        results.add_result("fotmob_bronze", result)
        return result
    return None


def process_clickhouse_loading_per_date(
    date_str: str,
    config: PipelineConfig,
    results: PipelineResults,
) -> Optional[StepResult]:
    """Process ClickHouse loading for a single date."""
    if not config.skip_fotmob:
        result = run_clickhouse_load("fotmob", date_str, config)
        results.add_result("fotmob_clickhouse", result)
        return result
    return None


def process_clickhouse_loading_monthly(
    month_str: str,
    config: PipelineConfig,
    results: PipelineResults,
    logger: logging.Logger,
) -> Optional[StepResult]:
    """Process ClickHouse loading for monthly mode."""
    logger.info(f"\n\n{'#' * 80}")
    logger.info("# Loading to ClickHouse (Monthly Mode)")
    logger.info(f"{'#' * 80}\n")
    if not config.skip_fotmob:
        result = run_clickhouse_load_month("fotmob", month_str, config)
        results.add_result("fotmob_clickhouse", result)
        return result
    return None


def process_silver_per_date(
    date_str: str,
    config: PipelineConfig,
    results: PipelineResults,
) -> Optional[StepResult]:
    """Process silver layer for a single date."""
    if not config.skip_fotmob:
        result = run_silver_process(date_str)
        results.add_result("fotmob_silver", result)
        return result
    return None


def process_silver_monthly(
    month_str: str,
    config: PipelineConfig,
    results: PipelineResults,
) -> Optional[StepResult]:
    """Process silver layer for monthly mode."""
    if not config.skip_fotmob:
        result = run_silver_process_month(month_str)
        results.add_result("fotmob_silver", result)
        return result
    return None


def process_gold_per_date(
    date_str: str,
    config: PipelineConfig,
    results: PipelineResults,
) -> Optional[StepResult]:
    """Process gold layer for a single date."""
    if not config.skip_fotmob:
        result = run_gold_process(date_str)
        results.add_result("fotmob_gold", result)
        return result
    return None


def process_gold_monthly(
    month_str: str,
    config: PipelineConfig,
    results: PipelineResults,
) -> Optional[StepResult]:
    """Process gold layer for monthly mode."""
    if not config.skip_fotmob:
        result = run_gold_process_month(month_str)
        results.add_result("fotmob_gold", result)
        return result
    return None


def process_full_history(
    config: PipelineConfig,
    results: PipelineResults,
) -> None:
    """Run every non-scraping warehouse stage in explicit full-history mode."""
    clickhouse_result: Optional[StepResult] = None
    if (
        not config.skip_fotmob
        and not config.skip_clickhouse
        and not config.bronze_only
        and not config.silver_only
        and not config.gold_only
    ):
        script_path = PROJECT_ROOT / "scripts" / "bronze" / "load_clickhouse.py"
        argv = ["--full-history"]
        if config.force:
            argv.append("--force")
        clickhouse_result = run_step(
            "ClickHouse Load - FotMob - Full History",
            f"{script_path} {' '.join(argv)}",
            lambda: _run_script(script_path, argv),
            date_str="full-history",
        )
        results.add_result("fotmob_clickhouse", clickhouse_result)
    if clickhouse_result is not None and not clickhouse_result.success:
        return

    silver_result: Optional[StepResult] = None
    if (
        not config.skip_fotmob
        and not config.skip_silver
        and not config.bronze_only
        and not config.gold_only
    ):
        script_path = PROJECT_ROOT / "scripts" / "silver" / "load_clickhouse.py"
        silver_result = run_step(
            "Silver Process - Full History",
            f"{script_path} --full-history",
            lambda: _run_script(script_path, ["--full-history"]),
            date_str="full-history",
        )
        results.add_result("fotmob_silver", silver_result)
    if silver_result is not None and not silver_result.success:
        return

    if (
        not config.skip_fotmob
        and not config.skip_gold
        and not config.bronze_only
        and not config.silver_only
    ):
        script_path = PROJECT_ROOT / "scripts" / "gold" / "load_clickhouse_gold.py"
        results.add_result(
            "fotmob_gold",
            run_step(
                "Gold Process - Full History",
                f"{script_path} --full-history",
                lambda: _run_script(script_path, ["--full-history"]),
                date_str="full-history",
            ),
        )


def log_pipeline_summary(
    logger: logging.Logger,
    results: PipelineResults,
    total_dates: int,
    elapsed_time: float,
    log_file: Path,
) -> None:
    """Log pipeline summary."""
    logger.info("\n\n" + "=" * 80)
    logger.info("PIPELINE SUMMARY")
    logger.info("=" * 80)
    logger.info(f"Total time: {format_elapsed_time(elapsed_time)}")
    logger.info(f"Dates processed: {total_dates}")
    logger.info(f"Log file: {log_file}")
    logger.info("\nResults by step:")
    summary = results.get_summary()
    for step_name, stats in summary.items():
        display_name = RESULT_CATEGORIES.get(step_name, step_name.replace("_", " ").title())
        logger.info(f"\n  {display_name}:")
        logger.info(f"    Successful: {stats['successful']}/{stats['total']}")
        logger.info(f"    Failed: {stats['failed']}")
        logger.info(f"    Total time: {stats['total_time']:.1f}s")
        if stats["failed"] > 0:
            logger.info(f"    Failed dates: {stats['failed_dates']}")
    logger.info("\n" + "=" * 80)


def run_pipeline(args: argparse.Namespace) -> int:
    """
    Run the complete pipeline.
    Args:
        args: Parsed command-line arguments
    Returns:
        Exit code (0 for success, 1 for failure)
    """
    project_root = get_project_root()
    config = create_pipeline_config(args)
    date_info = create_date_info(args)
    logger, log_file = setup_pipeline_logging(project_root, date_info, config.debug)
    log_pipeline_header(logger, date_info, config, log_file)
    results = PipelineResults()
    pipeline_start = time.time()
    if args.full_history:
        logger.info("Scraping is intentionally excluded from full-history pipeline mode")
        process_full_history(config, results)
    for idx, date_str in enumerate(date_info.dates, 1):
        logger.info(f"\n\n{'#' * 80}")
        logger.info(f"# Processing date {idx}/{len(date_info.dates)}: {date_str}")
        logger.info(f"{'#' * 80}\n")
        bronze_result: Optional[StepResult] = None
        if not config.silver_only and not config.gold_only:
            bronze_result = process_bronze_scraping(date_str, config, results)
        if bronze_result is not None and not bronze_result.success:
            logger.error(
                "Skipping downstream stages for %s because FotMob Bronze failed",
                date_str,
            )
            continue

        clickhouse_result: Optional[StepResult] = None
        if (
            not args.month
            and not config.skip_clickhouse
            and not config.bronze_only
            and not config.silver_only
            and not config.gold_only
        ):
            clickhouse_result = process_clickhouse_loading_per_date(date_str, config, results)
        if clickhouse_result is not None and not clickhouse_result.success:
            logger.error(
                "Skipping Silver and Gold for %s because ClickHouse Bronze load failed",
                date_str,
            )
            continue

        silver_result: Optional[StepResult] = None
        if (
            not args.month
            and not config.skip_silver
            and not config.bronze_only
            and not config.gold_only
        ):
            silver_result = process_silver_per_date(date_str, config, results)
        if silver_result is not None and not silver_result.success:
            logger.error("Skipping Gold for %s because Silver failed", date_str)
            continue

        if (
            not args.month
            and not config.skip_gold
            and not config.bronze_only
            and not config.silver_only
        ):
            process_gold_per_date(date_str, config, results)

    if (
        args.month
        and results.fotmob_bronze
        and not all(r.success for r in results.fotmob_bronze)
    ):
        logger.error("Skipping monthly warehouse stages because one or more Bronze dates failed")
        pipeline_elapsed = time.time() - pipeline_start
        log_pipeline_summary(logger, results, len(date_info.dates), pipeline_elapsed, log_file)
        return 1

    monthly_clickhouse_result: Optional[StepResult] = None
    if (
        args.month
        and not config.skip_clickhouse
        and not config.bronze_only
        and not config.silver_only
        and not config.gold_only
    ):
        monthly_clickhouse_result = process_clickhouse_loading_monthly(
            args.month, config, results, logger
        )
    if monthly_clickhouse_result is not None and not monthly_clickhouse_result.success:
        logger.error("Skipping monthly Silver and Gold because ClickHouse Bronze load failed")
        pipeline_elapsed = time.time() - pipeline_start
        log_pipeline_summary(logger, results, len(date_info.dates), pipeline_elapsed, log_file)
        return 1

    monthly_silver_result: Optional[StepResult] = None
    if args.month and not config.skip_silver and not config.bronze_only and not config.gold_only:
        monthly_silver_result = process_silver_monthly(args.month, config, results)
    if monthly_silver_result is not None and not monthly_silver_result.success:
        logger.error("Skipping monthly Gold because Silver failed")
        pipeline_elapsed = time.time() - pipeline_start
        log_pipeline_summary(logger, results, len(date_info.dates), pipeline_elapsed, log_file)
        return 1

    if args.month and not config.skip_gold and not config.bronze_only and not config.silver_only:
        process_gold_monthly(args.month, config, results)
    pipeline_elapsed = time.time() - pipeline_start
    total_dates = len(date_info.dates) if not args.full_history else 0
    log_pipeline_summary(logger, results, total_dates, pipeline_elapsed, log_file)
    if results.all_successful():
        logger.info("[OK] Pipeline completed successfully!")
        return 0
    else:
        logger.warning("[WARN] Pipeline completed with some failures (see details above)")
        return 1


def main() -> int:
    """Main execution function."""
    args = parse_arguments()
    return run_pipeline(args)


if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger = get_logger("pipeline")
        logger.warning("\n\nPipeline interrupted by user. Exiting...")
        sys.exit(130)
    except (RuntimeError, OSError, ValueError) as e:
        logger = get_logger("pipeline")
        logger.error(f"\nFatal error: {e}", exc_info=True)
        sys.exit(1)
