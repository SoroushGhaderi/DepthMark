from datetime import datetime
from types import SimpleNamespace

import pytest

from src.fotmob.gold.service import GoldService
from src.warehouse.publication import (
    PublicationLog,
    assert_upstream_published,
    find_unpublished_partitions,
)
from src.warehouse.quality import DataQualitySummary
from src.warehouse.scope import WarehouseExecutionScope
from src.warehouse.scoped_replace import ScopedReplacementBatch, ScopedSqlJob

LOG = PublicationLog("silver.scope_publication", "silver")


class RecordingLogger:
    def info(self, *args, **kwargs):
        pass

    def error(self, *args, **kwargs):
        pass

    def warning(self, *args, **kwargs):
        pass


class PublicationClient:
    """Fake ClickHouse client that records statements and serves publication rows."""

    def __init__(self, *, table_exists=True, status_rows=None, fail_on=None):
        self.table_exists = table_exists
        self.status_rows = status_rows or []
        self.fail_on = fail_on
        self.queries = []
        self.status_writes = []

    def execute(self, query, parameters=None, *, log_query=True):
        self.queries.append(query)
        if self.fail_on and self.fail_on in query:
            raise RuntimeError("injected failure")
        if query.startswith("EXISTS TABLE"):
            return SimpleNamespace(result_rows=[(1 if self.table_exists else 0,)])
        if query.startswith("INSERT INTO silver.scope_publication"):
            self.status_writes.append(parameters)
            return SimpleNamespace(result_rows=[])
        if "GROUP BY batch, partition_id" in query:
            return SimpleNamespace(result_rows=self.status_rows)
        if query.startswith("SELECT count()"):
            return SimpleNamespace(result_rows=[(1,)])
        return SimpleNamespace(result_rows=[])


def _job(table):
    return ScopedSqlJob(
        job_id=table.rsplit(".", 1)[-1],
        target_table=table,
        statements=(f"INSERT INTO {table} SELECT 1",),
        date_expression="match_date",
    )


def _batch(client, scope=None):
    return ScopedReplacementBatch(
        client,
        scope or WarehouseExecutionScope.for_month("202512"),
        log=RecordingLogger(),
        run_id="run1",
        publication=LOG,
    )


def test_successful_batch_records_committing_then_published():
    client = PublicationClient()

    _batch(client).run([_job("silver.match"), _job("silver.shot")])

    assert [write["status"] for write in client.status_writes] == ["committing", "published"]
    published = client.status_writes[-1]
    assert published["partition_id"] == 202512
    assert published["committed_tables"] == ["silver.match", "silver.shot"]
    assert published["batch"] == "silver"


def test_full_history_batch_records_partition_zero():
    client = PublicationClient()

    _batch(client, WarehouseExecutionScope.full_history()).run([_job("silver.match")])

    assert {write["partition_id"] for write in client.status_writes} == {0}


def test_partial_commit_records_failed_with_committed_tables():
    client = PublicationClient(
        fail_on="REPLACE PARTITION 202512 FROM warehouse_stage._depthmark_run1_silver__shot"
    )

    with pytest.raises(RuntimeError, match="injected failure"):
        _batch(client).run([_job("silver.match"), _job("silver.shot")])

    failed = client.status_writes[-1]
    assert failed["status"] == "failed"
    assert failed["committed_tables"] == ["silver.match"]
    assert failed["tables"] == ["silver.match", "silver.shot"]
    assert "injected failure" in failed["error"]


def test_staging_failure_records_no_status():
    client = PublicationClient(fail_on="warehouse_stage._depthmark_run1_silver__shot_calc")

    with pytest.raises(RuntimeError):
        _batch(client).run([_job("silver.match"), _job("silver.shot")])

    assert client.status_writes == []


def test_missing_publication_table_fails_before_staging():
    client = PublicationClient(table_exists=False)

    with pytest.raises(RuntimeError, match="setup_fotmob_warehouse.py"):
        _batch(client).run([_job("silver.match")])

    assert not any(query.startswith("CREATE TABLE") for query in client.queries)


def _row(partition_id, status, minute, run_id="r"):
    return (
        "silver",
        partition_id,
        status,
        run_id,
        str(partition_id),
        ["silver.match"],
        datetime(2026, 10, 10, 12, minute),
    )


def test_unpublished_partitions_respect_later_full_history_runs():
    client = PublicationClient(
        status_rows=[
            _row(202511, "failed", 1),  # superseded by the published full-history run
            _row(202512, "committing", 5),  # newer than the full-history run
            _row(202601, "published", 6),
            _row(0, "published", 3),
        ]
    )

    unpublished = find_unpublished_partitions(client, "silver.scope_publication", "silver")

    assert [(item.partition_id, item.status) for item in unpublished] == [(202512, "committing")]


def test_failed_full_history_run_is_always_reported():
    client = PublicationClient(status_rows=[_row(0, "failed", 3), _row(202512, "published", 5)])

    unpublished = find_unpublished_partitions(client, "silver.scope_publication")

    assert [item.partition_label for item in unpublished] == ["all partitions (full-history)"]


def test_upstream_guard_names_unpublished_partitions():
    client = PublicationClient(status_rows=[_row(202512, "failed", 1, run_id="abc")])

    with pytest.raises(RuntimeError, match="silver 202512: failed \\(run abc"):
        assert_upstream_published(client, LOG, consumer="Gold load")


def test_gold_load_is_blocked_by_unpublished_silver():
    client = PublicationClient(status_rows=[_row(202512, "failed", 1)])

    result = GoldService(client=client, metadata_db="gold").run(
        scope=WarehouseExecutionScope.for_date("20251208")
    )

    assert result.exit_code == 1
    assert not any(query.startswith("CREATE TABLE") for query in client.queries)


def test_unpublished_partitions_fail_the_quality_summary():
    client = PublicationClient(status_rows=[_row(202512, "failed", 1)])
    summary = DataQualitySummary(
        unpublished_partitions=find_unpublished_partitions(client, "silver.scope_publication")
    )

    assert summary.has_failures
