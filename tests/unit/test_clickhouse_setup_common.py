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
