"""Durable publication status for scoped Silver and Gold batches (ADR 0028).

ClickHouse cannot commit several tables atomically, so a scoped batch commits
its target tables one at a time. The publication log records each batch's
outcome per month partition: ``committing`` before the first commit, then
``published`` once every table committed, or ``failed`` with the tables that
did commit. A partition whose latest status is not ``published`` may mix table
versions; readers must not consume it until a rerun publishes it.

Full-history batches record partition ``0``, meaning every partition.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Optional, Sequence

from src.warehouse.scope import WarehouseExecutionScope

FULL_HISTORY_PARTITION = 0
SILVER_PUBLICATION_TABLE = "silver.scope_publication"
GOLD_PUBLICATION_TABLE = "gold.scope_publication"
SILVER_BATCH = "silver"
GOLD_OUTPUTS_BATCH = "gold_outputs"
GOLD_ACTIVATIONS_BATCH = "gold_activations"
COMMITTING = "committing"
PUBLISHED = "published"
FAILED = "failed"
SAFE_QUALIFIED_TABLE_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*$")


def publication_partition(scope: WarehouseExecutionScope) -> int:
    """Return the month partition a scope replaces, or 0 for full history."""
    return scope.partition_id if scope.partition_id is not None else FULL_HISTORY_PARTITION


@dataclass(frozen=True)
class PublicationLog:
    """One batch's status rows in a layer's ``scope_publication`` table."""

    table: str
    batch: str

    def __post_init__(self) -> None:
        if not SAFE_QUALIFIED_TABLE_RE.fullmatch(self.table):
            raise ValueError(f"Unsafe publication table name: {self.table}")

    def assert_ready(self, client: Any) -> None:
        """Fail before staging when setup has not created the publication table."""
        result = client.execute(f"EXISTS TABLE {self.table}", log_query=False)
        rows = getattr(result, "result_rows", None) or []
        if not rows or not int(rows[0][0]):
            raise RuntimeError(
                f"Publication table {self.table} does not exist; run "
                "python scripts/orchestration/setup_fotmob_warehouse.py to create it"
            )

    def record(
        self,
        client: Any,
        scope: WarehouseExecutionScope,
        *,
        run_id: str,
        status: str,
        tables: Sequence[str],
        committed_tables: Sequence[str] = (),
        error: Optional[str] = None,
    ) -> None:
        """Append one status row for the batch and the scope's partition."""
        client.execute(
            f"INSERT INTO {self.table} "
            "(batch, partition_id, run_id, scope_label, status, tables, committed_tables, error) "
            "VALUES (%(batch)s, %(partition_id)s, %(run_id)s, %(scope_label)s, %(status)s, "
            "%(tables)s, %(committed_tables)s, %(error)s)",
            {
                "batch": self.batch,
                "partition_id": publication_partition(scope),
                "run_id": run_id,
                "scope_label": scope.label,
                "status": status,
                "tables": list(tables),
                "committed_tables": list(committed_tables),
                "error": error,
            },
            log_query=False,
        )


@dataclass(frozen=True)
class UnpublishedPartition:
    """A partition whose latest publication status is not ``published``."""

    batch: str
    partition_id: int
    status: str
    run_id: str
    scope_label: str
    committed_tables: tuple[str, ...]

    @property
    def partition_label(self) -> str:
        if self.partition_id == FULL_HISTORY_PARTITION:
            return "all partitions (full-history)"
        return str(self.partition_id)


def find_unpublished_partitions(
    client: Any, table: str, batch: Optional[str] = None
) -> list[UnpublishedPartition]:
    """Return partitions whose latest batch status is not ``published``.

    A partition row counts only when it is newer than the batch's latest
    full-history row, because a later full-history run replaces every
    partition. A full-history row that is not ``published`` is always reported.
    """
    if not SAFE_QUALIFIED_TABLE_RE.fullmatch(table):
        raise ValueError(f"Unsafe publication table name: {table}")
    batch_filter = " WHERE batch = %(batch)s" if batch else ""
    result = client.execute(
        "SELECT batch, partition_id, argMax(status, updated_at), argMax(run_id, updated_at), "
        "argMax(scope_label, updated_at), argMax(committed_tables, updated_at), "
        f"max(updated_at) FROM {table}{batch_filter} "
        "GROUP BY batch, partition_id ORDER BY batch, partition_id",
        {"batch": batch} if batch else None,
        log_query=False,
    )
    latest = [
        (
            UnpublishedPartition(
                batch=str(row[0]),
                partition_id=int(row[1]),
                status=str(row[2]),
                run_id=str(row[3]),
                scope_label=str(row[4]),
                committed_tables=tuple(row[5] or ()),
            ),
            row[6],
        )
        for row in (getattr(result, "result_rows", None) or [])
    ]
    full_history_at = {
        entry.batch: updated_at
        for entry, updated_at in latest
        if entry.partition_id == FULL_HISTORY_PARTITION
    }
    unpublished: list[UnpublishedPartition] = []
    for entry, updated_at in latest:
        if entry.status == PUBLISHED:
            continue
        superseding_full_history = full_history_at.get(entry.batch)
        if (
            entry.partition_id != FULL_HISTORY_PARTITION
            and superseding_full_history is not None
            and superseding_full_history > updated_at
        ):
            continue
        unpublished.append(entry)
    return unpublished


def describe_unpublished(partitions: Sequence[UnpublishedPartition]) -> str:
    """Format unpublished partitions for operator logs."""
    return "; ".join(
        f"{item.batch} {item.partition_label}: {item.status} (run {item.run_id}, "
        f"scope {item.scope_label}, committed {len(item.committed_tables)} table(s))"
        for item in partitions
    )


def assert_upstream_published(client: Any, log: PublicationLog, consumer: str) -> None:
    """Fail closed when an upstream batch has a partition that is not published."""
    log.assert_ready(client)
    unpublished = find_unpublished_partitions(client, log.table, log.batch)
    if unpublished:
        raise RuntimeError(
            f"{consumer} refuses to read {log.batch} while partitions are not published: "
            f"{describe_unpublished(unpublished)}. Rerun the same {log.batch} scope until it "
            "publishes."
        )


def silver_publication() -> PublicationLog:
    return PublicationLog(SILVER_PUBLICATION_TABLE, SILVER_BATCH)


def gold_outputs_publication() -> PublicationLog:
    return PublicationLog(GOLD_PUBLICATION_TABLE, GOLD_OUTPUTS_BATCH)


def gold_activations_publication() -> PublicationLog:
    return PublicationLog(GOLD_PUBLICATION_TABLE, GOLD_ACTIVATIONS_BATCH)
