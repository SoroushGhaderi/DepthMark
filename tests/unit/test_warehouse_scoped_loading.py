import argparse
from types import SimpleNamespace

import pytest

from src.fotmob.bronze import BronzeService
from src.fotmob.commands import load_bronze as bronze_loader
from src.fotmob.commands import load_gold as gold_loader
from src.fotmob.commands import load_silver as silver_loader
from src.fotmob.commands.load_bronze import discover_historical_dates
from src.warehouse.scope import (
    WarehouseExecutionScope,
    add_warehouse_scope_arguments,
    execution_scope_from_args,
)
from src.warehouse.scoped_replace import (
    ScopedReplacementBatch,
    ScopedSqlJob,
    replace_insert_target,
)


class RecordingLogger:
    def __init__(self):
        self.messages = []

    def info(self, message, *args, **kwargs):
        self.messages.append(("info", message, args, kwargs))

    def error(self, message, *args, **kwargs):
        self.messages.append(("error", message, args, kwargs))

    def warning(self, message, *args, **kwargs):
        self.messages.append(("warning", message, args, kwargs))


class RecordingClient:
    def __init__(self, *, counts=None, fail_on=None):
        self.queries = []
        self.counts = iter(counts or [1, 1])
        self.fail_on = fail_on

    def execute(self, query, parameters=None, *, log_query=True):
        self.queries.append(query)
        if self.fail_on and self.fail_on in query:
            raise RuntimeError("injected failure")
        if query.startswith("SELECT count()"):
            return SimpleNamespace(result_rows=[(next(self.counts),)])
        return SimpleNamespace(result_rows=[])


def _job(table="silver.match"):
    return ScopedSqlJob(
        job_id=table.rsplit(".", 1)[-1],
        target_table=table,
        statements=(f"INSERT INTO {table} SELECT 1",),
        date_expression="match_date",
    )


@pytest.mark.parametrize(
    ("argv", "kind", "value"),
    [
        (["--date", "20251208"], "date", "20251208"),
        (["--month", "202512"], "month", "202512"),
        (["--full-history"], "full-history", None),
        (["--single-date", "20251208"], "date", "20251208"),
    ],
)
def test_scope_argument_modes(argv, kind, value):
    parser = argparse.ArgumentParser()
    add_warehouse_scope_arguments(parser)
    scope = execution_scope_from_args(parser.parse_args(argv))
    assert (scope.kind, scope.value) == (kind, value)


@pytest.mark.parametrize(
    "argv",
    [[], ["--date", "20251208", "--month", "202512"], ["--date", "20250230"]],
)
def test_scope_arguments_reject_missing_conflicting_and_invalid_values(argv):
    parser = argparse.ArgumentParser()
    add_warehouse_scope_arguments(parser)
    if argv == ["--date", "20250230"]:
        args = parser.parse_args(argv)
        with pytest.raises(ValueError, match="YYYYMMDD"):
            execution_scope_from_args(args)
    else:
        with pytest.raises(SystemExit):
            parser.parse_args(argv)


def test_loader_parsers_require_explicit_scope():
    with pytest.raises(SystemExit):
        silver_loader.parse_args([])
    with pytest.raises(SystemExit):
        gold_loader.parse_args([])


def test_bronze_loader_parser_accepts_dry_run():
    args = bronze_loader.parse_args(["--date", "20251208", "--replace", "--dry-run"])
    assert args.date == "20251208"
    assert args.replace is True
    assert args.dry_run is True


@pytest.mark.parametrize(
    "argv, message",
    [
        (["--date", "20251208", "--truncate"], "no longer accepted"),
        (["--month", "202512", "--truncate"], "no longer accepted"),
        (["--date", "20251208", "--rebuild"], "requires --full-history"),
        (["--full-history", "--replace"], "Use --rebuild"),
        (["--date", "20251208", "--replace", "--rebuild"], "requires --full-history"),
    ],
)
def test_bronze_loader_rejects_unsafe_scope_combinations(argv, message):
    with pytest.raises(SystemExit) as exit_info:
        bronze_loader.validate_arguments(bronze_loader.parse_args(argv))
    assert message in str(exit_info.value)


def test_deprecated_full_history_truncate_runs_a_rebuild(capsys):
    args = bronze_loader.parse_args(["--full-history", "--truncate"])

    bronze_loader.validate_arguments(args)

    assert args.rebuild is True
    assert bronze_loader._write_mode(args) == "rebuild"
    assert "deprecated" in capsys.readouterr().err


def test_bronze_service_dry_run_does_not_load(monkeypatch):
    service = BronzeService(client=None)
    calls = []

    monkeypatch.setattr(service, "load_dates", lambda *args, **kwargs: calls.append("load"))

    result = service.run(dates=["20251208"], dry_run=True, mode="replace")

    assert result.exit_code == 0
    assert result.dates_processed == 1
    assert calls == []


def test_bronze_loader_dry_run_skips_clickhouse_and_telegram(monkeypatch):
    connected = []
    notifications = []

    def blocking_session(*args, **kwargs):
        connected.append(("session", args, kwargs))
        raise AssertionError("dry-run must not open a warehouse session")

    class RecordingTelegramClient:
        def render_and_send(self, *args, **kwargs):
            notifications.append((args, kwargs))

    monkeypatch.setattr(bronze_loader, "warehouse_session", blocking_session)
    monkeypatch.setattr(bronze_loader, "TelegramClient", lambda: RecordingTelegramClient())
    monkeypatch.setattr(bronze_loader, "setup_logging", lambda *args, **kwargs: RecordingLogger())

    exit_code = bronze_loader.main(["--date", "20251208", "--replace", "--dry-run"])

    assert exit_code == 0
    assert connected == []
    assert notifications == []


def test_date_scope_reconstructs_month_and_never_deletes_whole_table():
    client = RecordingClient(counts=[3, 8])
    batch = ScopedReplacementBatch(
        client,
        WarehouseExecutionScope.for_date("20251208"),
        log=RecordingLogger(),
        run_id="test",
    )
    batch.run([_job()])
    sql = "\n".join(client.queries)
    assert "AND NOT (match_date = toDate('2025-12-08'))" in sql
    assert "REPLACE PARTITION 202512" in sql
    assert "TRUNCATE TABLE" not in sql
    assert "DELETE FROM" not in sql


def test_removed_source_rows_drop_only_the_selected_month_partition():
    client = RecordingClient(counts=[0, 4])
    batch = ScopedReplacementBatch(
        client,
        WarehouseExecutionScope.for_month("202512"),
        log=RecordingLogger(),
        run_id="test",
    )
    batch.run([_job()])
    sql = "\n".join(client.queries)
    assert "ALTER TABLE silver.match DROP PARTITION 202512" in sql
    assert "DROP TABLE silver.match" not in sql


def test_full_history_uses_staged_exchange():
    client = RecordingClient()
    batch = ScopedReplacementBatch(
        client,
        WarehouseExecutionScope.full_history(),
        log=RecordingLogger(),
        run_id="test",
    )
    batch.run([_job()])
    assert any(query.startswith("EXCHANGE TABLES silver.match") for query in client.queries)
    assert not any("TRUNCATE TABLE" in query for query in client.queries)


def test_staging_failure_leaves_all_targets_uncommitted():
    client = RecordingClient(fail_on="warehouse_stage._depthmark_test_silver__period_stat_calc")
    batch = ScopedReplacementBatch(
        client,
        WarehouseExecutionScope.full_history(),
        log=RecordingLogger(),
        run_id="test",
    )
    with pytest.raises(RuntimeError, match="injected failure"):
        batch.run([_job(), _job("silver.period_stat")])
    assert not any(query.startswith("EXCHANGE TABLES") for query in client.queries)
    assert not any(" REPLACE PARTITION " in query for query in client.queries)


def test_dry_run_is_mutation_free_and_reports_full_history_context():
    client = RecordingClient()
    log = RecordingLogger()
    batch = ScopedReplacementBatch(
        client,
        WarehouseExecutionScope.for_date("20251208"),
        dry_run=True,
        log=log,
    )
    batch.run([_job()])
    assert client.queries == []
    assert "input=%s" in log.messages[0][1]
    assert "all available history" in log.messages[0][2]


def test_insert_rewrite_is_target_specific():
    sql = "INSERT INTO silver.match SELECT * FROM bronze.general"
    assert replace_insert_target(sql, "silver.match", "silver.stage") == (
        "INSERT INTO silver.stage SELECT * FROM bronze.general"
    )
    with pytest.raises(ValueError, match="expected target"):
        replace_insert_target(sql, "silver.shot", "silver.stage")


def test_month_scope_has_calendar_boundaries():
    scope = WarehouseExecutionScope.for_month("202512")
    assert scope.output_range == "[2025-12-01, 2026-01-01)"
    assert scope.partition_id == 202512


def test_full_history_bronze_discovery_excludes_live_and_invalid_names(tmp_path):
    historical = tmp_path / "historical"
    (historical / "matches" / "202512" / "20251208").mkdir(parents=True)
    (historical / "daily_listings" / "202512" / "20251209").mkdir(parents=True)
    (historical / "matches" / "not-a-date").mkdir()
    (tmp_path / "live" / "matches" / "20251210").mkdir(parents=True)
    assert discover_historical_dates(historical) == ["20251208", "20251209"]
