"""Drop every table of one FotMob warehouse layer (bronze or silver) in ClickHouse."""

import argparse
import time
from collections.abc import Sequence
from contextlib import ExitStack

from src.common.logging import get_logger
from src.integrations.clickhouse.client import ClickHouseClient
from src.warehouse.identities import Identity, warehouse_session

logger = get_logger()


def parse_args(argv: Sequence[str] | None = None, layer: str = "bronze") -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=f"Drop all tables from the {layer} ClickHouse schema"
    )
    parser.add_argument(
        "--database",
        default=layer,
        help=f"Target database name (default: {layer})",
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


def main(argv: Sequence[str] | None = None, layer: str = "bronze") -> int:
    """Drop every table in the layer's database (maintenance identity)."""
    args = parse_args(argv, layer)
    database = args.database

    with ExitStack() as stack:
        try:
            client = stack.enter_context(warehouse_session(Identity.MAINTENANCE))
        except RuntimeError as error:
            logger.error(str(error))
            return 1
        find_start = time.perf_counter()
        tables = _find_tables(client, database)
        find_elapsed_seconds = time.perf_counter() - find_start
        logger.info("%s table discovery completed in %.2f seconds", layer, find_elapsed_seconds)

        if not tables:
            logger.info("No tables found in %s", database)
            return 0

        total_tables = len(tables)
        logger.info("Found %s %s table(s) in %s", total_tables, layer, database)

        for index, table in enumerate(tables, start=1):
            full_table = f"{database}.{table}"
            if args.dry_run:
                logger.info(
                    "[dry-run] Would drop %s table %s/%s: %s",
                    layer,
                    index,
                    total_tables,
                    full_table,
                )
                continue

            logger.info(
                "Dropping %s table %s/%s: %s",
                layer,
                index,
                total_tables,
                full_table,
            )
            drop_start = time.perf_counter()
            client.execute(f"DROP TABLE IF EXISTS {full_table}")
            drop_elapsed_seconds = time.perf_counter() - drop_start
            logger.info(
                "Dropped %s table %s/%s: %s in %.2f seconds",
                layer,
                index,
                total_tables,
                full_table,
                drop_elapsed_seconds,
            )

        if args.dry_run:
            logger.info("Dry-run completed")
        else:
            logger.info("All %s tables dropped successfully", layer)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
