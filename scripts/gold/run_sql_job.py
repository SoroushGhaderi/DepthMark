"""Run one Gold scenario or signal SQL job through the generic executor."""

import argparse
import sys
from pathlib import Path
from typing import Optional

project_root = Path(__file__).resolve().parents[2]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from config.settings import settings
from scripts.gold.sql_jobs import execute_gold_sql_job, resolve_gold_sql_job
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(description="Run one Gold SQL job in ClickHouse")
    parser.add_argument(
        "--kind",
        choices=("scenario", "signal"),
        required=True,
        help="Gold SQL job kind to run",
    )
    parser.add_argument(
        "--id",
        required=True,
        help="Gold SQL job id, for example sig_player_shooting_goals_shot_conversion_peak",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview the selected SQL job without connecting to ClickHouse or executing SQL",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    """Run one selected Gold SQL job."""
    global logger
    args = parse_args(argv)
    logger = setup_logging(
        name="gold_sql_job_runner",
        log_dir=settings.log_dir,
        log_level=settings.log_level,
    )

    try:
        job = resolve_gold_sql_job(args.kind, args.id)
    except ValueError as error:
        logger.error("Invalid Gold SQL job selection: %s", error)
        return 2

    if args.dry_run:
        return 0 if execute_gold_sql_job(None, job, dry_run=True, log=logger) else 1

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
        return 0 if execute_gold_sql_job(client, job, dry_run=False, log=logger) else 1
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
