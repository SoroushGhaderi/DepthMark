from pathlib import Path

from scripts import clickhouse_setup_common
from scripts.clickhouse_setup_common import get_layer_sql_files


def test_layer_setup_excludes_optimization_sql(tmp_path: Path):
    clickhouse_root = tmp_path / "clickhouse"
    bronze_dir = clickhouse_root / "bronze"
    bronze_dir.mkdir(parents=True)
    create_database = bronze_dir / "00_create_database.sql"
    create_table = bronze_dir / "01_general.sql"
    optimize_tables = bronze_dir / "99_optimize_tables.sql"
    create_database.write_text("CREATE DATABASE IF NOT EXISTS bronze;\n", encoding="utf-8")
    create_table.write_text("CREATE TABLE IF NOT EXISTS bronze.general;\n", encoding="utf-8")
    optimize_tables.write_text(
        "OPTIMIZE TABLE bronze.general FINAL DEDUPLICATE;\n", encoding="utf-8"
    )

    sql_files = get_layer_sql_files("bronze", clickhouse_root=clickhouse_root)

    assert sql_files == [create_database, create_table]


def test_clickhouse_user_grants_are_database_scoped_and_not_all(monkeypatch):
    class _Client:
        def __init__(self):
            self.queries = []

        def execute(self, query):
            self.queries.append(query)
            return type("Result", (), {"result_rows": []})()

    client = _Client()
    monkeypatch.setattr(clickhouse_setup_common, "is_local_development_environment", lambda: False)

    assert clickhouse_setup_common.create_user_if_not_exists(client, "runtime_user", "strong")

    grants = [query for query in client.queries if query.startswith("GRANT")]
    assert grants
    assert all("GRANT ALL" not in query for query in grants)
    assert all("CREATE DATABASE" not in query for query in grants)
    assert any("oddspedia_bronze.*" in query for query in grants)


def test_local_bootstrap_gate_reads_dotenv_and_fails_closed(monkeypatch, tmp_path):
    for name in ("DEPTHMARK_ENV", "ENVIRONMENT", "SCRAPER_ENV"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setattr(clickhouse_setup_common, "project_root", tmp_path)
    env_file = tmp_path / ".env"

    env_file.write_text("DEPTHMARK_ENV=production\n", encoding="utf-8")
    assert not clickhouse_setup_common.is_local_development_environment()

    env_file.write_text("DEPTHMARK_ENV=local\n", encoding="utf-8")
    assert clickhouse_setup_common.is_local_development_environment()

    env_file.unlink()
    assert not clickhouse_setup_common.is_local_development_environment()


class _SetupClient:
    """Fake ClickHouse client that serves live schemas and records executed DDL."""

    def __init__(self, live_tables=None):
        self.live_tables = live_tables or {}
        self.executed = []

    def execute(self, query, *args, **kwargs):
        if "FROM system.columns" in query:
            rows = [
                (database, table, name, column_type)
                for (database, table), (columns, _) in self.live_tables.items()
                for name, column_type in columns
            ]
        elif "FROM system.tables" in query:
            rows = [
                (database, table, sorting_key)
                for (database, table), (_, sorting_key) in self.live_tables.items()
            ]
        else:
            self.executed.append(query)
            rows = []
        return type("Result", (), {"result_rows": rows})()


def _bronze_root(tmp_path: Path, table_sql: str) -> Path:
    bronze_dir = tmp_path / "clickhouse" / "bronze"
    bronze_dir.mkdir(parents=True)
    (bronze_dir / "00_create_database.sql").write_text(
        "CREATE DATABASE IF NOT EXISTS bronze;\n", encoding="utf-8"
    )
    (bronze_dir / "01_general.sql").write_text(table_sql, encoding="utf-8")
    return tmp_path / "clickhouse"


GENERAL_DDL = (
    "CREATE TABLE IF NOT EXISTS bronze.general (\n"
    "    match_id Int32,\n"
    "    inserted_at DateTime DEFAULT now()\n"
    ") ENGINE = ReplacingMergeTree(inserted_at)\n"
    "ORDER BY match_id;\n"
)


def test_gold_setup_excludes_activation_stage_ddl():
    gold_files = get_layer_sql_files("gold")

    assert gold_files
    assert all("activations" not in path.parts for path in gold_files)


def test_setup_creates_missing_tables_when_no_drift(monkeypatch, tmp_path: Path):
    root = _bronze_root(tmp_path, GENERAL_DDL)
    monkeypatch.setattr(clickhouse_setup_common, "resolve_clickhouse_root", lambda: root)
    client = _SetupClient()

    assert clickhouse_setup_common.run_clickhouse_layer_setup("bronze", client=client) == 0
    assert any(
        query.startswith("CREATE TABLE IF NOT EXISTS bronze.general") for query in client.executed
    )


def test_setup_fails_closed_on_drift_before_executing_any_ddl(monkeypatch, tmp_path: Path):
    root = _bronze_root(tmp_path, GENERAL_DDL)
    monkeypatch.setattr(clickhouse_setup_common, "resolve_clickhouse_root", lambda: root)
    client = _SetupClient(
        {("bronze", "general"): ([("match_id", "Int64"), ("inserted_at", "DateTime")], "match_id")}
    )

    assert clickhouse_setup_common.run_clickhouse_layer_setup("bronze", client=client) == 1
    assert client.executed == []


def test_setup_refuses_destructive_sql_before_executing_any_ddl(monkeypatch, tmp_path: Path):
    root = _bronze_root(tmp_path, "DROP TABLE IF EXISTS bronze.general;\n" + GENERAL_DDL)
    monkeypatch.setattr(clickhouse_setup_common, "resolve_clickhouse_root", lambda: root)
    client = _SetupClient()

    assert clickhouse_setup_common.run_clickhouse_layer_setup("bronze", client=client) == 1
    assert client.executed == []
