"""Gold layer application service behind script entry points."""

import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from src.warehouse.scoped_replace import ScopedReplacementBatch
from src.fotmob.gold.dml_runner import (
    GoldSqlJob,
    build_scoped_gold_job,
    discover_gold_sql_jobs,
)
from src.warehouse.scope import WarehouseExecutionScope
from src.integrations.clickhouse.client import ClickHouseClient
from src.integrations.clickhouse.sql import execute_sql_script
from src.warehouse.databases import gold_db, gold_scenarios_db, gold_signals_db
from src.warehouse.contracts import assert_gold_activation_contracts, assert_gold_layer_contracts
from src.common.logging import get_logger

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

    Owns workflow coordination: SQL discovery, scope-aware staged replacement,
    activation invocation with the same scope, and layer contract assertion.

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
        scope: WarehouseExecutionScope,
        dry_run: bool = False,
    ) -> tuple[int, int, list[str]]:
        """Stage and commit one Gold job group for an explicit scope."""
        if not jobs:
            logger.warning("No gold %s SQL jobs found", job_name)
            return 0, 0, []

        if dry_run:
            logger.info("[dry-run] Planned gold %s SQL jobs: %s", job_name, len(jobs))

        total_jobs = len(jobs)
        failed_jobs: list[str] = []
        try:
            scoped_jobs = [build_scoped_gold_job(job) for job in jobs]
            ScopedReplacementBatch(
                self.client,
                scope,
                dry_run=dry_run,
                log=logger,
            ).run(scoped_jobs)
        except Exception as error:
            logger.error("Gold %s scoped batch failed: %s", job_name, error)
            failed_jobs = [job.job_id for job in jobs]

        failed_count = len(failed_jobs)
        success_count = total_jobs - failed_count
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
        scope: WarehouseExecutionScope,
        dry_run: bool = False,
    ) -> tuple[int, int, int, int]:
        """Stage and commit scenario and signal jobs selected by part and scope.

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

        if not scenario_jobs:
            logger.info("Scenario tables intentionally excluded because --part=%s", part)
        if not signal_jobs:
            logger.info("Signal tables intentionally excluded because --part=%s", part)

        selected_jobs = [*scenario_jobs, *signal_jobs]
        if not selected_jobs:
            return 0, 0, 0, 0
        try:
            scoped_jobs = [build_scoped_gold_job(job) for job in selected_jobs]
            ScopedReplacementBatch(
                self.client,
                scope,
                dry_run=dry_run,
                log=logger,
            ).run(scoped_jobs)
        except Exception as error:
            logger.error("Gold scoped staging or commit failed: %s", error)
            return 0, len(scenario_jobs), 0, len(signal_jobs)
        return len(scenario_jobs), 0, len(signal_jobs), 0

    def run_signal_activation_builders(
        self,
        scope: WarehouseExecutionScope,
        dry_run: bool = False,
    ) -> int:
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
                logger.info(
                    "[dry-run] Activation plan | scope=%s target=gold.signal_activations "
                    "input=all selected signal history output=%s operations=stage; validate; "
                    "scoped partition replacement or full-history exchange; script=%s",
                    scope.label,
                    scope.output_range,
                    script_path,
                )
                continue

            logger.info("Running signal activation script: %s", script_path.name)
            scope_args = (
                ["--date", scope.value]
                if scope.kind == "date"
                else ["--month", scope.value]
                if scope.kind == "month"
                else ["--full-history"]
            )
            command = [sys.executable, str(script_path), *scope_args]
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
        """Run Gold layer contract assertions."""
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

    def run(
        self,
        *,
        scope: WarehouseExecutionScope,
        part: str = "all",
        dry_run: bool = False,
    ) -> GoldRunResult:
        """Execute one scoped Gold pipeline and return a structured result.

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

        logger.info("Selected gold SQL jobs via --part=%s scope=%s", part, scope.label)
        (
            result.scenario_success_count,
            result.scenario_failed_count,
            result.signal_success_count,
            result.signal_failed_count,
        ) = self.run_selected_jobs(part=part, scope=scope, dry_run=dry_run)

        if part in ("all", "signals") and result.signal_failed_count == 0:
            result.signal_activation_exit_code = self.run_signal_activation_builders(
                scope=scope, dry_run=dry_run
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
