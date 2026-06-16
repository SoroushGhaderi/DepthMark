"""Drop all FotMob silver tables in ClickHouse."""

import argparse
import sys
import time
from pathlib import Path

project_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(project_root))

from config.settings import get_settings
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.logging_utils import get_logger

logger = get_logger()


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Drop all tables from the silver ClickHouse schema"
    )
    parser.add_argument(
        "--database",
        default="silver",
        help="Target database name (default: silver)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List matching tables without dropping them",
    )
    return parser.parse_args(argv)


def _find_tables(client: ClickHouseClient, database: str) -> list[str]:
    query = """
        SELECT name
        FROM system.tables
        WHERE database = %(database)s
        ORDER BY name
    """
    result = client.execute(query, {"database": database})
    return [row[0] for row in result.result_rows]


def main(argv=None) -> int:
    args = parse_args(argv)
    settings = get_settings()
    database = args.database

    client = ClickHouseClient(
        host=settings.clickhouse_host,
        port=settings.clickhouse_port,
        username=settings.clickhouse_user,
        password=settings.clickhouse_password,
        database="default",
    )

    if not client.connect():
        logger.error("Failed to connect to ClickHouse")
        return 1

    try:
        find_start = time.perf_counter()
        tables = _find_tables(client, database)
        find_elapsed_seconds = time.perf_counter() - find_start
        logger.info("Silver table discovery completed in %.2f seconds", find_elapsed_seconds)

        if not tables:
            logger.info("No tables found in %s", database)
            return 0

        total_tables = len(tables)
        logger.info("Found %s silver table(s) in %s", total_tables, database)

        for index, table in enumerate(tables, start=1):
            full_table = f"{database}.{table}"
            if args.dry_run:
                logger.info(
                    "[dry-run] Would drop silver table %s/%s: %s",
                    index,
                    total_tables,
                    full_table,
                )
                continue

            logger.info(
                "Dropping silver table %s/%s: %s",
                index,
                total_tables,
                full_table,
            )
            drop_start = time.perf_counter()
            client.execute(f"DROP TABLE IF EXISTS {full_table}")
            drop_elapsed_seconds = time.perf_counter() - drop_start
            logger.info(
                "Dropped silver table %s/%s: %s in %.2f seconds",
                index,
                total_tables,
                full_table,
                drop_elapsed_seconds,
            )

        if args.dry_run:
            logger.info("Dry-run completed")
        else:
            logger.info("All silver tables dropped successfully")
        return 0
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
