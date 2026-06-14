"""Shared execution helpers for Gold scenario and signal SQL jobs."""

import os
import re
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, Optional

from src.storage.clickhouse_client import ClickHouseClient
from src.utils.gold_databases import gold_scenarios_db, gold_signals_db

GoldJobKind = Literal["scenario", "signal"]
SignalEntity = Literal["match", "player", "team"]

PROJECT_ROOT = Path(__file__).resolve().parents[3]
GOLD_SQL_DIR = PROJECT_ROOT / "clickhouse" / "gold"
GOLD_DML_DIR = GOLD_SQL_DIR / "dml"
JOB_ID_RE = re.compile(r"^(scenario|sig|signal)_[a-z0-9_]+$")
SIGNAL_ENTITIES: tuple[SignalEntity, ...] = ("match", "player", "team")
SIGNAL_FAMILY_RE = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")


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


def signal_entity_from_job_id(job_id: str) -> Optional[SignalEntity]:
    """Infer signal entity subdirectory from a signal job id."""
    if job_id.startswith("sig_match_"):
        return "match"
    if job_id.startswith("sig_player_"):
        return "player"
    if job_id.startswith("sig_team_"):
        return "team"
    return None


def _dml_search_dir(kind: GoldJobKind, entity: Optional[SignalEntity] = None) -> Path:
    """Return the DML directory root for scenario or signal SQL discovery."""
    if kind == "scenario":
        return GOLD_DML_DIR / "scenarios"
    if entity:
        return GOLD_DML_DIR / "signals" / entity
    return GOLD_DML_DIR / "signals"


def validate_signal_family(family: str) -> str:
    """Validate a signal family filter."""
    if not SIGNAL_FAMILY_RE.match(family):
        raise ValueError(
            "Signal family must contain only lowercase letters, digits, and underscores: "
            f"{family}"
        )
    return family


def resolve_gold_sql_job(
    kind: GoldJobKind,
    job_id: str,
    *,
    target_db: Optional[str] = None,
) -> GoldSqlJob:
    """Resolve a Gold SQL job id to SQL path and target table metadata."""
    job_id = validate_job_id(kind, job_id)
    entity = signal_entity_from_job_id(job_id) if kind == "signal" else None
    search_dirs = (
        [_dml_search_dir(kind, entity)]
        if entity
        else [_dml_search_dir(kind)]
        if kind == "scenario"
        else [_dml_search_dir(kind, signal_entity) for signal_entity in SIGNAL_ENTITIES]
    )
    sql_file = next(
        (
            path
            for search_dir in search_dirs
            for path in search_dir.rglob(f"{job_id}.sql")
            if path.is_file()
        ),
        _dml_search_dir(kind, entity) / f"{job_id}.sql",
    )
    resolved_target_db = (
        target_db or os.getenv("CLICKHOUSE_GOLD_TARGET_DB") or default_target_db(kind)
    )
    return GoldSqlJob(
        kind=kind,
        job_id=job_id,
        sql_file=sql_file,
        target_db=resolved_target_db,
        target_table=f"{resolved_target_db}.{job_id}",
    )


def discover_gold_sql_jobs(
    kind: GoldJobKind,
    *,
    entity: Optional[SignalEntity] = None,
    family: Optional[str] = None,
    target_db: Optional[str] = None,
) -> list[GoldSqlJob]:
    """Discover all executable Gold SQL jobs for a kind."""
    if kind != "signal" and (entity or family):
        raise ValueError("Entity and family filters are only supported for signal SQL jobs")
    if family is not None:
        family = validate_signal_family(family)
    if entity and family:
        raise ValueError("Use --entity or --family as separate signal selectors, not both")

    if kind == "scenario":
        pattern = "scenario_*.sql"
        search_dirs = [_dml_search_dir(kind)]
    elif entity:
        pattern = f"sig_{entity}_*.sql"
        search_dirs = [_dml_search_dir(kind, entity)]
    elif family:
        pattern = f"sig_*_{family}_*.sql"
        search_dirs = [_dml_search_dir(kind)]
    else:
        pattern = "sig_*.sql"
        search_dirs = [_dml_search_dir(kind, signal_entity) for signal_entity in SIGNAL_ENTITIES]

    jobs: list[GoldSqlJob] = []
    seen_job_ids: set[str] = set()
    for search_dir in search_dirs:
        for path in sorted(search_dir.rglob(pattern)):
            if not path.is_file() or path.stem in seen_job_ids:
                continue
            seen_job_ids.add(path.stem)
            jobs.append(resolve_gold_sql_job(kind, path.stem, target_db=target_db))
    return jobs


def execute_gold_sql_job(
    client: Optional[ClickHouseClient],
    job: GoldSqlJob,
    *,
    dry_run: bool,
    log,
) -> bool:
    """Execute one Gold SQL job and optimize its target table."""
    if not job.sql_file.exists():
        log.error("Gold %s SQL file not found: %s", job.kind, job.sql_file)
        return False

    if dry_run:
        log.info(
            "[dry-run] Would execute Gold %s SQL job %s from %s into %s",
            job.kind,
            job.job_id,
            job.sql_file,
            job.target_table,
        )
        return True
    if client is None:
        raise RuntimeError("ClickHouse client is required when dry_run is false")

    started_at = time.perf_counter()
    insert_query = job.sql_file.read_text(encoding="utf-8").strip().rstrip(";")
    if job.kind == "scenario":
        insert_query = insert_query.replace(f"{gold_scenarios_db()}.", f"{job.target_db}.")
        insert_query = insert_query.replace("gold.scenario_", f"{job.target_db}.scenario_")
    else:
        insert_query = insert_query.replace(f"{gold_signals_db()}.", f"{job.target_db}.")
        insert_query = insert_query.replace("gold.sig_", f"{job.target_db}.sig_")
        insert_query = insert_query.replace("gold.signal_", f"{job.target_db}.signal_")

    client.execute(insert_query)
    log.info("Gold %s SQL job completed: %s", job.kind, job.job_id)

    optimize_sql = f"OPTIMIZE TABLE {job.target_table} FINAL DEDUPLICATE"
    client.execute(optimize_sql)
    log.info(
        "Optimized Gold %s SQL job target %s in %.2f seconds",
        job.kind,
        job.target_table,
        time.perf_counter() - started_at,
    )
    return True
