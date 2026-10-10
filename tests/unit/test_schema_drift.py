from pathlib import Path

import pytest

from scripts.clickhouse_setup_common import LAYER_ORDER, get_layer_sql_files
from src.warehouse.schema_drift import (
    assert_setup_sql_is_non_destructive,
    find_disallowed_setup_statements,
    find_schema_drift,
    parse_create_table,
    parse_expected_tables,
)

PROJECT_ROOT = Path(__file__).resolve().parents[2]

SIGNAL_DDL = """
CREATE TABLE IF NOT EXISTS gold_signals.sig_example (
    match_id Int32,
    player_id Nullable(Int32),
    kicked_at Nullable(DateTime64(3, 'UTC')),
    signal_instance_id String DEFAULT lower(hex(SHA256(concat('v1', '|', toString(match_id))))),
    inserted_at DateTime DEFAULT now(),
    INDEX idx_player player_id TYPE minmax GRANULARITY 1
) ENGINE = ReplacingMergeTree(inserted_at)
PARTITION BY toYYYYMM(toDate(match_id))
ORDER BY (match_id, ifNull(player_id, -1), signal_instance_id)
SETTINGS index_granularity = 8192;
"""


class FakeSystemTablesClient:
    """Answer the system.tables / system.columns queries used by drift detection."""

    def __init__(self, tables):
        self.tables = tables
        self.queries = []

    def execute(self, query, *args, **kwargs):
        self.queries.append(query)
        if "FROM system.columns" in query:
            rows = [
                (database, table, name, column_type)
                for (database, table), (columns, _) in self.tables.items()
                for name, column_type in columns
            ]
        elif "sorting_key" in query:
            rows = [
                (database, table, sorting_key)
                for (database, table), (_, sorting_key) in self.tables.items()
            ]
        else:
            rows = []
        return type("Result", (), {"result_rows": rows})()


def _write_ddl(tmp_path: Path, text: str = SIGNAL_DDL) -> Path:
    path = tmp_path / "create_table_example.sql"
    path.write_text(text, encoding="utf-8")
    return path


def _live_example(columns=None, sorting_key=None):
    columns = columns or [
        ("match_id", "Int32"),
        ("player_id", "Nullable(Int32)"),
        ("kicked_at", "Nullable(DateTime64(3, 'UTC'))"),
        ("signal_instance_id", "String"),
        ("inserted_at", "DateTime"),
    ]
    sorting_key = sorting_key or "match_id, ifNull(player_id, -1), signal_instance_id"
    return {("gold_signals", "sig_example"): (columns, sorting_key)}


def test_parse_create_table_reads_columns_and_sorting_key(tmp_path: Path):
    table = parse_expected_tables([_write_ddl(tmp_path)])[0]

    assert table.qualified_name == "gold_signals.sig_example"
    assert table.columns == (
        ("match_id", "Int32"),
        ("player_id", "Nullable(Int32)"),
        ("kicked_at", "Nullable(DateTime64(3,'UTC'))"),
        ("signal_instance_id", "String"),
        ("inserted_at", "DateTime"),
    )
    assert table.sorting_key == ("match_id", "ifNull(player_id,-1)", "signal_instance_id")


def test_unqualified_or_unconditional_create_is_not_parsed(tmp_path: Path):
    assert parse_create_table("CREATE TABLE example (id Int32) ENGINE = Log", tmp_path) is None


def test_matching_schema_with_clickhouse_formatting_is_not_drift(tmp_path: Path):
    expected = parse_expected_tables([_write_ddl(tmp_path)])

    assert find_schema_drift(FakeSystemTablesClient(_live_example()), expected) == []


def test_missing_table_is_not_drift(tmp_path: Path):
    expected = parse_expected_tables([_write_ddl(tmp_path)])

    assert find_schema_drift(FakeSystemTablesClient({}), expected) == []


def test_drift_reports_column_type_and_sorting_key_changes(tmp_path: Path):
    expected = parse_expected_tables([_write_ddl(tmp_path)])
    live = _live_example(
        columns=[
            ("match_id", "Int64"),
            ("player_id", "Nullable(Int32)"),
            ("signal_instance_id", "String"),
            ("inserted_at", "DateTime"),
            ("legacy_flag", "UInt8"),
        ],
        sorting_key="match_id, signal_instance_id",
    )

    drifts = find_schema_drift(FakeSystemTablesClient(live), expected)

    assert len(drifts) == 1
    assert drifts[0].differences == (
        "column match_id is Int64, DDL declares Int32",
        "missing column kicked_at Nullable(DateTime64(3,'UTC'))",
        "column legacy_flag UInt8 is not in the DDL",
        "ORDER BY is (match_id, signal_instance_id), "
        "DDL declares (match_id, ifNull(player_id,-1), signal_instance_id)",
    )


@pytest.mark.parametrize(
    "statement",
    [
        "DROP TABLE IF EXISTS gold_signals.sig_example;",
        "TRUNCATE TABLE gold_signals.sig_example;",
        "CREATE TABLE gold.stage (id Int32) ENGINE = Memory;",
        "ALTER TABLE gold_signals.sig_example DROP COLUMN player_id;",
    ],
)
def test_guard_rejects_anything_but_create_if_not_exists(tmp_path: Path, statement: str):
    sql_file = _write_ddl(tmp_path, statement + "\n" + SIGNAL_DDL)

    with pytest.raises(ValueError, match="Disallowed statements"):
        assert_setup_sql_is_non_destructive([sql_file])


def test_repository_setup_sql_is_create_only_and_fully_parsed():
    sql_files = [path for layer in LAYER_ORDER for path in get_layer_sql_files(layer)]
    sql_files += sorted((PROJECT_ROOT / "clickhouse" / "oddspedia_bronze" / "ddl").glob("*.sql"))

    assert find_disallowed_setup_statements(sql_files) == []
    tables = parse_expected_tables(sql_files)
    assert len(tables) > 400
    assert all(table.columns and table.sorting_key for table in tables)
    assert {"gold.signal_activations", "silver.match", "oddspedia_bronze.event"} <= {
        table.qualified_name for table in tables
    }
