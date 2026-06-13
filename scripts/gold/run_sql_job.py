"""Run selected Gold scenario and signal SQL jobs through the generic executor."""

import argparse
import sys
import time
from pathlib import Path
from typing import Optional

project_root = Path(__file__).resolve().parents[2]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from config.settings import settings
from scripts.gold.sql_jobs import (
    GoldJobKind,
    discover_gold_sql_jobs,
    execute_gold_sql_job,
    resolve_gold_sql_job,
)
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(description="Run selected Gold SQL jobs in ClickHouse")
    parser.add_argument(
        "--kind",
        choices=("scenario", "signal"),
        help="Gold SQL job kind to run. Omit to select both scenarios and signals.",
    )
    parser.add_argument(
        "--id",
        help="Gold SQL job id, for example sig_player_shooting_goals_shot_conversion_peak",
    )
    parser.add_argument(
        "--entity",
        choices=("match", "player", "team"),
        help="Signal entity filter for batch execution",
    )
    parser.add_argument(
        "--family",
        help="Signal family filter, for example shooting_goals or creativity_playmaking",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview selected SQL jobs without connecting to ClickHouse or executing SQL",
    )
    return parser.parse_args(argv)


def _kind_from_job_id(job_id: str) -> GoldJobKind:
    """Infer the Gold job kind from a job id prefix."""
    if job_id.startswith("scenario_"):
        return "scenario"
    if job_id.startswith(("sig_", "signal_")):
        return "signal"
    raise ValueError(
        "Gold SQL job id must start with scenario_, sig_, or signal_ when --kind is omitted"
    )


def _validate_selection(args: argparse.Namespace) -> int:
    """Validate CLI selection mode."""
    has_filter = bool(args.entity or args.family)
    if args.id and has_filter:
        logger.error("Use either --id or --entity/--family filters, not both")
        return 2
    if args.entity and args.family:
        logger.error("Use either --entity or --family as a signal selector, not both")
        return 2
    if has_filter and args.kind not in (None, "signal"):
        logger.error("--entity and --family filters are only supported for signal jobs")
        return 2
    return 0


def _selected_jobs(args: argparse.Namespace):
    """Resolve selected Gold SQL jobs from CLI arguments."""
    if args.id:
        inferred_kind = _kind_from_job_id(args.id)
        if args.kind and args.kind != inferred_kind:
            raise ValueError(f"--kind {args.kind} does not match Gold SQL job id: {args.id}")
        return [resolve_gold_sql_job(inferred_kind, args.id)]

    if args.kind:
        return discover_gold_sql_jobs(args.kind, entity=args.entity, family=args.family)

    if args.entity or args.family:
        return discover_gold_sql_jobs("signal", entity=args.entity, family=args.family)

    scenario_jobs = discover_gold_sql_jobs("scenario")
    signal_jobs = discover_gold_sql_jobs("signal")
    return [*scenario_jobs, *signal_jobs]


def _run_jobs(client: Optional[ClickHouseClient], jobs, *, dry_run: bool) -> tuple[int, int]:
    """Run selected jobs and return success/failure counts."""
    if not jobs:
        logger.error("No Gold SQL jobs matched the selection")
        return 0, 1

    success_count = 0
    failed_jobs: list[str] = []
    total_jobs = len(jobs)
    logger.info("Selected Gold SQL jobs: %s", total_jobs)
    for index, job in enumerate(jobs, start=1):
        started_at = time.perf_counter()
        logger.info("Running Gold %s SQL job %s/%s: %s", job.kind, index, total_jobs, job.job_id)
        try:
            if execute_gold_sql_job(client, job, dry_run=dry_run, log=logger):
                success_count += 1
                continue
        except Exception as error:
            logger.error("Gold %s SQL job raised an exception: %s", job.kind, error)

        logger.error(
            "Gold %s SQL job failed %s/%s: %s after %.2f seconds",
            job.kind,
            index,
            total_jobs,
            job.job_id,
            time.perf_counter() - started_at,
        )
        failed_jobs.append(job.job_id)

    if failed_jobs:
        logger.error("Failed Gold SQL jobs: %s", ", ".join(failed_jobs))
    logger.info(
        "Gold SQL job execution report | total=%s success=%s failed=%s",
        total_jobs,
        success_count,
        len(failed_jobs),
    )
    return success_count, len(failed_jobs)


def main(argv: Optional[list[str]] = None) -> int:
    """Run selected Gold SQL jobs."""
    global logger
    args = parse_args(argv)
    logger = setup_logging(
        name="gold_sql_job_runner",
        log_dir=settings.log_dir,
        log_level=settings.log_level,
    )

    selection_exit_code = _validate_selection(args)
    if selection_exit_code != 0:
        return selection_exit_code

    try:
        jobs = _selected_jobs(args)
    except ValueError as error:
        logger.error("Invalid Gold SQL job selection: %s", error)
        return 2

    if args.dry_run:
        _, failed_count = _run_jobs(None, jobs, dry_run=True)
        return 0 if failed_count == 0 else 1

    client = ClickHouseClient(
        host=settings.clickhouse_host,
        port=settings.clickhouse_port,
        username=settings.clickhouse_user,
        password=settings.clickhouse_password,
        database="default",
    )

    if not client.connect():
        logger.error("Failed to connect to ClickHouse")
        return 1

    try:
        _, failed_count = _run_jobs(client, jobs, dry_run=False)
        return 0 if failed_count == 0 else 1
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
