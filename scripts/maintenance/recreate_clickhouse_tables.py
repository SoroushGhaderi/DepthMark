"""Explicit Table Recreation: drop selected warehouse tables and recreate them empty.

Normal setup never drops or alters tables and fails closed on schema drift
(ADR 0026). This operator command is the only supported way to apply a schema
change to an existing table. It plans by default; ``--execute`` drops each
selected table and recreates it, empty, from its setup DDL. It never reloads
rows: rerun the normal layer loader for the affected scope afterward.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

project_root = Path(__file__).resolve().parents[2]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))
scripts_root = project_root / "scripts"
if str(scripts_root) not in sys.path:
    sys.path.insert(0, str(scripts_root))

from clickhouse_setup_common import LAYER_ORDER, get_layer_sql_files, resolve_clickhouse_root

from src.common.logging import get_logger
from src.integrations.clickhouse.client import ClickHouseClient
from src.warehouse.identities import maintenance_client
from src.warehouse.schema_drift import (
    ExpectedTable,
    find_schema_drift,
    format_drift_report,
    parse_expected_tables,
)

logger = get_logger(__name__)

ODDSPEDIA_LAYER = "oddspedia_bronze"
LAYER_CHOICES = (*LAYER_ORDER, ODDSPEDIA_LAYER)
RELOAD_HINTS = {
    "bronze": "python scripts/bronze/load_fotmob_bronze.py --full-history",
    "silver": "python scripts/silver/load_fotmob_silver.py --full-history",
    "gold": "python scripts/gold/load_fotmob_gold.py --full-history",
    ODDSPEDIA_LAYER: (
        "python scripts/oddspedia/load_oddspedia_bronze.py --start-date YYYYMMDD --end-date YYYYMMDD"
    ),
}
ODDSPEDIA_RESOLUTION_TABLE = "silver.oddspedia_match_resolution"
ODDSPEDIA_RESOLUTION_HINT = (
    "python scripts/oddspedia/resolve_oddspedia_events.py --start-date YYYYMMDD --end-date YYYYMMDD"
)


@dataclass(frozen=True)
class RecreationTarget:
    """One setup-declared table selected for explicit recreation."""

    layer: str
    expected: ExpectedTable

    @property
    def qualified_name(self) -> str:
        return self.expected.qualified_name

    @property
    def reload_hint(self) -> str:
        if self.qualified_name == ODDSPEDIA_RESOLUTION_TABLE:
            return ODDSPEDIA_RESOLUTION_HINT
        return RELOAD_HINTS[self.layer]


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse operator Table Recreation arguments."""
    parser = argparse.ArgumentParser(
        description=(
            "Plan or execute an explicit Table Recreation: drop selected warehouse tables and "
            "recreate them empty from setup DDL. Dry-run is the default; pass --execute with "
            "--drifted, --table, --database, or a specific --layer to mutate tables."
        )
    )
    parser.add_argument(
        "--layer",
        choices=(*LAYER_CHOICES, "all"),
        default="all",
        help="Setup layer whose declared tables are selectable (default: all).",
    )
    parser.add_argument("--database", help="Optional exact ClickHouse database selector.")
    parser.add_argument("--table", help="Optional exact table name inside the selection.")
    parser.add_argument(
        "--drifted",
        action="store_true",
        help="Select only existing tables whose schema drifted from their setup DDL.",
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Drop and recreate the selected tables. Omit this flag for dry-run planning.",
    )
    return parser.parse_args(argv)


def setup_inventory(clickhouse_root: Path) -> list[RecreationTarget]:
    """Return every table declared by setup DDL, labelled with its setup layer."""
    sql_files_by_layer = {
        layer: get_layer_sql_files(layer, clickhouse_root=clickhouse_root) for layer in LAYER_ORDER
    }
    sql_files_by_layer[ODDSPEDIA_LAYER] = sorted(
        (clickhouse_root / ODDSPEDIA_LAYER / "ddl").glob("*.sql")
    )
    inventory: dict[str, RecreationTarget] = {}
    for layer, sql_files in sql_files_by_layer.items():
        for expected in parse_expected_tables(sql_files):
            inventory.setdefault(expected.qualified_name, RecreationTarget(layer, expected))
    return list(inventory.values())


def select_targets(
    inventory: Sequence[RecreationTarget],
    layer: str,
    database: str | None,
    table: str | None,
) -> list[RecreationTarget]:
    """Filter the setup inventory by layer, database, and table selectors."""
    selected = [
        target
        for target in inventory
        if (layer == "all" or target.layer == layer)
        and (database is None or target.expected.database == database)
        and (table is None or target.expected.table == table)
    ]
    if not selected:
        raise ValueError(
            "No setup-declared table matches "
            f"layer={layer} database={database or '*'} table={table or '*'}"
        )
    return selected


def requires_explicit_scope(args: argparse.Namespace) -> bool:
    """Return whether --execute was requested without any narrowing selector."""
    return args.execute and not (args.drifted or args.table or args.database or args.layer != "all")


def live_row_counts(client: Any, targets: Sequence[RecreationTarget]) -> dict[str, int]:
    """Return current row counts for the selected tables that exist."""
    databases = sorted({target.expected.database for target in targets})
    for database in databases:
        if not ClickHouseClient._SAFE_IDENT.fullmatch(database):
            raise ValueError(f"Unsafe database: {database}")
    database_list = ", ".join(f"'{database}'" for database in databases)
    rows = client.execute(
        f"SELECT database, name, total_rows FROM system.tables WHERE database IN ({database_list})",
        log_query=False,
    ).result_rows
    return {f"{database}.{name}": int(total_rows or 0) for database, name, total_rows in rows}


def drop_statement(target: RecreationTarget) -> str:
    """Build the DROP statement for one selected table."""
    for identifier in (target.expected.database, target.expected.table):
        if not ClickHouseClient._SAFE_IDENT.fullmatch(identifier):
            raise ValueError(f"Unsafe identifier: {identifier}")
    return f"DROP TABLE IF EXISTS {target.qualified_name}"


def run(argv: Sequence[str] | None = None, client: Any | None = None) -> int:
    """Plan or execute an explicit Table Recreation."""
    args = parse_args(argv)
    if requires_explicit_scope(args):
        logger.error(
            "Executing Table Recreation requires --drifted, --table, --database, or a "
            "specific --layer"
        )
        return 2
    try:
        targets = select_targets(
            setup_inventory(resolve_clickhouse_root()), args.layer, args.database, args.table
        )
    except ValueError as error:
        logger.error(str(error))
        return 2

    owns_client = client is None
    if client is None:
        try:
            client = maintenance_client()
        except RuntimeError as identity_error:
            logger.error(str(identity_error))
            return 1
        if not client.connect():
            logger.error("Failed to connect to ClickHouse")
            return 1

    try:
        if args.drifted:
            drifts = find_schema_drift(client, [target.expected for target in targets])
            if drifts:
                logger.info("Schema drift detected\n" + format_drift_report(drifts))
            drifted_names = {drift.expected.qualified_name for drift in drifts}
            targets = [target for target in targets if target.qualified_name in drifted_names]
            if not targets:
                logger.info("No schema drift found; nothing to recreate")
                return 0

        row_counts = live_row_counts(client, targets)
        logger.info(
            "Planning Table Recreation",
            dry_run=not args.execute,
            selected_tables=len(targets),
            rows_to_drop=sum(row_counts.get(target.qualified_name, 0) for target in targets),
        )
        for target in targets:
            exists = target.qualified_name in row_counts
            if not args.execute:
                logger.info(
                    "Dry-run Table Recreation",
                    table=target.qualified_name,
                    exists=exists,
                    rows=row_counts.get(target.qualified_name, 0),
                    source_file=target.expected.source_file.name,
                )
                continue
            logger.info(
                "Recreating table",
                table=target.qualified_name,
                rows_dropped=row_counts.get(target.qualified_name, 0),
            )
            client.execute(drop_statement(target))
            client.execute(target.expected.create_statement)

        if args.execute:
            for hint in sorted({target.reload_hint for target in targets}):
                logger.info("Recreated tables are empty; reload the affected scope", command=hint)
        return 0
    except ValueError as error:
        logger.error(str(error))
        return 2
    except Exception as error:
        logger.exception("Table Recreation failed", error=str(error))
        return 1
    finally:
        if owns_client:
            client.disconnect()


def main() -> int:
    return run()


if __name__ == "__main__":
    raise SystemExit(main())
