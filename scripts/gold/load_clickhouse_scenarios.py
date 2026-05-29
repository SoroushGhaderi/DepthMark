"""Process FotMob gold layer in ClickHouse."""

import argparse
import os
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
from src.processors.gold.fotmob import FotMobGoldProcessor
from src.storage.clickhouse_client import ClickHouseClient
from src.storage.gold.fotmob import FotMobGoldStorage
from src.utils.layer_completion_alerts import send_layer_completion_alert
from src.utils.gold_databases import gold_scenarios_db, gold_signals_db
from src.utils.layer_contracts import LayerContractError, assert_gold_layer_contracts
from src.utils.logging_utils import get_logger, setup_logging

logger = get_logger(__name__)


def _job_scripts(subdirectory: str, pattern: str) -> list[Path]:
    scripts_path = Path(__file__).resolve().parent / subdirectory
    return sorted(path for path in scripts_path.glob(pattern) if path.is_file())


def _scenario_scripts() -> list[Path]:
    return _job_scripts("scenario", "scenario*.py")


def _signal_scripts() -> list[Path]:
    scripts_path = Path(__file__).resolve().parent / "signal" / "runners"
    signal_prefixed = list(scripts_path.glob("signal*.py"))
    sig_prefixed = list(scripts_path.glob("sig*.py"))
    return sorted(path for path in (signal_prefixed + sig_prefixed) if path.is_file())


def _selected_script_groups(part: str) -> tuple[list[Path], list[Path]]:
    scenario_scripts = _scenario_scripts() if part in ("all", "scenarios") else []
    signal_scripts = _signal_scripts() if part in ("all", "signals") else []
    return scenario_scripts, signal_scripts


def _build_command(script_path: Path) -> list[str]:
    return [sys.executable, str(script_path)]


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Process FotMob gold layer in ClickHouse")
    parser.add_argument(
        "--part",
        choices=("all", "scenarios", "signals"),
        default="all",
        help="Which scenario/signal job groups to run.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview gold SQL/scenario/signal jobs without executing SQL or subprocesses",
    )
    return parser.parse_args(argv)


def _run_job_scripts(
    job_name: str,
    script_paths: list[Path],
    dry_run: bool = False,
) -> tuple[int, int, list[str]]:
    if not script_paths:
        logger.warning(
            "No gold %s scripts found in %s",
            job_name,
            Path(__file__).resolve().parent / job_name,
        )
        return 0, 0, []

    if dry_run:
        logger.info("[dry-run] Planned gold %s scripts: %s", job_name, len(script_paths))

    total_scripts = len(script_paths)
    success_count = 0
    failed_scripts: list[str] = []

    for index, script_path in enumerate(script_paths, start=1):
        logger.info(
            "Running gold %s script %s/%s: %s",
            job_name,
            index,
            total_scripts,
            script_path.name,
        )
        if dry_run:
            logger.info("[dry-run] Would execute %s script: %s", job_name, script_path)
            success_count += 1
            continue
        command = _build_command(script_path)
        env = os.environ.copy()
        env["CLICKHOUSE_GOLD_TARGET_DB"] = (
            gold_scenarios_db() if job_name == "scenario" else gold_signals_db()
        )
        script_start = time.perf_counter()
        result = subprocess.run(command, cwd=project_root, env=env)
        elapsed_seconds = time.perf_counter() - script_start
        if result.returncode != 0:
            logger.error(
                "Gold %s script failed %s/%s: %s (exit code %s) after %.2f seconds",
                job_name,
                index,
                total_scripts,
                script_path.name,
                result.returncode,
                elapsed_seconds,
            )
            failed_scripts.append(script_path.name)
            continue
        success_count += 1
        logger.info(
            "Completed gold %s script %s/%s: %s in %.2f seconds",
            job_name,
            index,
            total_scripts,
            script_path.name,
            elapsed_seconds,
        )

    failed_count = len(failed_scripts)
    logger.info(
        "Gold %s execution report | total=%s success=%s failed=%s",
        job_name,
        total_scripts,
        success_count,
        failed_count,
    )
    if failed_scripts:
        logger.error("Failed %s scripts: %s", job_name, ", ".join(failed_scripts))

    return success_count, failed_count, failed_scripts


def _run_selected_jobs(part: str, dry_run: bool) -> tuple[int, int, int, int]:
    scenario_scripts, signal_scripts = _selected_script_groups(part)

    scenario_success_count = 0
    scenario_failed_count = 0
    signal_success_count = 0
    signal_failed_count = 0

    if scenario_scripts:
        scenario_success_count, scenario_failed_count, _ = _run_job_scripts(
            job_name="scenario",
            script_paths=scenario_scripts,
            dry_run=dry_run,
        )
    else:
        logger.info("Skipping scenario scripts because --part=%s", part)

    if signal_scripts:
        signal_success_count, signal_failed_count, _ = _run_job_scripts(
            job_name="signal",
            script_paths=signal_scripts,
            dry_run=dry_run,
        )
    else:
        logger.info("Skipping signal scripts because --part=%s", part)

    return (
        scenario_success_count,
        scenario_failed_count,
        signal_success_count,
        signal_failed_count,
    )


def main(argv=None) -> int:
    global logger
    stage_start = time.perf_counter()
    args = parse_args(argv)
    logger = setup_logging(
        name="clickhouse_gold_loader",
        log_dir=settings.log_dir,
        log_level=settings.log_level,
    )
    scenario_db = gold_scenarios_db()
    signal_db = gold_signals_db()

    if args.dry_run:
        logger.info("Running gold loader in dry-run mode (no SQL will be executed)")
        logger.info("Gold scenario database: %s", scenario_db)
        logger.info("Gold signal database: %s", signal_db)
        sql_dir = project_root / "clickhouse" / "gold"
        processor = FotMobGoldProcessor(sql_dir=sql_dir)
        sql_files = processor.sql_files()
        if not sql_files:
            logger.info("No non-DDL gold SQL files selected for load in %s", sql_dir)
        else:
            logger.info("[dry-run] Planned gold SQL files: %s", len(sql_files))
            for sql_file in sql_files:
                logger.info("[dry-run] Would execute SQL file: %s", sql_file)
        logger.info("Selected gold job scripts via --part=%s", args.part)
        (
            scenario_success_count,
            scenario_failed_count,
            signal_success_count,
            signal_failed_count,
        ) = _run_selected_jobs(part=args.part, dry_run=True)
        failed_count = scenario_failed_count + signal_failed_count
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
            summary_message="Gold SQL/scenario/signal dry-run finished.",
            scope="dry-run",
            success=failed_count == 0,
            duration_seconds=time.perf_counter() - stage_start,
            detail_lines=[
                f"SQL files planned: <b>{len(sql_files)}</b>",
                f"Scenario failures: <b>{scenario_failed_count}</b>",
                f"Signal failures: <b>{signal_failed_count}</b>",
            ],
            insight_lines=[
                f"Scenario/signal pass projection: <b>{scenario_success_rate:.1f}%</b>",
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
    contracts_checked = False
    exit_code = 0
    try:
        sql_dir = project_root / "clickhouse" / "gold"
        processor = FotMobGoldProcessor(sql_dir=sql_dir)
        storage = FotMobGoldStorage(client, database=scenario_db)

        sql_files = processor.sql_files()
        if not sql_files:
            logger.info("No non-DDL gold SQL files selected for load in %s", sql_dir)
            sql_file_count = 0
        else:
            sql_file_count = len(sql_files)
            storage.execute_sql_files(sql_files)
        logger.info("Selected gold job scripts via --part=%s", args.part)
        (
            scenario_success_count,
            scenario_failed_count,
            signal_success_count,
            signal_failed_count,
        ) = _run_selected_jobs(part=args.part, dry_run=False)
        if scenario_failed_count > 0 or signal_failed_count > 0:
            logger.error("Gold processing completed with failed scenario/signal scripts")
            exit_code = 1
            return exit_code

        if args.part in ("all", "scenarios"):
            assert_gold_layer_contracts(client, database=scenario_db, log=logger)
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
        summary = "Gold SQL + scenario/signal processing finished."
        send_layer_completion_alert(
            layer="gold",
            summary_message=summary,
            scope="runtime",
            success=exit_code == 0,
            duration_seconds=time.perf_counter() - stage_start,
            detail_lines=[
                f"SQL files executed: <b>{sql_file_count}</b>",
                f"Scenarios succeeded: <b>{scenario_success_count}</b>",
                f"Scenario failures: <b>{scenario_failed_count}</b>",
                f"Signals succeeded: <b>{signal_success_count}</b>",
                f"Signal failures: <b>{signal_failed_count}</b>",
                f"Contract checks: <b>{'passed' if contracts_checked else 'failed or skipped'}</b>",
            ],
            insight_lines=[
                f"Scenario/signal success rate: <b>{scenario_success_rate:.1f}%</b>",
                (
                    "Analytics quality signal: <b>gold contracts passed</b>"
                    if contracts_checked
                    else "Analytics quality signal: <b>contract check failed or was skipped</b>"
                ),
            ],
        )


if __name__ == "__main__":
    raise SystemExit(main())
