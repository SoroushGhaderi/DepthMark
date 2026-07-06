"""Explicit ClickHouse table optimization for operator-invoked maintenance."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Sequence

project_root = Path(__file__).resolve().parents[2]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from config.settings import get_settings
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.logging_utils import get_logger

logger = get_logger(__name__)

LAYER_DATABASES = {
    "bronze": ("bronze",),
    "silver": ("silver",),
    "gold": ("gold_scenarios", "gold_signals", "gold"),
}


@dataclass(frozen=True)
class OptimizeTarget:
    """One ClickHouse table selected for explicit maintenance optimization."""

    database: str
    table: str

    @property
    def qualified_name(self) -> str:
        return f"{self.database}.{self.table}"


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    """Parse operator maintenance arguments."""
    parser = argparse.ArgumentParser(
        description=(
            "Plan or execute explicit ClickHouse OPTIMIZE maintenance. Dry-run is the "
            "default; pass --execute with an explicit --layer or --database to mutate tables."
        )
    )
    parser.add_argument(
        "--layer",
        choices=("bronze", "silver", "gold", "all"),
        default="all",
        help="Warehouse layer to optimize (default: all).",
    )
    parser.add_argument(
        "--database",
        choices=("bronze", "silver", "gold_scenarios", "gold_signals", "gold"),
        help="Optional exact ClickHouse database selector.",
    )
    parser.add_argument(
        "--table",
        help="Optional exact table name inside the selected database or layer.",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Execute OPTIMIZE statements. Omit this flag for dry-run planning.",
    )
    return parser.parse_args(argv)


def _validate_identifier(value: str, label: str) -> str:
    if not ClickHouseClient._SAFE_IDENT.fullmatch(value):
        raise ValueError(f"Unsafe {label}: {value}")
    return value


def selected_databases(layer: str, database: Optional[str]) -> tuple[str, ...]:
    """Resolve the ClickHouse databases selected by CLI filters."""
    if database:
        _validate_identifier(database, "database")
        if layer != "all" and database not in LAYER_DATABASES[layer]:
            raise ValueError(f"Database {database} is not part of layer {layer}")
        return (database,)
    if layer == "all":
        return tuple(database for databases in LAYER_DATABASES.values() for database in databases)
    return LAYER_DATABASES[layer]


def discover_targets(
    client: ClickHouseClient,
    databases: Sequence[str],
    table: Optional[str],
) -> list[OptimizeTarget]:
    """Discover selected ClickHouse tables from system metadata."""
    if table:
        _validate_identifier(table, "table")
    database_values = ", ".join(f"'{database}'" for database in databases)
    table_predicate = f" AND name = '{table}'" if table else ""
    rows = client.execute(
        "SELECT database, name FROM system.tables "
        f"WHERE database IN ({database_values}){table_predicate} "
        "AND engine LIKE '%MergeTree%' "
        "ORDER BY database, name",
        log_query=False,
    ).result_rows
    return [OptimizeTarget(str(database), str(name)) for database, name in rows]


def optimize_statement(target: OptimizeTarget) -> str:
    """Build the maintenance OPTIMIZE statement for one selected table."""
    _validate_identifier(target.database, "database")
    _validate_identifier(target.table, "table")
    return f"OPTIMIZE TABLE {target.qualified_name} FINAL DEDUPLICATE"


def run(argv: Optional[Sequence[str]] = None) -> int:
    """Plan or execute explicit ClickHouse optimization."""
    args = parse_args(argv)
    if args.execute and args.layer == "all" and not args.database:
        logger.error("Executing optimization requires an explicit --layer or --database scope")
        return 2
    try:
        databases = selected_databases(args.layer, args.database)
    except ValueError as error:
        logger.error(str(error))
        return 2

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
        targets = discover_targets(client, databases, args.table)
        if not targets:
            logger.warning(
                "No ClickHouse tables selected for optimization",
                layer=args.layer,
                database=args.database,
                table=args.table,
            )
            return 0

        logger.info(
            "Planning ClickHouse optimization",
            dry_run=not args.execute,
            selected_tables=len(targets),
            databases=list(databases),
        )
        for target in targets:
            statement = optimize_statement(target)
            if args.execute:
                logger.info("Executing ClickHouse optimization", table=target.qualified_name)
                client.execute(statement)
            else:
                logger.info("Dry-run ClickHouse optimization", statement=statement)
        return 0
    except ValueError as error:
        logger.error(str(error))
        return 2
    except Exception as error:
        logger.exception("ClickHouse optimization failed", error=str(error))
        return 1
    finally:
        client.disconnect()


def main() -> int:
    return run()


if __name__ == "__main__":
    raise SystemExit(main())
