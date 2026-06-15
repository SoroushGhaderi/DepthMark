"""Silver layer application service behind script entry points."""

import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from src.storage.clickhouse_client import ClickHouseClient
from src.storage.clickhouse_sql_executor import execute_sql_statements, split_sql_statements
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

    Owns: SQL directory discovery, SQL file discovery and deduplication,
    SQL execution and table optimization, layer contract assertion.

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
                logger.warning(
                    "Skipping silver load SQL with unexpected name: %s", sql_path.name
                )
                continue
            table_name = stem_parts[1]
            jobs.append((sql_path, f"silver.{table_name}"))
        return jobs

    def execute_load_sql(
        self,
        sql_file: Path,
        target_table: str,
        dry_run: bool = False,
    ) -> int:
        """Execute one silver load SQL file and optimize its target table. Returns exit code."""
        if not sql_file.exists():
            logger.error("Load SQL file not found: %s", sql_file)
            return 1

        sql_content = sql_file.read_text(encoding="utf-8")
        statements = split_sql_statements(sql_content)
        if not statements:
            logger.error("No executable SQL found in %s", sql_file)
            return 1

        if dry_run:
            logger.info(
                "[dry-run] Would execute %s SQL statement(s) and optimize %s using %s",
                len(statements),
                target_table,
                sql_file.name,
            )
            return 0

        if self.client is None:
            raise RuntimeError("ClickHouse client is required for SQL execution")

        execute_sql_statements(
            client=self.client,
            statements=statements,
            layer_name="silver_load",
            source_name=sql_file.name,
        )

        self.client.execute(f"OPTIMIZE TABLE {target_table} FINAL DEDUPLICATE")
        return 0

    def run_load_jobs(self, dry_run: bool = False) -> tuple[int, int, int]:
        """Run all silver load jobs. Returns (exit_code, total, completed)."""
        load_jobs = self.discover_load_jobs()
        if not load_jobs:
            logger.warning("No silver DML SQL files found in %s", self.silver_root)
            return 0, 0, 0

        if dry_run:
            logger.info("[dry-run] Planned silver load jobs: %s", len(load_jobs))

        total_jobs = len(load_jobs)
        completed_jobs = 0
        for index, (sql_path, target_table) in enumerate(load_jobs, start=1):
            logger.info(
                "Running silver load job %s/%s: %s -> %s",
                index,
                total_jobs,
                sql_path.name,
                target_table,
            )
            started_at = time.perf_counter()
            if not dry_run and self.client is None:
                logger.error("ClickHouse client is required when not running dry-run")
                return 1, total_jobs, completed_jobs
            result = self.execute_load_sql(sql_path, target_table, dry_run=dry_run)
            elapsed_seconds = time.perf_counter() - started_at
            if result != 0:
                logger.error(
                    "Silver load job failed %s/%s: %s -> %s (exit code %s) after %.2f seconds",
                    index,
                    total_jobs,
                    sql_path.name,
                    target_table,
                    result,
                    elapsed_seconds,
                )
                return 1, total_jobs, completed_jobs
            completed_jobs += 1
            logger.info(
                "Completed silver load job %s/%s: %s -> %s in %.2f seconds",
                index,
                total_jobs,
                sql_path.name,
                target_table,
                elapsed_seconds,
            )
        return 0, total_jobs, completed_jobs

    def assert_contracts(self, database: str = "silver") -> None:
        """Run silver layer contract assertions. Raises LayerContractError on failure."""
        if self.client is None:
            raise RuntimeError("ClickHouse client is required for contract checks")
        assert_silver_layer_contracts(self.client, database=database, log=logger)

    def run(self, *, dry_run: bool = False) -> SilverRunResult:
        """Execute the full Silver layer pipeline and return a structured result.

        The caller (script) is responsible for:
        - ClickHouse client creation and teardown
        - Telegram notification via TelegramClient
        - Mapping the result to an exit code
        """
        result = SilverRunResult(exit_code=0)

        load_exit_code, total_jobs, completed_jobs = self.run_load_jobs(dry_run=dry_run)
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
