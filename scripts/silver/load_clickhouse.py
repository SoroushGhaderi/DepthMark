"""Load FotMob silver data into ClickHouse tables."""

import argparse
import sys
import time
from pathlib import Path
from typing import Optional

project_root = Path(__file__).resolve().parents[2]
scripts_dir = Path(__file__).resolve().parents[1]
for candidate in (str(project_root), str(scripts_dir)):
    if candidate not in sys.path:
        sys.path.insert(0, candidate)

from config.settings import get_settings
from src.services.silver.fotmob_silver_service import SilverRunResult, SilverService
from src.services.telegram import LayerAlertData, TelegramClient
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.layer_contracts import LayerContractError
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load FotMob silver SQL into ClickHouse")
    parser.add_argument(
        "--single-date",
        type=str,
        help="Process a single date (YYYYMMDD format). Reserved for interface consistency; silver currently processes all pending SQL jobs.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview silver load jobs without executing SQL or optimizing tables",
    )
    return parser.parse_args(argv)


def main(argv=None) -> int:
    global logger
    stage_start = time.perf_counter()
    args = parse_args(argv)
    settings = get_settings()
    logger = setup_logging(
        name="clickhouse_silver_loader",
        log_dir=settings.log_dir,
        log_level=settings.log_level,
    )
    if args.dry_run:
        logger.info("Running silver loader in dry-run mode (no SQL will be executed)")
        service = SilverService(client=None)
        result = service.run(dry_run=True)
        completion_rate = (
            (result.completed_jobs / result.total_jobs * 100) if result.total_jobs > 0 else 0
        )
        telegram_client = TelegramClient()
        telegram_client.render_and_send(
            "layer_alert.html.j2",
            LayerAlertData(
                layer="silver",
                success=result.exit_code == 0,
                scope="dry-run",
                duration_seconds=time.perf_counter() - stage_start,
                details={
                    "Jobs planned": str(result.total_jobs),
                    "Jobs completed": str(result.completed_jobs),
                },
                insights={
                    "Completion rate": f"{completion_rate:.1f}%",
                    "Mode": "dry-run (no writes)",
                },
            ),
        )
        if result.exit_code == 0:
            logger.info("Silver dry-run completed successfully")
        return result.exit_code

    client = ClickHouseClient(
        host=settings.clickhouse_host,
        port=settings.clickhouse_port,
        username=settings.clickhouse_user,
        password=settings.clickhouse_password,
        database="default",
    )
    if not client.connect():
        logger.error("Failed to connect to ClickHouse")
        telegram_client = TelegramClient()
        telegram_client.render_and_send(
            "layer_alert.html.j2",
            LayerAlertData(
                layer="silver",
                success=False,
                scope="runtime",
                duration_seconds=time.perf_counter() - stage_start,
                details={
                    "Jobs planned": "0",
                    "Jobs completed": "0",
                    "Contract checks": "not run",
                },
            ),
        )
        return 1

    exit_code = 0
    try:
        service = SilverService(client=client)
        result = service.run(dry_run=False)
        exit_code = result.exit_code
        return exit_code
    except LayerContractError as contract_error:
        logger.error("Silver layer contract assertion failed", error=str(contract_error))
        exit_code = 1
        return exit_code
    finally:
        client.disconnect()
        completion_rate = (
            (result.completed_jobs / result.total_jobs * 100) if result.total_jobs > 0 else 0
        )
        telegram_client = TelegramClient()
        telegram_client.render_and_send(
            "layer_alert.html.j2",
            LayerAlertData(
                layer="silver",
                success=exit_code == 0,
                scope="runtime",
                duration_seconds=time.perf_counter() - stage_start,
                details={
                    "Jobs planned": str(result.total_jobs),
                    "Jobs completed": str(result.completed_jobs),
                    "Contract checks": "passed"
                    if result.contracts_checked
                    else "failed or skipped",
                },
                insights={
                    "Completion rate": f"{completion_rate:.1f}%",
                    "Quality signal": "contracts passed"
                    if result.contracts_checked
                    else "contract check failed",
                },
            ),
        )


if __name__ == "__main__":
    raise SystemExit(main())
