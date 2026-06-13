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

from config.settings import settings
from src.services.silver.fotmob_silver_service import SilverService, SilverRunResult
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.layer_completion_alerts import send_layer_completion_alert
from src.utils.layer_contracts import LayerContractError
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load FotMob silver SQL into ClickHouse")
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
        send_layer_completion_alert(
            layer="silver",
            summary_message="Silver transformations dry-run finished.",
            scope="dry-run",
            success=result.exit_code == 0,
            duration_seconds=time.perf_counter() - stage_start,
            detail_lines=[
                f"Jobs planned: <b>{result.total_jobs}</b>",
                f"Jobs completed: <b>{result.completed_jobs}</b>",
            ],
            insight_lines=[
                f"Transformation completion rate: <b>{completion_rate:.1f}%</b>",
                "Dry-run mode: <b>no writes performed</b>",
            ],
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
        send_layer_completion_alert(
            layer="silver",
            summary_message="Silver transformations finished with connection failure.",
            scope="runtime",
            success=False,
            duration_seconds=time.perf_counter() - stage_start,
            detail_lines=[
                "Jobs planned: <b>0</b>",
                "Jobs completed: <b>0</b>",
                "Contract checks: <b>not run</b>",
            ],
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
        send_layer_completion_alert(
            layer="silver",
            summary_message="Silver transformations and validations finished.",
            scope="runtime",
            success=exit_code == 0,
            duration_seconds=time.perf_counter() - stage_start,
            detail_lines=[
                f"Jobs planned: <b>{result.total_jobs}</b>",
                f"Jobs completed: <b>{result.completed_jobs}</b>",
                f"Contract checks: <b>{'passed' if result.contracts_checked else 'failed or skipped'}</b>",
            ],
            insight_lines=[
                f"Transformation completion rate: <b>{completion_rate:.1f}%</b>",
                (
                    "Data quality signal: <b>contracts passed</b>"
                    if result.contracts_checked
                    else "Data quality signal: <b>contract check failed or was skipped</b>"
                ),
            ],
        )


if __name__ == "__main__":
    raise SystemExit(main())
