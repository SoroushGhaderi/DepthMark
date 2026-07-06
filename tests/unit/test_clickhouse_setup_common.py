from pathlib import Path

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
    optimize_tables.write_text("OPTIMIZE TABLE bronze.general FINAL DEDUPLICATE;\n", encoding="utf-8")

    sql_files = get_layer_sql_files("bronze", clickhouse_root=clickhouse_root)

    assert sql_files == [create_database, create_table]
