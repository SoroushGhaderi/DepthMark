"""Run FotMob gold layer orchestration in ClickHouse."""

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
from src.services.gold.fotmob_gold_service import GoldService, GoldRunResult
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.gold_databases import gold_db, gold_signals_db
from src.utils.layer_completion_alerts import send_layer_completion_alert
from src.utils.layer_contracts import LayerContractError
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Process FotMob gold layer in ClickHouse")
    parser.add_argument(
        "--part",
        choices=("all", "signals"),
        default="all",
        help="Which signal job groups to run. Scenario execution is disabled for now.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview gold SQL/scenario/signal jobs without executing SQL or subprocesses",
    )
    return parser.parse_args(argv)


def main(argv=None) -> int:
    global logger
    stage_start = time.perf_counter()
    args = parse_args(argv)
    logger = setup_logging(
        name="clickhouse_gold_orchestrator",
        log_dir=settings.log_dir,
        log_level=settings.log_level,
    )
    scenario_db = "disabled"
    signal_db = gold_signals_db()
    metadata_db = gold_db()

    if args.dry_run:
        logger.info("Running gold loader in dry-run mode (no SQL will be executed)")
        logger.info("Gold scenario database: %s", scenario_db)
        logger.info("Gold signal database: %s", signal_db)
        logger.info("Gold metadata database: %s", metadata_db)
        service = GoldService(client=None, metadata_db=metadata_db)
        result = service.run(part=args.part, dry_run=True)
        failed_count = result.scenario_failed_count + result.signal_failed_count
        if result.signal_activation_exit_code != 0:
            failed_count += 1
        total_jobs = (
            result.scenario_success_count
            + result.scenario_failed_count
            + result.signal_success_count
            + result.signal_failed_count
        )
        successful_jobs = result.scenario_success_count + result.signal_success_count
        scenario_success_rate = (successful_jobs / total_jobs * 100) if total_jobs > 0 else 0
        send_layer_completion_alert(
            layer="gold",
            summary_message="Gold SQL/signal dry-run finished.",
            scope="dry-run",
            success=failed_count == 0,
            duration_seconds=time.perf_counter() - stage_start,
            detail_lines=[
                f"SQL files planned: <b>{result.sql_file_count}</b>",
                "Scenario failures: <b>0</b>",
                f"Signal failures: <b>{result.signal_failed_count}</b>",
                f"Signal activation builder exit code: <b>{result.signal_activation_exit_code}</b>",
            ],
            insight_lines=[
                f"Signal pass projection: <b>{scenario_success_rate:.1f}%</b>",
                "Dry-run mode: <b>no writes performed</b>",
            ],
        )
        if failed_count > 0:
            return 1
        logger.info("Gold dry-run completed successfully")
        return 0

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
            layer="gold",
            summary_message="Gold processing finished with connection failure.",
            scope="runtime",
            success=False,
            duration_seconds=time.perf_counter() - stage_start,
            detail_lines=[
                "SQL files executed: <b>0</b>",
                "Scenario failures: <b>0</b>",
                "Signal failures: <b>0</b>",
                "Contract checks: <b>not run</b>",
            ],
        )
        return 1

    exit_code = 0
    try:
        service = GoldService(client=client, metadata_db=metadata_db)
        result = service.run(part=args.part, dry_run=False)
        exit_code = result.exit_code
        return exit_code
    except LayerContractError as contract_error:
        logger.error("Gold layer contract assertion failed", error=str(contract_error))
        exit_code = 1
        return exit_code
    finally:
        client.disconnect()
        total_jobs = (
            result.scenario_success_count
            + result.scenario_failed_count
            + result.signal_success_count
            + result.signal_failed_count
        )
        scenario_success_rate = (
            ((result.scenario_success_count + result.signal_success_count) / total_jobs * 100)
            if total_jobs > 0
            else 0
        )
        summary = "Gold SQL + signal processing finished."
        send_layer_completion_alert(
            layer="gold",
            summary_message=summary,
            scope="runtime",
            success=exit_code == 0,
            duration_seconds=time.perf_counter() - stage_start,
            detail_lines=[
                f"SQL files executed: <b>{result.sql_file_count}</b>",
                "Scenarios succeeded: <b>0</b>",
                "Scenario failures: <b>0</b>",
                f"Signals succeeded: <b>{result.signal_success_count}</b>",
                f"Signal failures: <b>{result.signal_failed_count}</b>",
                f"Signal activation builder exit code: <b>{result.signal_activation_exit_code}</b>",
                f"Contract checks: <b>{'passed' if result.contracts_checked else 'failed or skipped'}</b>",
            ],
            insight_lines=[
                f"Signal success rate: <b>{scenario_success_rate:.1f}%</b>",
                (
                    "Analytics quality signal: <b>gold contracts passed</b>"
                    if result.contracts_checked
                    else "Analytics quality signal: <b>contract check failed or was skipped</b>"
                ),
            ],
        )


if __name__ == "__main__":
    raise SystemExit(main())
