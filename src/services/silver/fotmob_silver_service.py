"""Silver layer application service behind script entry points."""

import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from src.services.clickhouse_scoped_replace import ScopedReplacementBatch, ScopedSqlJob
from src.services.warehouse_scope import WarehouseExecutionScope
from src.storage.clickhouse_client import ClickHouseClient
from src.storage.clickhouse_sql_executor import split_sql_statements
from src.utils.layer_contracts import assert_silver_layer_contracts
from src.utils.logging_utils import get_logger

logger = get_logger(__name__)

PROJECT_ROOT = Path(__file__).resolve().parents[3]


@dataclass
class SilverRunResult:
    """Structured result returned by SilverService.run()."""

    exit_code: int
    total_jobs: int = 0
    completed_jobs: int = 0
    contracts_checked: bool = False


class SilverService:
    """Coordinates FotMob Silver layer execution in ClickHouse.

    Owns: SQL discovery, scoped-job construction, two-phase staged replacement,
    and layer contract assertion.

    Does NOT own Silver analytical logic (that lives in SQL files).
    """

    def __init__(
        self,
        client: Optional[ClickHouseClient] = None,
        silver_root: Optional[Path] = None,
    ):
        self.client = client
        self.silver_root = silver_root or (PROJECT_ROOT / "clickhouse" / "silver")

    def discover_sql_dirs(self) -> list[Path]:
        """Return available silver SQL directories (dml/, load/)."""
        dml_dir = self.silver_root / "dml"
        load_dir = self.silver_root / "load"
        sql_dirs = [path for path in (dml_dir, load_dir) if path.exists() and path.is_dir()]
        if dml_dir.exists():
            if load_dir.exists():
                logger.info(
                    "Using silver DML SQL from both %s (preferred) and %s (fallback)",
                    dml_dir,
                    load_dir,
                )
            else:
                logger.info("Using silver DML SQL from %s", dml_dir)
        elif load_dir.exists():
            logger.warning(
                "Using legacy silver load SQL directory: %s (consider migrating to dml/)",
                load_dir,
            )
        return sql_dirs

    def discover_load_jobs(self) -> list[tuple[Path, str]]:
        """Discover (sql_path, target_table) pairs from silver SQL dirs."""
        sql_by_name: dict[str, Path] = {}
        for sql_dir in self.discover_sql_dirs():
            for sql_path in sorted(path for path in sql_dir.glob("*.sql") if path.is_file()):
                if sql_path.name in sql_by_name:
                    logger.warning(
                        "Skipping duplicate silver DML SQL %s from %s; using %s",
                        sql_path.name,
                        sql_dir,
                        sql_by_name[sql_path.name],
                    )
                    continue
                sql_by_name[sql_path.name] = sql_path

        jobs: list[tuple[Path, str]] = []
        for sql_path in sorted(sql_by_name.values(), key=lambda path: path.name):
            stem_parts = sql_path.stem.split("_", 1)
            if len(stem_parts) != 2:
                logger.warning("Skipping silver load SQL with unexpected name: %s", sql_path.name)
                continue
            table_name = stem_parts[1]
            jobs.append((sql_path, f"silver.{table_name}"))
        return jobs

    def build_scoped_jobs(self) -> list[ScopedSqlJob]:
        """Build staged replacement jobs from discovered Silver DML."""
        jobs: list[ScopedSqlJob] = []
        for sql_path, target_table in self.discover_load_jobs():
            statements = split_sql_statements(sql_path.read_text(encoding="utf-8"))
            if not statements:
                raise ValueError(f"No executable SQL found in {sql_path}")
            jobs.append(
                ScopedSqlJob(
                    job_id=sql_path.stem,
                    target_table=target_table,
                    statements=tuple(statements),
                    date_expression="match_date",
                )
            )
        return jobs

    def run_load_jobs(
        self,
        scope: WarehouseExecutionScope,
        dry_run: bool = False,
    ) -> tuple[int, int, int]:
        """Stage and commit all Silver jobs for one explicit output scope."""
        try:
            load_jobs = self.build_scoped_jobs()
        except (OSError, ValueError) as error:
            logger.error("Failed to prepare Silver load jobs: %s", error)
            return 1, 0, 0
        if not load_jobs:
            logger.warning("No silver DML SQL files found in %s", self.silver_root)
            return 0, 0, 0

        if dry_run:
            logger.info("[dry-run] Planned silver load jobs: %s", len(load_jobs))

        total_jobs = len(load_jobs)
        started_at = time.perf_counter()
        batch = ScopedReplacementBatch(
            self.client,
            scope,
            dry_run=dry_run,
            log=logger,
        )
        try:
            batch.run(load_jobs)
        except Exception as error:
            logger.error("Silver scoped load failed: %s", error)
            return 1, total_jobs, 0
        logger.info(
            "Silver scoped load completed | scope=%s jobs=%s duration_seconds=%.2f",
            scope.label,
            total_jobs,
            time.perf_counter() - started_at,
        )
        return 0, total_jobs, total_jobs

    def assert_contracts(self, database: str = "silver") -> None:
        """Run silver layer contract assertions. Raises LayerContractError on failure."""
        if self.client is None:
            raise RuntimeError("ClickHouse client is required for contract checks")
        assert_silver_layer_contracts(self.client, database=database, log=logger)

    def run(
        self,
        *,
        scope: WarehouseExecutionScope,
        dry_run: bool = False,
    ) -> SilverRunResult:
        """Execute one scoped Silver pipeline and return a structured result.

        The caller (script) is responsible for:
        - ClickHouse client creation and teardown
        - Telegram notification via TelegramClient
        - Mapping the result to an exit code
        """
        result = SilverRunResult(exit_code=0)

        load_exit_code, total_jobs, completed_jobs = self.run_load_jobs(
            scope=scope,
            dry_run=dry_run,
        )
        result.exit_code = load_exit_code
        result.total_jobs = total_jobs
        result.completed_jobs = completed_jobs

        if load_exit_code != 0:
            return result

        if not dry_run:
            self.assert_contracts()
            result.contracts_checked = True
        logger.info("Silver load completed successfully")
        return result
