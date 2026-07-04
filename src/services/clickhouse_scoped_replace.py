"""Two-phase, scope-aware replacement for ClickHouse derived tables."""

import re
import uuid
from dataclasses import dataclass
from typing import Optional

from src.services.warehouse_scope import WarehouseExecutionScope
from src.storage.clickhouse_client import ClickHouseClient

SAFE_QUALIFIED_TABLE_RE = re.compile(
    r"^(?P<database>[a-zA-Z_][a-zA-Z0-9_]*)\.(?P<table>[a-zA-Z_][a-zA-Z0-9_]*)$"
)


@dataclass(frozen=True)
class ScopedSqlJob:
    """One deterministic SQL job and its scope lineage."""

    job_id: str
    target_table: str
    statements: tuple[str, ...]
    date_expression: str
    historical_input_range: str = "all available history"


@dataclass(frozen=True)
class PreparedReplacement:
    """Staged replacement ready for commit."""

    job: ScopedSqlJob
    calculation_table: str
    replacement_table: str
    replacement_row_count: Optional[int]
    target_partition_row_count: Optional[int] = None


def replace_insert_target(sql: str, target_table: str, stage_table: str) -> str:
    """Redirect every INSERT INTO target occurrence to a staging table."""
    pattern = re.compile(rf"(?i)(INSERT\s+INTO\s+){re.escape(target_table)}(?=\s|\()")
    rewritten, replacement_count = pattern.subn(rf"\1{stage_table}", sql)
    if replacement_count == 0:
        raise ValueError(f"SQL does not insert into expected target {target_table}")
    return rewritten


class ScopedReplacementBatch:
    """Stage all selected jobs, then commit them one table at a time."""

    def __init__(
        self,
        client: Optional[ClickHouseClient],
        scope: WarehouseExecutionScope,
        *,
        dry_run: bool = False,
        log,
        run_id: Optional[str] = None,
    ):
        self.client = client
        self.scope = scope
        self.dry_run = dry_run
        self.log = log
        self.run_id = run_id or uuid.uuid4().hex[:10]

    def log_plan(self, job: ScopedSqlJob) -> None:
        """Report deterministic dry-run and runtime planning details."""
        operations = (
            "stage full calculation; copy unaffected month rows; stage selected date; "
            "validate; REPLACE PARTITION"
            if self.scope.kind == "date"
            else "stage full calculation; stage selected month; validate; REPLACE PARTITION"
            if self.scope.kind == "month"
            else "stage full calculation; validate; EXCHANGE TABLES"
        )
        self.log.info(
            "%sScoped load plan | scope=%s job=%s target=%s input=%s output=%s operations=%s",
            "[dry-run] " if self.dry_run else "",
            self.scope.label,
            job.job_id,
            job.target_table,
            job.historical_input_range,
            self.scope.output_range,
            operations,
        )

    def run(self, jobs: list[ScopedSqlJob]) -> list[PreparedReplacement]:
        """Prepare every job before committing any target table."""
        for job in jobs:
            self.log_plan(job)
        if self.dry_run:
            return []
        if self.client is None:
            raise RuntimeError("ClickHouse client is required outside dry-run mode")

        prepared: list[PreparedReplacement] = []
        try:
            for job in jobs:
                prepared.append(self._prepare(job))
        except Exception:
            self.log.error(
                "Scoped staging failed; targets are unchanged and stage tables are retained",
                scope=self.scope.label,
                prepared_jobs=len(prepared),
            )
            raise

        committed: list[str] = []
        try:
            for replacement in prepared:
                self._commit(replacement)
                committed.append(replacement.job.target_table)
        except Exception:
            pending = [
                item.job.target_table for item in prepared if item.job.target_table not in committed
            ]
            self.log.error(
                "Scoped commit failed; rerun the same scope to converge",
                scope=self.scope.label,
                committed_tables=committed,
                pending_tables=pending,
            )
            raise
        return prepared

    def _stage_names(self, target_table: str) -> tuple[str, str]:
        match = SAFE_QUALIFIED_TABLE_RE.match(target_table)
        if not match:
            raise ValueError(f"Unsafe qualified table name: {target_table}")
        database = match.group("database")
        table = match.group("table")
        prefix = f"_depthmark_{self.run_id}_{table}"
        return f"{database}.{prefix}_calc", f"{database}.{prefix}_replace"

    def _prepare(self, job: ScopedSqlJob) -> PreparedReplacement:
        calculation_table, replacement_table = self._stage_names(job.target_table)
        self.client.execute(f"CREATE TABLE {calculation_table} AS {job.target_table}")
        for statement in job.statements:
            staged_sql = replace_insert_target(
                statement,
                job.target_table,
                calculation_table,
            )
            self.client.execute(staged_sql, log_query=False)
        self.client.execute(f"OPTIMIZE TABLE {calculation_table} FINAL DEDUPLICATE")

        if self.scope.kind == "full-history":
            return PreparedReplacement(
                job=job,
                calculation_table=calculation_table,
                replacement_table=replacement_table,
                replacement_row_count=None,
            )

        self.client.execute(f"CREATE TABLE {replacement_table} AS {job.target_table}")
        partition_filter = f"toYYYYMM({job.date_expression}) = {self.scope.partition_id}"
        if self.scope.kind == "date":
            selected_filter = f"{job.date_expression} = toDate('{self.scope.iso_date}')"
            self.client.execute(
                f"INSERT INTO {replacement_table} SELECT * FROM {job.target_table} FINAL "
                f"WHERE {partition_filter} AND NOT ({selected_filter})"
            )
        else:
            selected_filter = partition_filter
        self.client.execute(
            f"INSERT INTO {replacement_table} SELECT * FROM {calculation_table} FINAL "
            f"WHERE {selected_filter}"
        )
        self.client.execute(f"OPTIMIZE TABLE {replacement_table} FINAL DEDUPLICATE")
        result = self.client.execute(
            f"SELECT count() FROM {replacement_table} FINAL",
            log_query=False,
        )
        row_count = int(result.result_rows[0][0])
        target_result = self.client.execute(
            f"SELECT count() FROM {job.target_table} FINAL "
            f"WHERE toYYYYMM({job.date_expression}) = {self.scope.partition_id}",
            log_query=False,
        )
        target_row_count = int(target_result.result_rows[0][0])
        return PreparedReplacement(
            job=job,
            calculation_table=calculation_table,
            replacement_table=replacement_table,
            replacement_row_count=row_count,
            target_partition_row_count=target_row_count,
        )

    def _commit(self, replacement: PreparedReplacement) -> None:
        target_table = replacement.job.target_table
        if self.scope.kind == "full-history":
            self.client.execute(
                f"EXCHANGE TABLES {target_table} AND {replacement.calculation_table}"
            )
            self.client.execute(f"DROP TABLE {replacement.calculation_table}")
            return

        if replacement.replacement_row_count == 0:
            if replacement.target_partition_row_count == 0:
                self.log.info(
                    "Scoped replacement is empty and target partition is absent; no commit needed",
                    target_table=target_table,
                    partition_id=self.scope.partition_id,
                )
                self.client.execute(f"DROP TABLE {replacement.calculation_table}")
                self.client.execute(f"DROP TABLE {replacement.replacement_table}")
                return
            self.client.execute(
                f"ALTER TABLE {target_table} DROP PARTITION {self.scope.partition_id}"
            )
        else:
            self.client.execute(
                f"ALTER TABLE {target_table} REPLACE PARTITION {self.scope.partition_id} "
                f"FROM {replacement.replacement_table}"
            )
        self.client.execute(f"DROP TABLE {replacement.calculation_table}")
        self.client.execute(f"DROP TABLE {replacement.replacement_table}")
