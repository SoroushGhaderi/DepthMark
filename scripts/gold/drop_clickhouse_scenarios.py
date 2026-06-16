"""Drop FotMob gold scenario and/or signal tables in ClickHouse."""

import argparse
import sys
import time
from pathlib import Path

project_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(project_root))

from config.settings import get_settings
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.gold_databases import gold_db, gold_scenarios_db, gold_signals_db
from src.utils.logging_utils import get_logger

logger = get_logger()


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Drop scenario/signal tables from the gold ClickHouse schema"
    )
    parser.add_argument(
        "--part",
        choices=("all", "scenarios", "signals"),
        default="scenarios",
        help="Which gold tables to drop: scenarios, signals, or all (default: scenarios)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List matching tables without dropping them",
    )
    return parser.parse_args(argv)


def _find_tables(client: ClickHouseClient, database: str, part: str) -> list[str]:
    prefixes = []
    if part == "scenarios":
        prefixes.append("scenario_")
    elif part == "signals":
        prefixes.append("sig_")
    elif part == "metadata":
        return ["signal_activations"]
    if not prefixes:
        return []

    prefix_filter = " OR ".join(f"startsWith(name, '{prefix}')" for prefix in prefixes)
    query = """
        SELECT name
        FROM system.tables
        WHERE database = %(database)s
          AND ({prefix_filter})
        ORDER BY name
    """.format(prefix_filter=prefix_filter)
    result = client.execute(query, {"database": database})
    return [row[0] for row in result.result_rows]


def main(argv=None) -> int:
    args = parse_args(argv)
    settings = get_settings()

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
        db_targets = []
        if args.part in ("all", "scenarios"):
            db_targets.append(("scenarios", gold_scenarios_db(), "scenarios"))
        if args.part in ("all", "signals"):
            db_targets.append(("signals", gold_signals_db(), "signals"))
        if args.part in ("all", "signals"):
            db_targets.append(("metadata", gold_db(), "metadata"))

        find_elapsed_seconds = time.perf_counter() - find_start
        logger.info(
            "Gold %s table discovery completed in %.2f seconds",
            args.part,
            find_elapsed_seconds,
        )

        dropped_any = False
        for group_name, database, lookup_part in db_targets:
            tables = _find_tables(client, database, lookup_part)
            if not tables:
                logger.info("No %s tables found in %s", group_name, database)
                continue
            total_tables = len(tables)
            logger.info("Found %s gold %s table(s) in %s", total_tables, group_name, database)
            dropped_any = True
            for index, table in enumerate(tables, start=1):
                full_table = f"{database}.{table}"
                if args.dry_run:
                    logger.info(
                        "[dry-run] Would drop gold %s table %s/%s: %s",
                        group_name,
                        index,
                        total_tables,
                        full_table,
                    )
                    continue
                logger.info(
                    "Dropping gold %s table %s/%s: %s",
                    group_name,
                    index,
                    total_tables,
                    full_table,
                )
                drop_start = time.perf_counter()
                client.execute(f"DROP TABLE IF EXISTS {full_table}")
                drop_elapsed_seconds = time.perf_counter() - drop_start
                logger.info(
                    "Dropped gold %s table %s/%s: %s in %.2f seconds",
                    group_name,
                    index,
                    total_tables,
                    full_table,
                    drop_elapsed_seconds,
                )

        if not dropped_any:
            return 0

        if args.dry_run:
            logger.info("Dry-run completed")
        else:
            logger.info("All matching gold %s tables dropped successfully", args.part)
        return 0
    finally:
        client.disconnect()


if __name__ == "__main__":
    raise SystemExit(main())
