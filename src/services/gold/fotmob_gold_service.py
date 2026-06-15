"""Gold layer application service behind script entry points."""

import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from src.services.gold.gold_dml_runner import (
    GoldSqlJob,
    discover_gold_sql_jobs,
    execute_gold_sql_job,
)
from src.storage.clickhouse_client import ClickHouseClient
from src.storage.clickhouse_sql_executor import execute_sql_script
from src.utils.gold_databases import gold_db, gold_scenarios_db, gold_signals_db
from src.utils.layer_contracts import (
    LayerContractError,
    assert_gold_activation_contracts,
    assert_gold_layer_contracts,
)
from src.utils.logging_utils import get_logger

logger = get_logger(__name__)

PROJECT_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = PROJECT_ROOT / "scripts" / "gold"


@dataclass
class GoldRunResult:
    """Structured result returned by GoldService.run()."""

    exit_code: int
    sql_file_count: int = 0
    scenario_success_count: int = 0
    scenario_failed_count: int = 0
    signal_success_count: int = 0
    signal_failed_count: int = 0
    signal_activation_exit_code: int = 0
    contracts_checked: bool = False
    failed_jobs: list[str] = field(default_factory=list)


class GoldService:
    """Coordinates FotMob Gold layer execution in ClickHouse.

    Owns workflow coordination: SQL file discovery and execution,
    signal/scenario job discovery and iteration, activation script
    invocation, and layer contract assertion.

    Does NOT own Gold analytical logic (that lives in SQL files).
    """

    def __init__(
        self,
        client: Optional[ClickHouseClient] = None,
        metadata_db: Optional[str] = None,
    ):
        self.client = client
        self.metadata_db = metadata_db or gold_db()

    def discover_sql_files(self) -> list[Path]:
        """Return ordered non-DDL, non-scenario SQL files for gold load."""
        sql_dir = PROJECT_ROOT / "clickhouse" / "gold"

        def _is_ddl(path: Path) -> bool:
            name = path.name.lower()
            return (
                name.startswith("create_")
                or name.startswith("00_")
                or name.startswith("01_")
                or "_create_" in name
            )

        return sorted(
            path
            for path in sql_dir.glob("*.sql")
            if not path.name.startswith("scenario_") and not _is_ddl(path)
        )

    def execute_sql_files(self, sql_files: list[Path]) -> None:
        """Execute SQL files sequentially against the metadata database."""
        if self.client is None:
            raise RuntimeError("ClickHouse client is required for SQL execution")
        for sql_file in sql_files:
            execute_sql_script(self.client, sql_file, layer_name="gold")

    def discover_signal_jobs(
        self,
        entity: Optional[str] = None,
        family: Optional[str] = None,
    ) -> list[GoldSqlJob]:
        """Discover signal SQL jobs, optionally filtered by entity or family."""
        return discover_gold_sql_jobs(
            "signal",
            entity=entity,
            family=family,
            target_db=gold_signals_db(),
        )

    def run_sql_jobs(
        self,
        job_name: str,
        jobs: list[GoldSqlJob],
        dry_run: bool = False,
    ) -> tuple[int, int, list[str]]:
        """Execute a list of Gold SQL jobs and return (success, failed, failed_ids)."""
        if not jobs:
            logger.warning("No gold %s SQL jobs found", job_name)
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
                if execute_gold_sql_job(self.client, job, dry_run=dry_run, log=logger):
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

    def run_selected_jobs(
        self,
        part: str,
        dry_run: bool = False,
    ) -> tuple[int, int, int, int]:
        """Run scenario and signal jobs filtered by part.

        Returns (scenario_ok, scenario_fail, signal_ok, signal_fail).
        """
        scenario_jobs = (
            discover_gold_sql_jobs("scenario", target_db=gold_scenarios_db())
            if part in ("all", "scenarios")
            else []
        )
        signal_jobs = (
            discover_gold_sql_jobs("signal", target_db=gold_signals_db())
            if part in ("all", "signals")
            else []
        )

        scenario_success_count = 0
        scenario_failed_count = 0
        signal_success_count = 0
        signal_failed_count = 0

        if scenario_jobs:
            scenario_success_count, scenario_failed_count, _ = self.run_sql_jobs(
                job_name="scenario",
                jobs=scenario_jobs,
                dry_run=dry_run,
            )
        else:
            logger.info("Skipping scenario SQL jobs because --part=%s", part)

        if signal_jobs:
            signal_success_count, signal_failed_count, _ = self.run_sql_jobs(
                job_name="signal",
                jobs=signal_jobs,
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

    def run_signal_activation_builders(self, dry_run: bool = False) -> int:
        """Run signal activation scripts. Returns exit code."""
        activation_dir = SCRIPTS_DIR / "activations"
        activation_scripts = [
            activation_dir / "build_signal_activations.py",
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
            command = [sys.executable, str(script_path)]
            result = subprocess.run(command, cwd=PROJECT_ROOT)
            if result.returncode != 0:
                logger.error(
                    "Signal activation script failed: %s (exit code %s)",
                    script_path.name,
                    result.returncode,
                )
                return result.returncode
            logger.info("Signal activation script completed: %s", script_path.name)

        return 0

    def assert_contracts(self, part: str = "all", database: Optional[str] = None) -> None:
        """Run gold layer contract assertions. Raises LayerContractError on failure."""
        if self.client is None:
            raise RuntimeError("ClickHouse client is required for contract checks")
        assert_gold_layer_contracts(
            self.client,
            scenario_database=gold_scenarios_db(),
            signal_database=gold_signals_db(),
            check_scenarios=part in ("all", "scenarios"),
            check_signals=part in ("all", "signals"),
            log=logger,
        )
        if part in ("all", "signals"):
            assert_gold_activation_contracts(
                self.client,
                database=database or self.metadata_db,
                log=logger,
            )

    def run(self, *, part: str = "all", dry_run: bool = False) -> GoldRunResult:
        """Execute the full Gold layer pipeline and return a structured result.

        The caller (script) is responsible for:
        - ClickHouse client creation and teardown
        - Telegram notification via TelegramClient
        - Mapping the result to an exit code
        """
        result = GoldRunResult(exit_code=0)

        sql_files = self.discover_sql_files()
        result.sql_file_count = len(sql_files)
        if not sql_files:
            logger.info(
                "No non-DDL gold SQL files selected for load in %s",
                PROJECT_ROOT / "clickhouse" / "gold",
            )
        elif not dry_run:
            self.execute_sql_files(sql_files)

        logger.info("Selected gold SQL jobs via --part=%s", part)
        (
            result.scenario_success_count,
            result.scenario_failed_count,
            result.signal_success_count,
            result.signal_failed_count,
        ) = self.run_selected_jobs(part=part, dry_run=dry_run)

        if part in ("all", "signals") and result.signal_failed_count == 0:
            result.signal_activation_exit_code = self.run_signal_activation_builders(
                dry_run=dry_run
            )
        elif part in ("all", "signals") and result.signal_failed_count > 0:
            logger.warning("Skipping signal activation builder because signal scripts had failures")
            result.signal_activation_exit_code = 1

        if result.signal_failed_count > 0:
            logger.error("Gold processing completed with failed signal scripts")
            result.exit_code = 1
            return result

        if result.signal_activation_exit_code != 0:
            logger.error("Gold processing completed with failed signal activation builder")
            result.exit_code = 1
            return result

        if part in ("all", "signals") and not dry_run:
            self.assert_contracts(part=part)
            result.contracts_checked = True
        elif part == "scenarios" and not dry_run:
            self.assert_contracts(part=part)
            result.contracts_checked = True

        logger.info("Gold processing completed successfully")
        return result
