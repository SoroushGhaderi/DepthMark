"""Create the isolated Oddspedia Bronze and resolution warehouse tables."""

import argparse
import sys
from pathlib import Path
from typing import Optional, Sequence

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config.settings import get_settings
from src.common.logging import get_logger
from src.integrations.clickhouse.client import ClickHouseClient
from src.integrations.clickhouse.sql import split_sql_statements
from src.warehouse.schema_drift import (
    assert_setup_sql_is_non_destructive,
    find_schema_drift,
    format_drift_report,
    parse_expected_tables,
)

logger = get_logger(__name__)


def main(argv: Optional[Sequence[str]] = None) -> int:
    """Create missing Oddspedia warehouse tables or print the planned SQL files."""
    parser = argparse.ArgumentParser(description="Create Oddspedia warehouse tables")
    parser.add_argument("--dry-run", action="store_true", help="Print planned SQL files only")
    args = parser.parse_args(argv)
    sql_paths = sorted((PROJECT_ROOT / "clickhouse" / "oddspedia_bronze" / "ddl").glob("*.sql"))
    sql_paths.append(
        PROJECT_ROOT / "clickhouse" / "silver" / "ddl" / "09_oddspedia_match_resolution.sql"
    )
    try:
        assert_setup_sql_is_non_destructive(sql_paths)
    except ValueError as error:
        logger.error("Refusing to run Oddspedia setup", error=str(error))
        return 1
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
        drifts = find_schema_drift(client, parse_expected_tables(sql_paths))
        if drifts:
            logger.error(
                "Refusing to run Oddspedia setup: existing tables drifted from their setup DDL. "
                "Setup never drops or alters tables; plan a Table Recreation with "
                "scripts/maintenance/recreate_clickhouse_tables.py --drifted.\n"
                + format_drift_report(drifts),
                drifted_tables=len(drifts),
            )
            return 1
        for path in sql_paths:
            for statement in split_sql_statements(path.read_text(encoding="utf-8")):
                client.execute(statement)
        return 0
    finally:
        client.disconnect()


if __name__ == "__main__":
    print(
        "Warning: scripts/oddspedia/setup_warehouse.py is deprecated; use "
        "scripts/oddspedia/setup_oddspedia_warehouse.py instead.",
        file=sys.stderr,
    )
    raise SystemExit(main())
