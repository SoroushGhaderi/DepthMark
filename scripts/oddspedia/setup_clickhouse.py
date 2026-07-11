"""Create the isolated Oddspedia Bronze and resolution tables."""

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.settings import get_settings
from src.storage.clickhouse_client import ClickHouseClient
from src.storage.clickhouse_sql_executor import split_sql_statements


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Create Oddspedia source-domain ClickHouse tables")
    parser.add_argument("--dry-run", action="store_true", help="Print planned SQL files only")
    args = parser.parse_args(argv)
    sql_paths = sorted((PROJECT_ROOT / "clickhouse" / "oddspedia_bronze" / "ddl").glob("*.sql"))
    sql_paths.append(
        PROJECT_ROOT / "clickhouse" / "silver" / "ddl" / "09_oddspedia_match_resolution.sql"
    )
    if args.dry_run:
        for path in sql_paths:
            print(path.relative_to(PROJECT_ROOT))
        return 0
    settings = get_settings()
    client = ClickHouseClient(
        host=settings.clickhouse_host,
        port=settings.clickhouse_port,
        username=settings.clickhouse_user,
        password=settings.clickhouse_password,
        database="default",
    )
    if not client.connect():
        return 1
    try:
        for path in sql_paths:
            for statement in split_sql_statements(path.read_text(encoding="utf-8")):
                client.execute(statement)
        return 0
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
