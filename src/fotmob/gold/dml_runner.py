"""Discover and execute Gold scenario and signal DML SQL in ClickHouse.

Scenario jobs are discovered from their SQL files. Signal jobs come from the
validated signal catalog (ADR 0033): only active signals run, and selecting a
deprecated or uncatalogued signal is an error.
"""

import os
import re
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from src.fotmob.gold.signal_catalog import (
    SIGNAL_TABLE_DATABASE,
    SignalCatalog,
    SignalDefinition,
    load_signal_catalog,
)
from src.integrations.clickhouse.client import ClickHouseClient
from src.integrations.clickhouse.sql import split_sql_statements
from src.warehouse.databases import gold_scenarios_db, gold_signals_db
from src.warehouse.publication import gold_outputs_publication
from src.warehouse.scope import WarehouseExecutionScope
from src.warehouse.scoped_replace import (
    ScopedReplacementBatch,
    ScopedSqlJob,
)

GoldJobKind = Literal["scenario", "signal"]
SignalEntity = Literal["match", "player", "team"]

PROJECT_ROOT = Path(__file__).resolve().parents[3]
GOLD_SQL_DIR = PROJECT_ROOT / "clickhouse" / "gold"
GOLD_DML_DIR = GOLD_SQL_DIR / "dml"
SCENARIO_DML_DIR = GOLD_DML_DIR / "scenarios"
JOB_ID_RE = re.compile(r"^(scenario|sig|signal)_[a-z0-9_]+$")
SIGNAL_FAMILY_RE = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")

# Database that scenario SQL files name; the runner maps it to the configured one.
SCENARIO_TABLE_DATABASE = "gold_scenarios"


@dataclass(frozen=True)
class GoldSqlJob:
    """Resolved Gold SQL job ready for execution."""

    kind: GoldJobKind
    job_id: str
    sql_file: Path
    target_db: str
    target_table: str


def default_target_db(kind: GoldJobKind) -> str:
    """Return the default ClickHouse database for a Gold job kind."""
    if kind == "scenario":
        return gold_scenarios_db()
    if kind == "signal":
        return gold_signals_db()
    raise ValueError(f"Unsupported Gold SQL job kind: {kind}")


def validate_job_id(kind: GoldJobKind, job_id: str) -> str:
    """Validate a Gold SQL job identifier."""
    if not JOB_ID_RE.match(job_id):
        raise ValueError(
            "Gold SQL job id must start with scenario_, sig_, or signal_ and contain "
            f"only lowercase letters, digits, and underscores: {job_id}"
        )
    if kind == "scenario" and not job_id.startswith("scenario_"):
        raise ValueError(f"Scenario job ids must start with scenario_: {job_id}")
    if kind == "signal" and not (job_id.startswith("sig_") or job_id.startswith("signal_")):
        raise ValueError(f"Signal job ids must start with sig_ or signal_: {job_id}")
    return job_id


def validate_signal_family(family: str) -> str:
    """Validate a signal family filter."""
    if not SIGNAL_FAMILY_RE.match(family):
        raise ValueError(
            f"Signal family must contain only lowercase letters, digits, and underscores: {family}"
        )
    return family


def _resolved_target_db(kind: GoldJobKind, target_db: str | None) -> str:
    return target_db or os.getenv("CLICKHOUSE_GOLD_TARGET_DB") or default_target_db(kind)


def _signal_job(definition: SignalDefinition, target_db: str | None) -> GoldSqlJob:
    resolved_target_db = _resolved_target_db("signal", target_db)
    return GoldSqlJob(
        kind="signal",
        job_id=definition.signal_id,
        sql_file=definition.sql_path,
        target_db=resolved_target_db,
        target_table=f"{resolved_target_db}.{definition.signal_id}",
    )


def _scenario_job(job_id: str, target_db: str | None) -> GoldSqlJob:
    sql_file = next(
        (path for path in SCENARIO_DML_DIR.rglob(f"{job_id}.sql") if path.is_file()),
        SCENARIO_DML_DIR / f"{job_id}.sql",
    )
    resolved_target_db = _resolved_target_db("scenario", target_db)
    return GoldSqlJob(
        kind="scenario",
        job_id=job_id,
        sql_file=sql_file,
        target_db=resolved_target_db,
        target_table=f"{resolved_target_db}.{job_id}",
    )


def resolve_gold_sql_job(
    kind: GoldJobKind,
    job_id: str,
    *,
    target_db: str | None = None,
    signal_catalog: SignalCatalog | None = None,
) -> GoldSqlJob:
    """Resolve a Gold SQL job id to SQL path and target table metadata.

    A signal must have an active catalog; the catalog is loaded when not given.
    """
    job_id = validate_job_id(kind, job_id)
    if kind == "scenario":
        return _scenario_job(job_id, target_db)

    catalog = signal_catalog or load_signal_catalog()
    try:
        definition = catalog.get(job_id)
    except KeyError as error:
        raise ValueError(f"Signal {job_id} has no catalog") from error
    if not definition.is_active:
        raise ValueError(f"Signal {job_id} is {definition.status} and does not run in Gold")
    return _signal_job(definition, target_db)


def discover_gold_sql_jobs(
    kind: GoldJobKind,
    *,
    entity: SignalEntity | None = None,
    family: str | None = None,
    target_db: str | None = None,
    signal_catalog: SignalCatalog | None = None,
) -> list[GoldSqlJob]:
    """Discover all executable Gold SQL jobs for a kind, ordered by job id.

    Signal jobs are the active catalog signals, optionally filtered by entity or by
    family (``family`` or ``family_subfamily``); the catalog is loaded when not given.
    """
    if kind != "signal" and (entity or family):
        raise ValueError("Entity and family filters are only supported for signal SQL jobs")
    if family is not None:
        family = validate_signal_family(family)
    if entity and family:
        raise ValueError("Use --entity or --family as separate signal selectors, not both")

    if kind == "scenario":
        jobs: list[GoldSqlJob] = []
        seen_job_ids: set[str] = set()
        for path in sorted(SCENARIO_DML_DIR.rglob("scenario_*.sql")):
            if not path.is_file() or path.stem in seen_job_ids:
                continue
            seen_job_ids.add(path.stem)
            jobs.append(_scenario_job(path.stem, target_db))
        return jobs

    catalog = signal_catalog or load_signal_catalog()
    return [
        _signal_job(definition, target_db)
        for definition in catalog.select(entity=entity, family=family)
    ]


def build_scoped_gold_job(job: GoldSqlJob) -> ScopedSqlJob:
    """Normalize one Gold SQL file into a scope-aware replacement job."""
    if not job.sql_file.exists():
        raise ValueError(f"Gold {job.kind} SQL file not found: {job.sql_file}")

    sql_content = job.sql_file.read_text(encoding="utf-8")
    if job.kind == "scenario":
        # SQL names the canonical database; map it to the configured target.
        sql_content = sql_content.replace(f"{SCENARIO_TABLE_DATABASE}.", f"{job.target_db}.")
        date_expression = "toDateOrNull(match_time_utc_date)"
    else:
        sql_content = sql_content.replace(f"{SIGNAL_TABLE_DATABASE}.", f"{job.target_db}.")
        date_expression = "match_date"
    statements = split_sql_statements(sql_content)
    if not statements:
        raise ValueError(f"No executable SQL found in {job.sql_file}")
    return ScopedSqlJob(
        job_id=job.job_id,
        target_table=job.target_table,
        statements=tuple(statements),
        date_expression=date_expression,
    )


def execute_gold_sql_job(
    client: ClickHouseClient | None,
    job: GoldSqlJob,
    *,
    scope: WarehouseExecutionScope,
    dry_run: bool,
    log,
) -> bool:
    """Execute one Gold SQL job through staged scope replacement."""
    started_at = time.perf_counter()
    scoped_job = build_scoped_gold_job(job)
    ScopedReplacementBatch(
        client, scope, dry_run=dry_run, log=log, publication=gold_outputs_publication()
    ).run([scoped_job])
    log.info(
        "Gold %s SQL job completed for scope %s: %s in %.2f seconds",
        job.kind,
        scope.label,
        job.job_id,
        time.perf_counter() - started_at,
    )
    return True
