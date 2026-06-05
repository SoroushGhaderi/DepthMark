"""Run FotMob gold layer orchestration in ClickHouse."""

import argparse
import subprocess
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
from scripts.gold.sql_jobs import GoldSqlJob, discover_gold_sql_jobs, execute_gold_sql_job
from src.processors.gold.fotmob import FotMobGoldProcessor
from src.storage.clickhouse_client import ClickHouseClient
from src.storage.gold.fotmob import FotMobGoldStorage
from src.utils.gold_databases import gold_db, gold_signals_db
from src.utils.layer_completion_alerts import send_layer_completion_alert
from src.utils.layer_contracts import LayerContractError, assert_gold_layer_contracts
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)


def _selected_job_groups(part: str) -> tuple[list[GoldSqlJob], list[GoldSqlJob]]:
    scenario_jobs: list[GoldSqlJob] = []
    signal_jobs = (
        discover_gold_sql_jobs("signal", target_db=gold_signals_db())
        if part in ("all", "signals")
        else []
    )
    return scenario_jobs, signal_jobs


def _build_command(script_path: Path) -> list[str]:
    return [sys.executable, str(script_path)]


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


def _run_sql_jobs(
    job_name: str,
    jobs: list[GoldSqlJob],
    client: Optional[ClickHouseClient],
    dry_run: bool = False,
) -> tuple[int, int, list[str]]:
    if not jobs:
        logger.warning(
            "No gold %s SQL jobs found",
            job_name,
        )
        return 0, 0, []

    if dry_run:
        logger.info("[dry-run] Planned gold %s SQL jobs: %s", job_name, len(jobs))

    total_jobs = len(jobs)
    success_count = 0
    failed_jobs: list[str] = []

    for index, job in enumerate(jobs, start=1):
        logger.info(
            "Running gold %s SQL job %s/%s: %s",
            job_name,
            index,
            total_jobs,
            job.job_id,
        )
        script_start = time.perf_counter()
        try:
            if execute_gold_sql_job(client, job, dry_run=dry_run, log=logger):
                success_count += 1
                continue
        except Exception as error:
            logger.error("Gold %s SQL job raised an exception: %s", job_name, error)

        elapsed_seconds = time.perf_counter() - script_start
        logger.info(
            "Gold %s SQL job finished with failure %s/%s: %s in %.2f seconds",
            job_name,
            index,
            total_jobs,
            job.job_id,
            elapsed_seconds,
        )
        failed_jobs.append(job.job_id)

    failed_count = len(failed_jobs)
    logger.info(
        "Gold %s execution report | total=%s success=%s failed=%s",
        job_name,
        total_jobs,
        success_count,
        failed_count,
    )
    if failed_jobs:
        logger.error("Failed %s SQL jobs: %s", job_name, ", ".join(failed_jobs))

    return success_count, failed_count, failed_jobs


def _run_selected_jobs(
    part: str,
    dry_run: bool,
    client: Optional[ClickHouseClient] = None,
) -> tuple[int, int, int, int]:
    scenario_jobs, signal_jobs = _selected_job_groups(part)

    scenario_success_count = 0
    scenario_failed_count = 0
    signal_success_count = 0
    signal_failed_count = 0

    if scenario_jobs:
        scenario_success_count, scenario_failed_count, _ = _run_sql_jobs(
            job_name="scenario",
            jobs=scenario_jobs,
            client=client,
            dry_run=dry_run,
        )
    else:
        logger.info("Skipping scenario SQL jobs because --part=%s", part)

    if signal_jobs:
        signal_success_count, signal_failed_count, _ = _run_sql_jobs(
            job_name="signal",
            jobs=signal_jobs,
            client=client,
            dry_run=dry_run,
        )
    else:
        logger.info("Skipping signal SQL jobs because --part=%s", part)

    return (
        scenario_success_count,
        scenario_failed_count,
        signal_success_count,
        signal_failed_count,
    )


def _run_signal_activation_builder(dry_run: bool) -> int:
    activation_scripts = [
        Path(__file__).resolve().parent / "activations" / "build_signal_activations.py",
        Path(__file__).resolve().parent / "activations" / "build_signal_activations_match.py",
    ]

    for script_path in activation_scripts:
        if not script_path.exists():
            logger.error("Signal activation script not found: %s", script_path)
            return 1

    for script_path in activation_scripts:
        if dry_run:
            logger.info("[dry-run] Would execute signal activation script: %s", script_path)
            continue

        logger.info("Running signal activation script: %s", script_path.name)
        command = _build_command(script_path)
        result = subprocess.run(command, cwd=project_root)
        if result.returncode != 0:
            logger.error(
                "Signal activation script failed: %s (exit code %s)",
                script_path.name,
                result.returncode,
            )
            return result.returncode
        logger.info("Signal activation script completed: %s", script_path.name)

    return 0


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
        sql_dir = project_root / "clickhouse" / "gold"
        processor = FotMobGoldProcessor(sql_dir=sql_dir)
        sql_files = processor.sql_files()
        if not sql_files:
            logger.info("No non-DDL gold SQL files selected for load in %s", sql_dir)
        else:
            logger.info("[dry-run] Planned gold SQL files: %s", len(sql_files))
            for sql_file in sql_files:
                logger.info("[dry-run] Would execute SQL file: %s", sql_file)
        logger.info("Selected gold SQL jobs via --part=%s", args.part)
        (
            scenario_success_count,
            scenario_failed_count,
            signal_success_count,
            signal_failed_count,
        ) = _run_selected_jobs(part=args.part, dry_run=True)
        signal_activation_exit_code = 0
        if args.part in ("all", "signals"):
            signal_activation_exit_code = _run_signal_activation_builder(dry_run=True)
        failed_count = scenario_failed_count + signal_failed_count
        if signal_activation_exit_code != 0:
            failed_count += 1
        total_jobs = (
            scenario_success_count
            + scenario_failed_count
            + signal_success_count
            + signal_failed_count
        )
        successful_jobs = scenario_success_count + signal_success_count
        scenario_success_rate = (successful_jobs / total_jobs * 100) if total_jobs > 0 else 0
        send_layer_completion_alert(
            layer="gold",
            summary_message="Gold SQL/signal dry-run finished.",
            scope="dry-run",
            success=failed_count == 0,
            duration_seconds=time.perf_counter() - stage_start,
            detail_lines=[
                f"SQL files planned: <b>{len(sql_files)}</b>",
                "Scenario failures: <b>0</b>",
                f"Signal failures: <b>{signal_failed_count}</b>",
                f"Signal activation builder exit code: <b>{signal_activation_exit_code}</b>",
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

    sql_file_count = 0
    scenario_success_count = 0
    scenario_failed_count = 0
    signal_success_count = 0
    signal_failed_count = 0
    signal_activation_exit_code = 0
    contracts_checked = False
    exit_code = 0
    try:
        sql_dir = project_root / "clickhouse" / "gold"
        processor = FotMobGoldProcessor(sql_dir=sql_dir)
        storage = FotMobGoldStorage(client, database=metadata_db)

        sql_files = processor.sql_files()
        if not sql_files:
            logger.info("No non-DDL gold SQL files selected for load in %s", sql_dir)
            sql_file_count = 0
        else:
            sql_file_count = len(sql_files)
            storage.execute_sql_files(sql_files)
        logger.info("Selected gold SQL jobs via --part=%s", args.part)
        (
            scenario_success_count,
            scenario_failed_count,
            signal_success_count,
            signal_failed_count,
        ) = _run_selected_jobs(part=args.part, dry_run=False, client=client)
        signal_activation_exit_code = 0
        if args.part in ("all", "signals") and signal_failed_count == 0:
            signal_activation_exit_code = _run_signal_activation_builder(dry_run=False)
        elif args.part in ("all", "signals") and signal_failed_count > 0:
            logger.warning("Skipping signal activation builder because signal scripts had failures")
            signal_activation_exit_code = 1

        if signal_failed_count > 0:
            logger.error("Gold processing completed with failed signal scripts")
            exit_code = 1
            return exit_code
        if signal_activation_exit_code != 0:
            logger.error("Gold processing completed with failed signal activation builder")
            exit_code = 1
            return exit_code

        if args.part in ("all", "signals"):
            assert_gold_layer_contracts(client, database=signal_db, log=logger)
        contracts_checked = True
        logger.info("Gold processing completed successfully")
        return exit_code
    except LayerContractError as contract_error:
        logger.error("Gold layer contract assertion failed", error=str(contract_error))
        exit_code = 1
        return exit_code
    finally:
        client.disconnect()
        total_jobs = (
            scenario_success_count
            + scenario_failed_count
            + signal_success_count
            + signal_failed_count
        )
        scenario_success_rate = (
            ((scenario_success_count + signal_success_count) / total_jobs * 100)
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
                f"SQL files executed: <b>{sql_file_count}</b>",
                "Scenarios succeeded: <b>0</b>",
                "Scenario failures: <b>0</b>",
                f"Signals succeeded: <b>{signal_success_count}</b>",
                f"Signal failures: <b>{signal_failed_count}</b>",
                f"Signal activation builder exit code: <b>{signal_activation_exit_code}</b>",
                f"Contract checks: <b>{'passed' if contracts_checked else 'failed or skipped'}</b>",
            ],
            insight_lines=[
                f"Signal success rate: <b>{scenario_success_rate:.1f}%</b>",
                (
                    "Analytics quality signal: <b>gold contracts passed</b>"
                    if contracts_checked
                    else "Analytics quality signal: <b>contract check failed or was skipped</b>"
                ),
            ],
        )


if __name__ == "__main__":
    raise SystemExit(main())
